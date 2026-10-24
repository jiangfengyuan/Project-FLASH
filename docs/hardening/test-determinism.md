# iOS reminder gate fixture correction

2026-10-25: the14-test iOS app gate executed13 passes and1 failure: `existingIdeasAreBaselineAndNewOnesCountTowardThreshold` expected oldest content一 but observed二. The unchanged production reminder code orders by millisecond `createdAt`; rapid consecutive `addLog` calls can tie and SwiftData provides no insertion-order guarantee for equal timestamps. That fixture did not establish its expected chronological order.

Only the three fictional new-idea fixtures now enter the existing production repository with distinct explicit UTC instants/IDs. The baseline, unread counts, threshold, badge, oldest-item and mark-read assertions remain. No assertion was removed; no sleep, production clock/store/reminder/widget/notification code changed. This is a deterministic test setup correction, not a claimed production reminder fix.

The complete iPhone18 Pro/iOS27.0 simulator gate then passed14/14. Failed and corrected xcresults/logs are retained as `m12-ios-tests.log` and `t1-ios-tests.log`; no physical notification/widget result is inferred. The shared timezone candidate was present in both runs.
