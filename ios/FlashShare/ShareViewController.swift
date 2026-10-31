// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FlashCore

/// 分享扩展入口：取出分享来的文字 / 链接，交给 SwiftUI 面板编辑与选类型。
/// 扩展不打开 SwiftData 主库（不在 App Group 内），保存只投递到 `CaptureInboxStore`，
/// 主 App 下次启动或回到前台时收入。
final class ShareViewController: UIViewController {
    private let model = ShareCaptureModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        model.onFinish = { [weak self] saved in
            if saved {
                self?.extensionContext?.completeRequest(returningItems: nil)
            } else {
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        }
        let host = UIHostingController(rootView: ShareCaptureView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        Task { await model.load(from: providers) }
    }
}

@MainActor
@Observable
final class ShareCaptureModel {
    var text = ""
    var category: Category = .idea
    var isLoading = true
    var errorMessage: String?
    @ObservationIgnored var onFinish: ((Bool) -> Void)?
    @ObservationIgnored var inbox: CaptureInboxStore? = .shared

    func load(from providers: [NSItemProvider]) async {
        var sharedText: String?
        var sharedURL: URL?
        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                sharedURL = await Self.loadObject(URL.self, from: provider)
            } else if sharedText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                sharedText = await Self.loadObject(String.self, from: provider)
            }
        }
        // 只收 http(s) 链接；文件 URL 等不是用户想记下的内容
        if let scheme = sharedURL?.scheme?.lowercased(), scheme != "http", scheme != "https" { sharedURL = nil }
        text = CaptureInboxEntry.compose(text: sharedText, url: sharedURL)
        isLoading = false
    }

    func save() {
        switch QuickCaptureCommit.prepare(text) {
        case .empty:
            errorMessage = "内容为空"
        case .tooLong(let message):
            errorMessage = message
        case .ready(let content):
            guard let inbox else {
                errorMessage = "暂时无法保存到 Flash：共享容器不可用"
                return
            }
            do {
                try inbox.enqueue(CaptureInboxEntry(text: content, category: category))
                onFinish?(true)
            } catch CaptureInboxError.full {
                errorMessage = "待收入的分享已满 \(CaptureInboxStore.maxPending) 条，请先打开 Flash"
            } catch {
                FlashLog.failure("share_extension_enqueue_failed", error)
                errorMessage = "保存失败，请重试"
            }
        }
    }

    func cancel() { onFinish?(false) }

    private static func loadObject<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
    where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { value, _ in continuation.resume(returning: value) }
        }
    }
}

struct ShareCaptureView: View {
    @Bindable var model: ShareCaptureModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $model.category) {
                        Text("灵感").tag(Category.idea)
                        Text("日志").tag(Category.log)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        TextEditor(text: $model.text)
                            .frame(minHeight: 160)
                    }
                } footer: {
                    if let message = model.errorMessage {
                        Text(message).foregroundStyle(.red)
                    } else {
                        Text("下次打开 Flash 时收入。")
                    }
                }
            }
            .navigationTitle("记到 Flash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { model.save() }
                        .disabled(model.isLoading)
                }
            }
        }
    }
}
