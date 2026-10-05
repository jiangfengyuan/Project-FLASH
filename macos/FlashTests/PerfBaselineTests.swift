// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if DEBUG
import Foundation
import Testing
@testable import Flash

/// 性能基线：合成 1 万日志 / 5 千情绪 / 2 千任务（SyntheticDataset 确定性生成）。
/// 结果追加写入 /tmp/flash-perf-baseline.txt（xcodebuild 不回传 stdout），
/// 供 `app/macos/README.md` 性能基线节前后对照；
/// 断言为宽松上限（≈预期 10 倍余量），只拦截病态回归，不做精确计时。
struct PerfBaselineTests {

    private let dataset = SyntheticDataset.generate(logs: 10_000)
    private let clock = ContinuousClock()

    private func record(_ name: String, _ elapsed: Duration) {
        let ms = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        let line = "[PerfBaseline] \(name) = \(String(format: "%.1f", ms)) ms\n"
        let url = URL(fileURLWithPath: "/tmp/flash-perf-baseline.txt")
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    @Test func aggregateDayBaseline() {
        let elapsed = clock.measure {
            _ = aggregateDay(logs: dataset.logs, emotions: dataset.emotions, tasks: dataset.tasks)
        }
        record("aggregateDay 10k/5k/2k", elapsed)
        #expect(elapsed < .seconds(5))
    }

    @Test func statsPipelineBaseline() {
        let elapsed = clock.measure {
            let emotions = dataset.emotions
            let logs = dataset.logs
            _ = EmotionStats.dailyAverages(emotions, days: 90)
            _ = EmotionStats.subEmotionDistribution(emotions, days: 90)
            _ = ActivityStats.daily(logs: logs, emotions: emotions, days: 90)
            _ = ReviewInsights.compare(logs: logs, emotions: emotions, window: .days90)
        }
        record("statsPipeline(dailyAverages+subEmotion+activity+insights, 90d)", elapsed)
        #expect(elapsed < .seconds(5))
    }

    @Test func logFilterBaseline() {
        var filter = LogFilter()
        filter.query = "设计"
        let elapsed = clock.measure {
            _ = filter.apply(to: dataset.logs)
        }
        record("LogFilter.apply(query) 10k", elapsed)
        #expect(elapsed < .seconds(2))
    }

    @Test func globalSearchBaseline() {
        let elapsed = clock.measure {
            _ = GlobalSearch.search(logs: dataset.logs, emotions: dataset.emotions,
                                    tasks: dataset.tasks, query: "设计")
        }
        record("GlobalSearch 10k/5k/2k", elapsed)
        #expect(elapsed < .seconds(2))
    }
}
#endif
