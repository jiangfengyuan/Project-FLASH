# Owner-assigned iOS correctness and accessibility fixes

The owner assigned C2's search and AX5 findings to Codex, explicitly in separate commits. These corrective fixes are separate from the planned next-beta visual refresh. No new theme, dependency, permission, signing, store or backup-schema change.

## C3 — search

`420c51c`: explicitly pass the existing `AppState.focusRouter` to the sibling search sheet. The native regression mounts the real RootView/sheet with isolated memory data/preferences/read-state, reproduces the parent's missing-FocusRouter fatal assertion, and passes after the fix. Complete candidate iOS15tests/5suites pass. The parent runner stalled after crash recovery and was terminated; do not call its0remaining-test restart a passing parent. [Source/log receipt](c3-search.json).

## C4 — accessibility-size candidate

| Surface | Corrective implementation | Behavior boundary |
| --- | --- | --- |
| Calendar | iOS accessibility sizes use a vertically scrollable page, full-width month header/actions and horizontally scrollable seven-column grid with scaled column widths. Count/emoji rows grow and stack instead of clipping to14pt. | Same dates, selection, task/detail actions, revision cache and reduced-motion logic; normal-size and macOS layout branches retained. Horizontal/vertical reachability and selected-date behavior need actual UI checks. |
| Task editor | iOS accessibility sizes place the deadline label above a native wheel DatePicker. | Same date binding/components/editor time zone and save/reminder calculation; ordinary/macOS compact picker retained. Both all-day and timed selection/save still need UI verification. |
| Emotion | iOS accessibility sizes stack the note and submit controls. | Same slider, note/intensity binding and save action; normal/macOS horizontal row retained. Actual submit/focus still need verification. |
| Quick capture | Accessibility sizes use a large scrollable sheet and vertical header/category/action composition. | Same draft/category/focus/cancel/return/save logic and native effects; standard-size detents/layout retained. No font cap added. Keyboard/narrow-width checks pending. |

[Gate receipt/source hashes](c4-ax5.json): Debug iOS build and15tests pass at system AX5; macOS13tests unchanged; FlashKit204tests pass. All gates serialized. The last iOS-only button layout adjustment was followed by another successful iOS build/test; shared/macOS sources did not change after their gates.

At this commit, actual UI verification is pending: Device Hub CUA capture failed with ScreenCaptureKit -3812 after approval capacity was restored; the owner has now brought the named window front/Zoom to Fit. Resume actual navigation and preserve fresh original PNGs in a NEW manifest; do not overwrite C2's47 images or infer accessibility from these test counts. VoiceOver, contrast/touch measurement, real devices and other screen sizes remain separate acceptance gates.

Keep these corrective commits independently of future visual-refresh rollback. The owner and independent reviewer retain acceptance; no merge/release is authorized by this checkpoint.
