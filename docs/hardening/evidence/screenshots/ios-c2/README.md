# C2 iOS screenshot checkpoint — 2026-10-25

47 original native PNGs, source `dd07bcd5227a88debbfc7be8c948576b206fdb9f`, dedicated `CodexFlashHardening` iPhone18 Pro / iOS27.0 (24A434), 1206×2622. Installed Debug app0.1.0/build1, SDK27.2/Xcode27B5028f, existing signing disabled. These are UI baselines, not Release performance measurements or real-device verification. Full file hashes, exact system theme/text readbacks, locale, dataset phase and UTC capture times are in [manifest.json](manifest.json). Simulator time zone remains unverified.

## Coverage and data phases

- First nine PNGs: initial empty container, light/default (`large`), welcome/home/emotion/task/records/review/Memory/settings/disabled-LAN alert.
- One original dark/default Memory PNG: one short operator-entered idea observed during window assistance. Preserve it as a distinct phase; never describe it as empty or agent-seeded fictional data.
- After an unexplained simulator stop, Flash was absent from `listapps`; app/data registration and matching orphan metadata container were absent. Agent did not erase/uninstall/delete that entry. Cause unknown. The same existing binary was reinstalled, launched and checked against every installed bundle-file hash. The prior ten PNGs remain unchanged. This observation alone does not attribute data loss to product code.
- Reinstalled empty phase: one welcome PNG plus home/records/weekly review/Memory/settings/month calendar/unsaved emotion/blank unsaved task, each at light/dark × default/AX5:32 comparable PNGs with no committed rows. AX5 is native `accessibility-extra-extra-extra-large`, verified by SDK readback.
- Four long-draft PNGs: same fictional Chinese/emoji idea draft, unsaved, light/dark × default/AX5. Single-line input scrolls horizontally. Keyboard is hidden in these exports. Cancel/reopen retained the draft; this is not a process-relaunch persistence test.

Original images are never retouched. Native `simctl io screenshot` was used because Device Hub's capture bridge sometimes showed a blank viewport while the native frame was valid. All navigation/input used CUA. No synthetic mockup substitutes for an uncaptured screen. The initial inspector-profile checks do not attest to all flags after the environment incident; later captures independently verify theme/text size and binary identity only.

## Findings returned to owner for fix assignment

| ID | Reproduction / observation | Evidence / source boundary |
| --- | --- | --- |
| C2-01 search crash | Empty home → global search, twice. App exits to SpringBoard; native SIGTRAP reports match both times. Fatal assertion: missing `FocusRouter` observable environment object. No usable search baseline. | [Minimal diagnostic extract](search-crash-extract.json); `ios/Flash/UI/RootView.swift:59,70` supplies router to TabView content before sibling sheet, while `ios/Flash/UI/Search/SearchScreen.swift:17` requires it. Both source files unchanged from e9a0aa6; baseline binary not rerun, so no runtime before/after attribution. |
| C2-02 AX5 calendar | Month header clips; two-digit days wrap vertically, layout overlaps title/dock. Both themes; leaving/re-entering the tab reproduces it. | `calendar-reinstalled-*-accessibility-extra-extra-extra-large.png`; `FlashDesign/Features/Calendar/CalendarView.swift:52,93,322` has fixed horizontal header/seven flexible columns. File unchanged from e9a0aa6. |
| C2-03 AX5 task editor | Deadline label and native date value visibly clip horizontally. No save/reminder attempted. | `task-editor-reinstalled-*-accessibility-extra-extra-extra-large.png`; `TaskEditorView.swift:98` native DatePicker. Only task-timezone resolution/preservation changed in1acf52d; layout unchanged. No baseline runtime comparison. |
| C2-04 AX5 emotion | Submit text wraps vertically near/behind floating dock; actual submit reachability/focus not verified. | `emotion-reinstalled-*-accessibility-extra-extra-extra-large.png`; `EmotionView.swift:160` fixed-width input/button HStack. Source unchanged from e9a0aa6. |
| C2-05 AX5 compact capture | Flash/header clips at compact detent and title truncates; save/cancel visible, keyboard hidden. Expanded detent/keyboard not accepted. | `quick-capture-long-draft-*-accessibility-extra-extra-extra-large.png`; `ios/Flash/UI/QuickCapture/QuickCaptureSheet.swift:39,87` header HStack and fixed260/medium detents. Source unchanged from e9a0aa6. |

