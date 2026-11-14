# 本轮逐文件变更清单

基准为审查前 871 文件工作区（源码基线提交 f6b7e53），不是原 HEAD c3eaf53。M＝修改，A＝新增；未删除 Git 文件。根 CHANGELOG、releases 和 outputs 不在 app Git，单列在表后。

| 状态 | 文件 | 用途 |
| --- | --- | --- |
| M | [.github/workflows/backup-contract.yml](../../.github/workflows/backup-contract.yml) | check LAN isolation and shared Apple builds |
| M | [.gitignore](../../.gitignore) | fix lint and make integration assertions locale aware |
| M | [README.md](../../README.md) | Paper 版本／本地化与验收文档同步 |
| M | [ROADMAP.md](../../ROADMAP.md) | Paper 版本／本地化与验收文档同步 |
| M | [android/README.md](../../android/README.md) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/build.gradle.kts](../../android/app/build.gradle.kts) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/androidTest/java/com/flash/app/data/BackupContractRepositoryTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/BackupContractRepositoryTest.kt) | fix lint and make integration assertions locale aware |
| A | [android/app/src/androidTest/java/com/flash/app/data/EmotionSaveFailureTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/EmotionSaveFailureTest.kt) | retain edits and preserve concurrent database updates |
| A | [android/app/src/androidTest/java/com/flash/app/data/FavoriteSnapshotTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/FavoriteSnapshotTest.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/androidTest/java/com/flash/app/data/LegacyLANDisablementTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/LegacyLANDisablementTest.kt) | fix lint and make integration assertions locale aware |
| A | [android/app/src/androidTest/java/com/flash/app/data/TaskEditorConcurrencyTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/TaskEditorConcurrencyTest.kt) | retain edits and preserve concurrent database updates |
| A | [android/app/src/androidTest/java/com/flash/app/data/TaskSaveFailureTest.kt](../../android/app/src/androidTest/java/com/flash/app/data/TaskSaveFailureTest.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/data/BackupEncryption.kt](../../android/app/src/main/java/com/flash/app/data/BackupEncryption.kt) | fix lint and make integration assertions locale aware |
| M | [android/app/src/main/java/com/flash/app/data/FlashRepository.kt](../../android/app/src/main/java/com/flash/app/data/FlashRepository.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/data/db/Daos.kt](../../android/app/src/main/java/com/flash/app/data/db/Daos.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/data/reminder/TaskReminderScheduler.kt](../../android/app/src/main/java/com/flash/app/data/reminder/TaskReminderScheduler.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/i18n/I18nKeys.kt](../../android/app/src/main/java/com/flash/app/i18n/I18nKeys.kt) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/java/com/flash/app/system/QuickCaptureTileService.kt](../../android/app/src/main/java/com/flash/app/system/QuickCaptureTileService.kt) | fix lint and make integration assertions locale aware |
| M | [android/app/src/main/java/com/flash/app/ui/calendar/CalendarScreen.kt](../../android/app/src/main/java/com/flash/app/ui/calendar/CalendarScreen.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/calendar/CalendarViewModel.kt](../../android/app/src/main/java/com/flash/app/ui/calendar/CalendarViewModel.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/calendar/TaskEditorDialog.kt](../../android/app/src/main/java/com/flash/app/ui/calendar/TaskEditorDialog.kt) | retain edits and preserve concurrent database updates |
| A | [android/app/src/main/java/com/flash/app/ui/capture/CaptureSession.kt](../../android/app/src/main/java/com/flash/app/ui/capture/CaptureSession.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/capture/QuickCaptureSheet.kt](../../android/app/src/main/java/com/flash/app/ui/capture/QuickCaptureSheet.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/emotion/EmotionScreen.kt](../../android/app/src/main/java/com/flash/app/ui/emotion/EmotionScreen.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/emotion/EmotionViewModel.kt](../../android/app/src/main/java/com/flash/app/ui/emotion/EmotionViewModel.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/lock/AppLockScreen.kt](../../android/app/src/main/java/com/flash/app/ui/lock/AppLockScreen.kt) | fix lint and make integration assertions locale aware |
| M | [android/app/src/main/java/com/flash/app/ui/navigation/FlashApp.kt](../../android/app/src/main/java/com/flash/app/ui/navigation/FlashApp.kt) | retain edits and preserve concurrent database updates |
| M | [android/app/src/main/java/com/flash/app/ui/settings/SettingsScreen.kt](../../android/app/src/main/java/com/flash/app/ui/settings/SettingsScreen.kt) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-ar/strings_generated.xml](../../android/app/src/main/res/values-ar/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-de/strings_generated.xml](../../android/app/src/main/res/values-de/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-fr/strings_generated.xml](../../android/app/src/main/res/values-fr/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-ja/strings_generated.xml](../../android/app/src/main/res/values-ja/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-ko/strings_generated.xml](../../android/app/src/main/res/values-ko/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-ru/strings_generated.xml](../../android/app/src/main/res/values-ru/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values-zh/strings_generated.xml](../../android/app/src/main/res/values-zh/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values/strings.xml](../../android/app/src/main/res/values/strings.xml) | Paper 版本／本地化与验收文档同步 |
| M | [android/app/src/main/res/values/strings_generated.xml](../../android/app/src/main/res/values/strings_generated.xml) | Paper 版本／本地化与验收文档同步 |
| A | [android/app/src/test/java/com/flash/app/data/CaptureSessionTest.kt](../../android/app/src/test/java/com/flash/app/data/CaptureSessionTest.kt) | retain edits and preserve concurrent database updates |
| A | [docs/acceptance/paper-alpha1-20261114.md](../../docs/acceptance/paper-alpha1-20261114.md) | Paper 版本／本地化与验收文档同步 |
| A | [docs/acceptance/paper-alpha1-files-20261114.md](../../docs/acceptance/paper-alpha1-files-20261114.md) | Paper 版本／本地化与验收文档同步 |
| M | [docs/i18n/harmony-hand-strings.json](../../docs/i18n/harmony-hand-strings.json) | Paper 版本／本地化与验收文档同步 |
| M | [docs/i18n/keys.json](../../docs/i18n/keys.json) | Paper 版本／本地化与验收文档同步 |
| M | [docs/i18n/parts/01.tsv](../../docs/i18n/parts/01.tsv) | Paper 版本／本地化与验收文档同步 |
| M | [docs/i18n/parts/03.tsv](../../docs/i18n/parts/03.tsv) | Paper 版本／本地化与验收文档同步 |
| A | [docs/i18n/parts/08.tsv](../../docs/i18n/parts/08.tsv) | Paper 版本／本地化与验收文档同步 |
| M | [docs/i18n/translations.json](../../docs/i18n/translations.json) | Paper 版本／本地化与验收文档同步 |
| A | [docs/release/versioning.md](../../docs/release/versioning.md) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/AppScope/app.json5](../../harmonyos/AppScope/app.json5) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/AppScope/resources/base/element/string.json](../../harmonyos/AppScope/resources/base/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/AppScope/resources/en_US/element/string.json](../../harmonyos/AppScope/resources/en_US/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/README.md](../../harmonyos/README.md) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/ets/data/BackupService.ets](../../harmonyos/entry/src/main/ets/data/BackupService.ets) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/ets/data/FlashStore.ets](../../harmonyos/entry/src/main/ets/data/FlashStore.ets) | preserve recovery sources and serialize reminders |
| M | [harmonyos/entry/src/main/ets/data/IdeaReminderScheduler.ets](../../harmonyos/entry/src/main/ets/data/IdeaReminderScheduler.ets) | preserve recovery sources and serialize reminders |
| M | [harmonyos/entry/src/main/ets/pages/ProfilePage.ets](../../harmonyos/entry/src/main/ets/pages/ProfilePage.ets) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/ets/state/AppController.ets](../../harmonyos/entry/src/main/ets/state/AppController.ets) | preserve recovery sources and serialize reminders |
| M | [harmonyos/entry/src/main/resources/ar/element/string.json](../../harmonyos/entry/src/main/resources/ar/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/base/element/string.json](../../harmonyos/entry/src/main/resources/base/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/de/element/string.json](../../harmonyos/entry/src/main/resources/de/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/fr/element/string.json](../../harmonyos/entry/src/main/resources/fr/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/ja/element/string.json](../../harmonyos/entry/src/main/resources/ja/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/ko/element/string.json](../../harmonyos/entry/src/main/resources/ko/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/ru/element/string.json](../../harmonyos/entry/src/main/resources/ru/element/string.json) | Paper 版本／本地化与验收文档同步 |
| M | [harmonyos/entry/src/main/resources/zh/element/string.json](../../harmonyos/entry/src/main/resources/zh/element/string.json) | Paper 版本／本地化与验收文档同步 |
| A | [harmonyos/tests/merge-reminder-regressions.test.cjs](../../harmonyos/tests/merge-reminder-regressions.test.cjs) | preserve recovery sources and serialize reminders |
| A | [harmonyos/tests/recovery-preservation.test.cjs](../../harmonyos/tests/recovery-preservation.test.cjs) | preserve recovery sources and serialize reminders |
| M | [ios/Flash.xcodeproj/project.pbxproj](../../ios/Flash.xcodeproj/project.pbxproj) | Paper 版本／本地化与验收文档同步 |
| M | [ios/Flash/Localizable.xcstrings](../../ios/Flash/Localizable.xcstrings) | Paper 版本／本地化与验收文档同步 |
| M | [ios/Flash/UI/QuickCapture/QuickCaptureSheet.swift](../../ios/Flash/UI/QuickCapture/QuickCaptureSheet.swift) | isolate locked capture from private drafts |
| M | [ios/Flash/UI/Theme/AppLockWindow.swift](../../ios/Flash/UI/Theme/AppLockWindow.swift) | isolate locked capture from private drafts |
| M | [ios/FlashShare/Localizable.xcstrings](../../ios/FlashShare/Localizable.xcstrings) | Paper 版本／本地化与验收文档同步 |
| M | [ios/FlashShare/ShareViewController.swift](../../ios/FlashShare/ShareViewController.swift) | retain text alongside supported URL representations |
| A | [ios/FlashTests/LockedCaptureDraftTests.swift](../../ios/FlashTests/LockedCaptureDraftTests.swift) | isolate locked capture from private drafts |
| M | [ios/FlashWidget/Localizable.xcstrings](../../ios/FlashWidget/Localizable.xcstrings) | Paper 版本／本地化与验收文档同步 |
| M | [ios/README.md](../../ios/README.md) | Paper 版本／本地化与验收文档同步 |
| M | [macos/Flash.xcodeproj/project.pbxproj](../../macos/Flash.xcodeproj/project.pbxproj) | Paper 版本／本地化与验收文档同步 |
| A | [macos/Flash/App/AppLockSheetShield.swift](../../macos/Flash/App/AppLockSheetShield.swift) | shield private sheets while app is locked |
| M | [macos/Flash/FlashApp.swift](../../macos/Flash/FlashApp.swift) | shield private sheets while app is locked |
| M | [macos/Flash/UI/Settings/SettingsView.swift](../../macos/Flash/UI/Settings/SettingsView.swift) | use private diagnostics for backup failures |
| M | [macos/FlashInfo.plist](../../macos/FlashInfo.plist) | Paper 版本／本地化与验收文档同步 |
| A | [macos/FlashTests/AppLockSheetShieldTests.swift](../../macos/FlashTests/AppLockSheetShieldTests.swift) | shield private sheets while app is locked |
| M | [macos/FlashWidgetInfo.plist](../../macos/FlashWidgetInfo.plist) | Paper 版本／本地化与验收文档同步 |
| M | [macos/README.md](../../macos/README.md) | Paper 版本／本地化与验收文档同步 |
| M | [shared/FlashKit/Sources/FlashCore/Data/BackupImportCoordinator.swift](../../shared/FlashKit/Sources/FlashCore/Data/BackupImportCoordinator.swift) | Paper 版本／本地化与验收文档同步 |
| M | [shared/FlashKit/Sources/FlashCore/Data/FlashStoreLocation.swift](../../shared/FlashKit/Sources/FlashCore/Data/FlashStoreLocation.swift) | retain SQLite companions when migration fails |
| M | [shared/FlashKit/Sources/FlashCore/Data/SettingsStore.swift](../../shared/FlashKit/Sources/FlashCore/Data/SettingsStore.swift) | Paper 版本／本地化与验收文档同步 |
| M | [shared/FlashKit/Sources/FlashCore/Domain/PersonalLibrary.swift](../../shared/FlashKit/Sources/FlashCore/Domain/PersonalLibrary.swift) | precompute matching tags once per query |
| M | [shared/FlashKit/Sources/FlashDesign/Features/Calendar/TaskEditorView.swift](../../shared/FlashKit/Sources/FlashDesign/Features/Calendar/TaskEditorView.swift) | keep task identity across reminder failure retries |
| M | [shared/FlashKit/Sources/FlashDesign/Features/Settings/AboutSection.swift](../../shared/FlashKit/Sources/FlashDesign/Features/Settings/AboutSection.swift) | Paper 版本／本地化与验收文档同步 |
| M | [shared/FlashKit/Sources/FlashDesign/Features/Settings/LanTransferSheet.swift](../../shared/FlashKit/Sources/FlashDesign/Features/Settings/LanTransferSheet.swift) | Paper 版本／本地化与验收文档同步 |
| M | [shared/FlashKit/Tests/FlashCoreTests/FlashStoreLocationTests.swift](../../shared/FlashKit/Tests/FlashCoreTests/FlashStoreLocationTests.swift) | retain SQLite companions when migration fails |
| A | [shared/FlashKit/Tests/FlashCoreTests/LibraryFilterQueryTests.swift](../../shared/FlashKit/Tests/FlashCoreTests/LibraryFilterQueryTests.swift) | precompute matching tags once per query |
| A | [shared/FlashKit/Tests/FlashDesignTests/TaskEditorIdentityTests.swift](../../shared/FlashKit/Tests/FlashDesignTests/TaskEditorIdentityTests.swift) | keep task identity across reminder failure retries |
| M | [tools/i18n/generate.py](../../tools/i18n/generate.py) | Paper 版本／本地化与验收文档同步 |

共 94 个 app 仓库文件。

仓库外：`/Users/haydenjiang/Documents/flash-Alpha/CHANGELOG.md` 记录全部工作；工作区 `releases/README.md` 记录 Paper 候选与 Aero 最后 Beta 归档、不新增分发物；`outputs/paper-alpha1-audit-20261114/` 保存原始基线、源码归档、合成复现、构建／测试／性能日志、机器可读摘要及完整提交列表。

仅删除本轮产生的两只 Python .pyc 缓存，依据见 outputs 内 deleted-files.json；没有删除 Git 源码、真实备份、数据库、密钥或签名材料。
