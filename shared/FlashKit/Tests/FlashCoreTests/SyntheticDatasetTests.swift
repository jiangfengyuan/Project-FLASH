// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if DEBUG
import Testing
@testable import FlashCore

@Suite("合成数据集（调试灌注）")
struct SyntheticDatasetTests {
    /// 灌注数据要能走完整备份链路（设备上验证导出/分享/局域网），id 必须符合严格导出契约
    @Test func syntheticDataPassesStrictExport() throws {
        let data = SyntheticDataset.generate(logs: 80)
        let json = try BackupService.exportStrictJSON(logs: data.logs, emotions: data.emotions,
                                                      tasks: data.tasks, appVersion: "test")
        let parsed = try BackupService.parseStrict(json)
        #expect(parsed.logCount == 80)
        #expect(parsed.emotionCount == 40)
        #expect(parsed.taskCount == 16)
    }

    @Test func idsAreUniqueAcrossSections() {
        let data = SyntheticDataset.generate(logs: 50)
        let ids = data.logs.map(\.id) + data.emotions.map(\.id) + data.tasks.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
#endif
