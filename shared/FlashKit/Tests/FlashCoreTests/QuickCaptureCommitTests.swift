// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData
import Testing
@testable import FlashCore

@MainActor
@Suite("QuickCaptureCommit 快速记录保存规则")
struct QuickCaptureCommitTests {
    private func makeRepository() -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    }

    @Test func blankDraftWritesNothing() throws {
        let repository = makeRepository()
        #expect(try QuickCaptureCommit.commit("  \n ", as: .log, repository: repository) == .empty)
        #expect(try repository.allLogs().isEmpty)
    }

    @Test func logIsTrimmedAndTaggedDaily() throws {
        let repository = makeRepository()
        let outcome = try QuickCaptureCommit.commit("  早上跑了五公里 \n", as: .log, repository: repository)
        #expect(outcome == .saved(toast: "✓ 已保存到日志"))
        let log = try #require(try repository.allLogs().first)
        #expect(log.content == "早上跑了五公里")
        #expect(log.category == .log)
        #expect(log.colorTag == .daily)
        #expect(log.importance == 0)
        #expect(log.recordDate == DateFormatting.today())
    }

    @Test func ideaInfersImportanceFromBangs() throws {
        let repository = makeRepository()
        let outcome = try QuickCaptureCommit.commit("做一个 iOS 版!!!", as: .idea, repository: repository)
        #expect(outcome == .saved(toast: "✓ 已保存到灵感"))
        let log = try #require(try repository.allLogs().first)
        #expect(log.category == .idea)
        #expect(log.colorTag == .idea)
        #expect(log.importance == 3)
    }

    @Test func overLimitKeepsDraftAndWritesNothing() throws {
        let repository = makeRepository()
        let tooLong = String(repeating: "a", count: TextLimits.maxContentUTF16 + 1)
        guard case .tooLong = try QuickCaptureCommit.commit(tooLong, as: .log, repository: repository) else {
            Issue.record("超限内容应返回 .tooLong")
            return
        }
        #expect(try repository.allLogs().isEmpty)
    }
}
