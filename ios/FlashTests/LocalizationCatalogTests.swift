// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing

/// 编译进 App 的 String Catalog：八种语言键集一致，占位符个数一致。
@Suite("iOS 文案目录")
struct LocalizationCatalogTests {
    private static let languages = ["en", "zh-Hans", "fr", "ko", "de", "ru", "ar", "ja"]

    private func specifierCount(_ text: String) -> Int {
        text.matches(of: /%(?:\d+\$)?(?:lld|ld|d|@|\.?\d*lf|\.?\d*f)/).count
    }

    private func table(_ language: String) throws -> [String: String] {
        let folder = try #require(Bundle.main.url(forResource: language, withExtension: "lproj"), "缺 \(language).lproj")
        let url = folder.appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(language) 没有 Localizable.strings")
    }

    @Test func everyLanguageHasEveryKey() throws {
        let english = try table("en")
        #expect(english.count > 400)
        for language in Self.languages {
            let current = try table(language)
            #expect(Set(current.keys) == Set(english.keys), "\(language)")
            #expect(current.values.allSatisfy { !$0.isEmpty }, "\(language)")
        }
    }

    @Test func placeholderCountsMatchTheKey() throws {
        for language in Self.languages {
            for (key, value) in try table(language) where !key.contains("${") {
                #expect(specifierCount(value) == specifierCount(key), "\(language): \(key)")
            }
        }
    }

    @Test func englishIsTranslatedNotTheChineseSource() throws {
        let english = try table("en")
        #expect(english["现在想记录什么？"] != "现在想记录什么？")
        #expect(english["现在想记录什么？"]?.isEmpty == false)
    }
}