These are implementation-owner observations, not independent acceptance. Fix ownership was requested from the owner. No search/layout fix is included in C2; no visual redesign, signing, entitlement, schema or production store change.

## Remaining acceptance and continuation

Search is blocked by C2-01. VoiceOver traversal, contrast/touch measurements, Reduce Motion, software-keyboard exports, populated lists/batch/import/error states, narrow/wide/iPad sizes, lock-screen widgets and physical devices remain unverified. Default/AX5 images do not prove accessibility. macOS and Harmony native screenshots remain absent; Android's earlier16 PNG/XML checkpoint remains separate.

To reproduce: use only this named dedicated simulator, install the recorded candidate bundle without resetting a daily store, verify its hashes; use Device Hub/CUA to navigate. Set the owned simulator's appearance and content_size through native SDK controls, read them back, then invoke `tools/verification/ios-screenshot-baseline.py` with explicit screen/state/data phase. A different binary must start a new manifest. Never overwrite a PNG or mix phases silently. Record time zone independently before calendar acceptance.

## Original PNG index

| Screen | Theme | Native text size | Data phase | Original PNG |
| --- | --- | --- | --- | --- |
| welcome | light | large | initial-empty | [welcome-light-large.png](welcome-light-large.png) |
| home-empty | light | large | initial-empty | [home-empty-light-large.png](home-empty-light-large.png) |
| emotion-empty | light | large | initial-empty | [emotion-empty-light-large.png](emotion-empty-light-large.png) |
| task-editor | light | large | initial-empty | [task-editor-light-large.png](task-editor-light-large.png) |
| records-empty | light | large | initial-empty | [records-empty-light-large.png](records-empty-light-large.png) |
| review-empty | light | large | initial-empty | [review-empty-light-large.png](review-empty-light-large.png) |
| memory-empty | light | large | initial-empty | [memory-empty-light-large.png](memory-empty-light-large.png) |
| settings | light | large | initial-empty | [settings-light-large.png](settings-light-large.png) |
| lan-disabled-alert | light | large | initial-empty | [lan-disabled-alert-light-large.png](lan-disabled-alert-light-large.png) |
| memory-one-idea | dark | large | operator-one-idea | [memory-one-idea-dark-large.png](memory-one-idea-dark-large.png) |
| welcome-reinstalled | dark | large | reinstalled-empty | [welcome-reinstalled-dark-large.png](welcome-reinstalled-dark-large.png) |
| home-reinstalled | dark | large | reinstalled-empty | [home-reinstalled-dark-large.png](home-reinstalled-dark-large.png) |
| records-reinstalled | dark | large | reinstalled-empty | [records-reinstalled-dark-large.png](records-reinstalled-dark-large.png) |
| review-reinstalled | dark | large | reinstalled-empty | [review-reinstalled-dark-large.png](review-reinstalled-dark-large.png) |
| memory-reinstalled | dark | large | reinstalled-empty | [memory-reinstalled-dark-large.png](memory-reinstalled-dark-large.png) |
| settings-reinstalled | dark | large | reinstalled-empty | [settings-reinstalled-dark-large.png](settings-reinstalled-dark-large.png) |
| settings-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [settings-reinstalled-dark-accessibility-extra-extra-extra-large.png](settings-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| memory-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [memory-reinstalled-dark-accessibility-extra-extra-extra-large.png](memory-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| review-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [review-reinstalled-dark-accessibility-extra-extra-extra-large.png](review-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| records-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [records-reinstalled-dark-accessibility-extra-extra-extra-large.png](records-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| home-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [home-reinstalled-dark-accessibility-extra-extra-extra-large.png](home-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| home-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [home-reinstalled-light-accessibility-extra-extra-extra-large.png](home-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| records-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [records-reinstalled-light-accessibility-extra-extra-extra-large.png](records-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| review-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [review-reinstalled-light-accessibility-extra-extra-extra-large.png](review-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| memory-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [memory-reinstalled-light-accessibility-extra-extra-extra-large.png](memory-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| settings-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [settings-reinstalled-light-accessibility-extra-extra-extra-large.png](settings-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| settings-reinstalled | light | large | reinstalled-empty | [settings-reinstalled-light-large.png](settings-reinstalled-light-large.png) |
| memory-reinstalled | light | large | reinstalled-empty | [memory-reinstalled-light-large.png](memory-reinstalled-light-large.png) |
| review-reinstalled | light | large | reinstalled-empty | [review-reinstalled-light-large.png](review-reinstalled-light-large.png) |
| calendar-reinstalled | light | large | reinstalled-empty | [calendar-reinstalled-light-large.png](calendar-reinstalled-light-large.png) |
| calendar-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [calendar-reinstalled-light-accessibility-extra-extra-extra-large.png](calendar-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| calendar-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [calendar-reinstalled-dark-accessibility-extra-extra-extra-large.png](calendar-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| calendar-reinstalled | dark | large | reinstalled-empty | [calendar-reinstalled-dark-large.png](calendar-reinstalled-dark-large.png) |
| records-reinstalled | light | large | reinstalled-empty | [records-reinstalled-light-large.png](records-reinstalled-light-large.png) |
| home-reinstalled | light | large | reinstalled-empty | [home-reinstalled-light-large.png](home-reinstalled-light-large.png) |
| emotion-reinstalled | light | large | reinstalled-empty | [emotion-reinstalled-light-large.png](emotion-reinstalled-light-large.png) |
| emotion-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [emotion-reinstalled-light-accessibility-extra-extra-extra-large.png](emotion-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| emotion-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [emotion-reinstalled-dark-accessibility-extra-extra-extra-large.png](emotion-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| emotion-reinstalled | dark | large | reinstalled-empty | [emotion-reinstalled-dark-large.png](emotion-reinstalled-dark-large.png) |
| task-editor-reinstalled | dark | large | reinstalled-empty | [task-editor-reinstalled-dark-large.png](task-editor-reinstalled-dark-large.png) |
| task-editor-reinstalled | dark | accessibility-extra-extra-extra-large | reinstalled-empty | [task-editor-reinstalled-dark-accessibility-extra-extra-extra-large.png](task-editor-reinstalled-dark-accessibility-extra-extra-extra-large.png) |
| task-editor-reinstalled | light | accessibility-extra-extra-extra-large | reinstalled-empty | [task-editor-reinstalled-light-accessibility-extra-extra-extra-large.png](task-editor-reinstalled-light-accessibility-extra-extra-extra-large.png) |
| task-editor-reinstalled | light | large | reinstalled-empty | [task-editor-reinstalled-light-large.png](task-editor-reinstalled-light-large.png) |
| quick-capture-long-draft | light | large | fictional-draft | [quick-capture-long-draft-light-large.png](quick-capture-long-draft-light-large.png) |
| quick-capture-long-draft | light | accessibility-extra-extra-extra-large | fictional-draft | [quick-capture-long-draft-light-accessibility-extra-extra-extra-large.png](quick-capture-long-draft-light-accessibility-extra-extra-extra-large.png) |
| quick-capture-long-draft | dark | accessibility-extra-extra-extra-large | fictional-draft | [quick-capture-long-draft-dark-accessibility-extra-extra-extra-large.png](quick-capture-long-draft-dark-accessibility-extra-extra-extra-large.png) |
| quick-capture-long-draft | dark | large | fictional-draft | [quick-capture-long-draft-dark-large.png](quick-capture-long-draft-dark-large.png) |
