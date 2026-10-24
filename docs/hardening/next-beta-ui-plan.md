# Next-beta UI preparation — architecture and review proposal

Status: planning only. No visual redesign, theme switch, remote configuration, alternate UI framework or production theme seam added. Current appearance/navigation remains the default. Independent review/evidence belongs to Claude; final acceptance remains with the owner.

## Current system and coupling audit

| Surface | Established implementation | Refresh risk / preparation |
| --- | --- | --- |
| Apple tokens | `FlashDesign/Theme/FlashTokens.swift`: semantic Typography uses SwiftUI relative styles, scaled display glyphs via ScaledMetric; Spacing, Radius, Metrics and Shadow; `BrandColors.swift` light/dark; `FlashMotion.swift` Reduce Motion-aware helpers | Preserve semantic sizes/AX5 layouts. Don't turn geometric dots/columns/preview-only frame sizes into global tokens merely because they are numeric |
| Shared FlashDesign | Cards, chips, empty states/toasts, charts, filters/editors, Calendar/Emotion/Stats/Memory/LogFlow and settings features shared by iOS/macOS | Features read data/view models and own editing/navigation as well as appearance. Keep domain/import/persistence independent; split a visual subview only when an actual refresh requires replacement |
| Native Apple shells | iOS RootView tabs/navigation stacks, sheets, capture accessory/fallback FAB and search; macOS NavigationSplitView, menus/shortcuts, MenuBarExtra, search overlay and floating capture panel | Retain shells; do not force desktop sidebar, keyboard menus and iPhone tabs into one navigation abstraction. Preserve FocusRouter consume(matching:) so inactive tabs cannot steal routes |
| Apple platform modifiers | `FlashDesign/Support/PlatformModifiers.swift` handles panel width, editor chrome, haptics, zoom and field styling; OS availability chooses glass or native fallback | Existing seam is sufficient. Avoid another theme environment that duplicates platform behavior. Re-run macOS behavior/counts whenever changing shared code |
| Android tokens/shell | `ui/theme/FlashTokens.kt`, Material roles/typography, GLASS components and style-aware cards; persisted UiStyle; dock/navigation and Compose forms/charts | Preserve both existing styles and their semantics. Keep Material components' focus/touch/interaction behavior; use existing style routing instead of a parallel theme framework |
| Harmony tokens/shell | `components/DesignTokens.ets` covers light/dark semantic text/surfaces, radii, type, widths, contrast helpers; pages/controllers/projections separate state; responsive dock/fold/tablet navigation | Maintain native ArkUI response and explicit theme-state propagation. Preserve tested contrast and reduced-motion preference; host tests do not establish ArkUI runtime behavior |
| Motion/feedback | Apple Motion + Reduce Motion, iOS haptics/zoom; Android Compose timing/system animation scale; Harmony persisted Reduce Motion via motionDuration | Future changes must preserve feedback when movement is disabled. Audit individual animations rather than assuming every direct animateTo/withAnimation/tween uses a wrapper |
| Empty/error/loading states | FlashEmptyState/brand text and platform forms/dialogs already exist | Make record preservation, retry and focus restoration consistent. A visual cleanup must not obscure strict-import errors, upgrade guidance, reminder postcommit failures or recovery counts |

Concrete remaining literals/couplings (source locations inspected at the approved base):

- Shared `Components/LogCardView.swift:96` padding14; `Features/Emotion/EmotionView.swift:443` and `Features/Calendar/CalendarView.swift:250` padding10; `Features/Stats/StatsView.swift:92,309` and `Features/Memory/MemoryView.swift:155,172` padding20. These are documented local optical adjustments. Decide semantic component density in a future proposal before replacing them globally.
- `macos/Flash/UI/Search/GlobalSearchOverlay.swift:147` width560; `FlashDesign/Features/LogFlow/LogFlowView.swift:62` width110; iOS `QuickCaptureEntry.swift:46` FAB56; `HomeView.swift:167` icon36. Distinguish desktop width/geometry from typography; test narrow windows and AX5 before altering.
- Android `ui/welcome/WelcomeScreen.kt:51-53` embeds a separate pastel gradient. `FlashTokens.Touch.IconButtonMin` is44dp, whereas platform Material controls may supply a larger48dp interactive area. Verify actual semantics bounds; do not claim platform target compliance from a token alone.
- Harmony `pages/ProfilePage.ets:168,191,214` uses radius14/padding12 in import/settings summaries; `ExplorePage.ets:107,284` radius26/padding20; `StatsPage.ets:161` fixed height88 and radius18; `formability/pages/TodaySummaryCard.ets:14-70` owns type/radius values outside main tokens. Form snapshots and widget sizes have OS constraints and need independent scaling checks.
- Apple editor/feature views combine visual layout with FocusRouter, sheet state, SwiftData queries, notification actions and import coordination. Refresh commits should depend on stable behavior interfaces and must not move stores, rework schema, change cache identity or add data migrations.

These examples are an audit sample, not an assertion that all remaining literals are wrong or that every screen has passed accessibility review.

## Proposed direction and information architecture

Retain Flash's warm, content-first system typography, recognizable module color/emoji cues, restrained glass on floating chrome, and calm short motion. For the next beta, compare a conservative token-only variant with a component-focused variant using the same recorded screenshots. No replacement artwork or visual specification is implemented here.

Keep capture within one choice, records searchable and editable, calendar/task links intact, review and Memory distinct. Validate discoverability of 日志流, 情绪 and 日历 from each native shell before proposing any IA movement. Desktop retains keyboard/menus/sidebars; Android retains system Back/Material or existing Glass choice; Harmony retains adaptive ArkUI navigation. Preserve route names, drafts, selection and scroll restoration across any future component swap.

## Screenshot and accessibility baseline contract

See `baseline-2026-10-24.md` for the full major-screen matrix. Each image needs platform/model/OS, screenshot dimensions, build+commit, theme/style, text size, locale/time zone, fixture identifier and screen/state. Use only isolated fictional data; never capture pairing PINs or daily personal records. Keep original PNGs and a manifest; don't substitute generated mockups for captured screens.

Required dimensions: light/dark; default/AX5 on iPhone narrow and unfolded widths; Mac normal/minimum window and largest supported text; Android compact/expanded, both styles,1.0/2.0 font; Harmony phone/fold/tablet and platform maximum accessible font. AX5 is an Apple category, not a literal Android/Harmony setting. Include nonempty/empty, long Chinese/emoji, keyboard visible, errors, import preview, search and batch state. Flag missing images explicitly in verification evidence.

For every major flow: actual VoiceOver/TalkBack/ScreenReader traversal, meaningful icon names/selected/error state, sensible reading/focus order, keyboard-only completion/Esc/Back, focus return after dialogs, contrast, no color-only meaning, reachable trailing content, platform minimum touch bounds, Reduce Motion, text reflow without clipping, and no stale records/widgets. Existing iOS AX5 fixes and Control Center/widget deep links are regression gates.

## Executed screenshot checkpoint and missing coverage

[Android baseline manifest](evidence/screenshots/android-m12/manifest.json):16 original PNGs and accessibility hierarchies, home/records/review/settings × light/dark × font1.0/2.0, dedicated API36/Android16 Pixel1080×1920. Empty fictional app container, current GLASS/system theme, production source1acf52d and APK SHA recorded. Font2.0 is an Android test setting, not Apple AX5. These are existing UI captures, not proposed artwork or performance results.

Visual sample inspection: home light/default places part of the empty-state action behind the floating dock in the initial viewport; records dark/font2 reflows the empty-state caption across lines. This is baseline evidence to challenge for scroll reachability/focus/alternate capture access, not an accessibility pass or a redesign instruction. Do not silently adjust layout in this preparation commit.

| Platform/coverage | Executed | Missing / exact continuation |
| --- | --- | --- |
| Android compact GLASS,4empty primary screens |16PNG/XML captures, build/OS/commit/hash manifest | Populate fictional records; capture emotion/calendar/Memory/editor/import/search/batch/errors; repeat Material, expanded/fold/tablet; actual TalkBack/keyboard/touch/contrast/Reduce Motion traversal |
| iOS dedicated iPhone18 Pro/iOS27.0 |14app tests; existing UI screenshot not yet captured | Candidate installed only on owned CodexFlashHardening simulator. Xcode27.2 uses Device Hub at Contents/Applications/DeviceHub.app. Select that named device; capture each major screen at light/dark × default/accessibilityExtraExtraExtraLarge(AX5), including Chinese/emoji/error/keyboard states and narrow/wide sizes. Mac locked during UI selection; CUA requires manual unlock, which has been requested. Do not bypass the lock or substitute generated images |
| macOS |13behavior tests; no screenshot baseline | Launch in a dedicated fictional user/container, preserve daily store; capture normal/minimum windows, light/dark, largest supported text, keyboard/VoiceOver; use existing signing, no store move |
| Harmony |287host/contract tests, unsigned HAP; no native screenshot | Attach a supported phone/fold/tablet with existing authorized signing; seed fictional data; capture light/dark/default/maximum accessibility font, form/keyboard/error states; run ScreenReader and native touch/motion checks |

Current screenshot coverage is incomplete. `tools/verification/android-screenshot-baseline.py` documents the already-executed purpose-built emulator capture and requires explicit emulator/build/source metadata; it must never target physical/daily devices. Original PNGs are retained unchanged. No baseline claim is made for uncaptured states or unavailable devices.

## Migration, validation and rollback

1. Capture and review current screens/accessibility traces; inventory exceptions and establish per-platform validation owners. Do not enable a new appearance without this baseline.
2. Agree on direction/IA and approve visual implementation. Resolve one component family at a time: semantic tokens -> buttons/chips/cards/forms -> charts/empty states -> feature composition -> native shells only if justified. Treat token mapping separately from behavior changes.
3. Add the smallest local theme selection seam only if comparing two implementations actually requires it. Current theme remains default; no remote flags/dead framework. Review each step against PNGs and native accessibility/behavior traces, including lower-spec Release frame stability.
4. Each visual milestone must pass unit/contract gates and platform UI/device checks, preserve store/backup compatibility, widget refresh/read-state, reminders/capture routes, and record/search ordering. Keep signing/deployment untouched.
5. UI commits depend on public stable data/domain contracts. Roll back by reverting only the visual commit family or removing the local disabled experiment, preserving security, transport and data fixes. Never roll back a secure protocol to v1.1 to restore appearance. If a visual branch begins requiring schema changes, stop and submit a separate approved migration.

Future owner decisions: direction and scope; IA changes, if evidence supports them; exact visual implementation approval; any accessibility tradeoff (no implicit waivers); and evidence completeness before beta inclusion. This plan does not grant acceptance or promise a release date.
