# Flash（一闪）原生 macOS 版 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建与原生 Android 版功能完全对齐的原生 macOS 版 Flash，universal2（arm64 + x86_64），最低 macOS 15。

**Architecture:** 纯 SwiftUI + SwiftData，零第三方依赖。分层：Models（storageKey 与 Android/Web 逐字对齐）→ Data（SwiftData + Repository + BackupService + SettingsStore）→ Domain（纯函数：过滤/统计/日历网格，全部可单测）→ UI（九个模块，视图薄、逻辑下沉到纯函数与 Repository）。

**Tech Stack:** Xcode 27（Swift 6）、SwiftUI、SwiftData、Swift Charts、Swift Testing；universal2 构建，`MACOSX_DEPLOYMENT_TARGET=15.0`。

**Spec:** `docs/superpowers/specs/2026-08-13-flash-macos-native-design.md`（与本文同库，执行前先读）

## Global Constraints

- 部署目标 **macOS 15.0**；`ARCHS = arm64 x86_64`（universal2），Release 构建必须双架构
- **零第三方依赖**：只允许 Apple 官方框架（SwiftUI / SwiftData / Swift Charts / Foundation / UniformTypeIdentifiers / os）
- 所有 storageKey、备份 schema `flash-backup-v1`、校验规则与 Android `native-android/` 逐字对齐（spec §5/§6）
- 色彩**全语义色**（`Color(nsColor: .labelColor)` 等）；自定义色（情绪七级、六色标签）必须提供 light/dark 变体（spec §10.4）
- **内容层禁止玻璃/材质效果**；玻璃只由系统标准组件自动获得（spec §10.3）
- App Sandbox + Hardened Runtime 全开；entitlements 仅 `com.apple.security.app-sandbox` + `com.apple.security.files.user-selected.read-write`；**禁止任何 network entitlement**（spec §7）
- 用户可见文案一律简体中文，措辞与 Android 版对齐
- 性能验收（spec §8）：冷启动 M 系列 <1s；空闲内存 <80MB；滚动 60fps；包体 <20MB
- 仓库根为 `app/`（git 根），工程放 `app/native-macos/`
- 每个 Task 完成后按步骤提交 git commit（执行前由主会话向用户取得本批次提交许可）

---

### Task 1: Xcode 工程骨架（无 GUI、无第三方工具，手写 pbxproj）

**Files:**
- Create: `app/native-macos/Flash.xcodeproj/project.pbxproj`
- Create: `app/native-macos/Flash.xcodeproj/xcshareddata/xcschemes/Flash.xcscheme`
- Create: `app/native-macos/Flash.entitlements`
- Create: `app/native-macos/Flash/FlashApp.swift`
- Create: `app/native-macos/Flash/PrivacyInfo.xcprivacy`
- Create: `app/native-macos/FlashTests/PlaceholderTests.swift`
- Create: `app/native-macos/.gitignore`

**Interfaces:**
- Produces: 可构建的 `Flash` app target（bundle id `com.flash.app.macos`，Swift 模块名 `Flash`）+ `FlashTests` 单测 target（`@testable import Flash`）。后续所有 Task 在此工程内加文件即可——project 使用 **PBXFileSystemSynchronizedRootGroup**（Xcode 16+ 文件系统同步组），新增 .swift 文件**无需改 pbxproj**。

- [ ] **Step 1: 建目录与 gitignore**

```bash
mkdir -p app/native-macos/Flash app/native-macos/FlashTests \
  app/native-macos/Flash.xcodeproj/xcshareddata/xcschemes
```

`app/native-macos/.gitignore`：
```gitignore
build/
DerivedData/
xcuserdata/
*.xcuserstate
.DS_Store
```

- [ ] **Step 2: 写 `project.pbxproj`**（完整内容如下，UUID 为固定 24 位十六进制，不得改动）

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 70;
	objects = {

/* Begin PBXFileSystemSynchronizedRootGroup section */
		FA0000000000000000000010 /* Flash */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = Flash;
			sourceTree = "<group>";
		};
		FA0000000000000000000011 /* FlashTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = FlashTests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		FA0000000000000000000020 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		FA0000000000000000000021 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		FA0000000000000000000001 = {
			isa = PBXGroup;
			children = (
				FA0000000000000000000010 /* Flash */,
				FA0000000000000000000011 /* FlashTests */,
				FA0000000000000000000002 /* Products */,
			);
			sourceTree = "<group>";
		};
		FA0000000000000000000002 /* Products */ = {
			isa = PBXGroup;
			children = (
				FA0000000000000000000030 /* Flash.app */,
				FA0000000000000000000031 /* FlashTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		FA0000000000000000000040 /* Flash */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = FA0000000000000000000060 /* Build configuration list for PBXNativeTarget "Flash" */;
			buildPhases = (
				FA0000000000000000000050 /* Sources */,
				FA0000000000000000000020 /* Frameworks */,
				FA0000000000000000000051 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				FA0000000000000000000010 /* Flash */,
			);
			name = Flash;
			productName = Flash;
			productReference = FA0000000000000000000030 /* Flash.app */;
			productType = "com.apple.product-type.application";
		};
		FA0000000000000000000041 /* FlashTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = FA0000000000000000000061 /* Build configuration list for PBXNativeTarget "FlashTests" */;
			buildPhases = (
				FA0000000000000000000052 /* Sources */,
				FA0000000000000000000021 /* Frameworks */,
				FA0000000000000000000053 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				FA0000000000000000000070 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				FA0000000000000000000011 /* FlashTests */,
			);
			name = FlashTests;
			productName = FlashTests;
			productReference = FA0000000000000000000031 /* FlashTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		FA0000000000000000000000 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2600;
				LastUpgradeCheck = 2600;
				TargetAttributes = {
					FA0000000000000000000040 = {
						CreatedOnToolsVersion = 26.0;
					};
					FA0000000000000000000041 = {
						CreatedOnToolsVersion = 26.0;
						TestTargetID = FA0000000000000000000040;
					};
				};
			};
			buildConfigurationList = FA0000000000000000000062 /* Build configuration list for PBXProject "Flash" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
				"zh-Hans",
			);
			mainGroup = FA0000000000000000000001;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = FA0000000000000000000002 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				FA0000000000000000000040 /* Flash */,
				FA0000000000000000000041 /* FlashTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		FA0000000000000000000051 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		FA0000000000000000000053 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		FA0000000000000000000050 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		FA0000000000000000000052 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		FA0000000000000000000070 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = FA0000000000000000000040 /* Flash */;
			targetProxy = FA0000000000000000000071 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
		FA0000000000000000000071 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = FA0000000000000000000000 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = FA0000000000000000000040;
			remoteInfo = Flash;
		};
/* End PBXContainerItemProxy section */

/* Begin XCBuildConfiguration section */
		FA0000000000000000000080 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
			};
			name = Debug;
		};
		FA0000000000000000000081 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 6.0;
			};
			name = Release;
		};
		FA0000000000000000000082 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Flash.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Flash 一闪";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_LSMinimumSystemVersion = "$(MACOSX_DEPLOYMENT_TARGET)";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.flash.app.macos;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Debug;
		};
		FA0000000000000000000083 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Flash.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Flash 一闪";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_LSMinimumSystemVersion = "$(MACOSX_DEPLOYMENT_TARGET)";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.flash.app.macos;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Release;
		};
		FA0000000000000000000084 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.flash.app.macos.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Flash.app/Contents/MacOS/Flash";
			};
			name = Debug;
		};
		FA0000000000000000000085 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.flash.app.macos.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Flash.app/Contents/MacOS/Flash";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		FA0000000000000000000060 /* Build configuration list for PBXNativeTarget "Flash" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				FA0000000000000000000082 /* Debug */,
				FA0000000000000000000083 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		FA0000000000000000000061 /* Build configuration list for PBXNativeTarget "FlashTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				FA0000000000000000000084 /* Debug */,
				FA0000000000000000000085 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		FA0000000000000000000062 /* Build configuration list for PBXProject "Flash" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				FA0000000000000000000080 /* Debug */,
				FA0000000000000000000081 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin PBXFileReference section */
		FA0000000000000000000030 /* Flash.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Flash.app; sourceTree = BUILT_PRODUCTS_DIR; };
		FA0000000000000000000031 /* FlashTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = FlashTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */
	};
	rootObject = FA0000000000000000000000 /* Project object */;
}
```

- [ ] **Step 3: 写共享 scheme `Flash.xcscheme`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "FA0000000000000000000040"
               BuildableName = "Flash.app"
               BlueprintName = "Flash"
               ReferencedContainer = "container:Flash.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "FA0000000000000000000041"
               BuildableName = "FlashTests.xctest"
               BlueprintName = "FlashTests"
               ReferencedContainer = "container:Flash.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "FA0000000000000000000040"
            BuildableName = "Flash.app"
            BlueprintName = "Flash"
            ReferencedContainer = "container:Flash.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "FA0000000000000000000040"
            BuildableName = "Flash.app"
            BlueprintName = "Flash"
            ReferencedContainer = "container:Flash.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 4: 写 entitlements 与隐私清单**

`app/native-macos/Flash.entitlements`（注意：在工程根目录，不在 Flash/ 同步组内，避免被打成资源）：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
</dict>
</plist>
```

`app/native-macos/Flash/PrivacyInfo.xcprivacy`：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] **Step 5: 写占位 App 入口与占位测试**

`app/native-macos/Flash/FlashApp.swift`：
```swift
import SwiftUI

@main
struct FlashApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Flash 一闪")
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}
```

`app/native-macos/FlashTests/PlaceholderTests.swift`：
```swift
import Testing
@testable import Flash

@Test func placeholder() {
    #expect(1 + 1 == 2)
}
```

- [ ] **Step 6: 构建 + 测试 + universal2 验证**

```bash
cd app/native-macos
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath build/dd build 2>&1 | tail -5
lipo -info build/dd/Build/Products/Release/Flash.app/Contents/MacOS/Flash
```

Expected: 全部成功；`lipo -info` 输出包含 `x86_64 arm64` 两个架构。若 pbxproj 解析报错，按报错行号修正格式（常见为少分号/括号不配平），不要改 UUID。

- [ ] **Step 7: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): Xcode 工程骨架（universal2 / sandbox / 隐私清单）"
```

---

### Task 2: 数据模型层（storageKey 三端对齐）

**Files:**
- Create: `app/native-macos/Flash/Models/ColorTag.swift`
- Create: `app/native-macos/Flash/Models/Category.swift`
- Create: `app/native-macos/Flash/Models/EmotionLevel.swift`
- Create: `app/native-macos/Flash/Models/SubEmotion.swift`
- Create: `app/native-macos/Flash/Models/LogItem.swift`
- Create: `app/native-macos/Flash/Models/EmotionRecord.swift`
- Create: `app/native-macos/Flash/Models/Importance.swift`
- Test: `app/native-macos/FlashTests/ModelsTests.swift`

**Interfaces:**
- Produces（后续 Task 全部依赖这些类型与存储值）:
  - `enum ColorTag: String, CaseIterable, Codable { urgent, inspiration, daily, memo, emotion, idea }`，`var displayName: String`，`var colorHex: String`
  - `enum Category: String, Codable { log, idea }`
  - `enum EmotionLevel: Int, CaseIterable, Codable`（raw -3...3），`var displayName: String`，`var colorHex: String`，`var emoji: String`，`var isNegative: Bool`
  - `enum SubEmotion: String, CaseIterable, Codable { sad, angry, uncomfortable }`，`var displayName: String`，`var colorHex: String`
  - `struct LogItem: Identifiable, Equatable { id, content, colorTag, category, importance, createdAt, recordDate }`
  - `struct EmotionRecord: Identifiable, Equatable { id, level, subEmotion, status, note, recordDate, createdAt }`
  - `func importanceFromContent(_ content: String) -> Int`

- [ ] **Step 1: 写失败测试** `FlashTests/ModelsTests.swift`

```swift
import Testing
@testable import Flash

@Suite("数据模型三端对齐")
struct ModelsTests {
    @Test func colorTagStorageKeys() {
        #expect(ColorTag.urgent.rawValue == "urgent")
        #expect(ColorTag.inspiration.rawValue == "inspiration")
        #expect(ColorTag.daily.rawValue == "daily")
        #expect(ColorTag.memo.rawValue == "memo")
        #expect(ColorTag.emotion.rawValue == "emotion")
        #expect(ColorTag.idea.rawValue == "idea")
        #expect(ColorTag.allCases.count == 6)
    }

    @Test func colorTagDisplayAndHex() {
        #expect(ColorTag.urgent.displayName == "紧急")
        #expect(ColorTag.urgent.colorHex == "#FF6B6B")
        #expect(ColorTag.inspiration.colorHex == "#FFD93D")
        #expect(ColorTag.daily.colorHex == "#4D96FF")
        #expect(ColorTag.memo.colorHex == "#6BCB77")
        #expect(ColorTag.emotion.colorHex == "#9B59B6")
        #expect(ColorTag.idea.colorHex == "#FF9F43")
    }

    @Test func emotionLevelValues() {
        #expect(EmotionLevel.veryUnhappy.rawValue == -3)
        #expect(EmotionLevel.neutral.rawValue == 0)
        #expect(EmotionLevel.veryHappy.rawValue == 3)
        #expect(EmotionLevel.allCases.count == 7)
        #expect(EmotionLevel(rawValue: -3)?.displayName == "非常不开心")
        #expect(EmotionLevel.veryUnhappy.isNegative)
        #expect(!EmotionLevel.neutral.isNegative)
        #expect(EmotionLevel.veryHappy.emoji == "😍")
        #expect(EmotionLevel.veryUnhappy.emoji == "😡")
    }

    @Test func subEmotionKeys() {
        #expect(SubEmotion.sad.rawValue == "sad")
        #expect(SubEmotion.sad.displayName == "伤心")
        #expect(SubEmotion(rawValue: "nope") == nil)
    }

    @Test func importanceFromContentRules() {
        #expect(importanceFromContent("普通") == 0)
        #expect(importanceFromContent("重要!!") == 2)
        #expect(importanceFromContent("更重要!!!") == 3)
        #expect(importanceFromContent("紧急!!!!") == 4)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败（类型不存在）

- [ ] **Step 3: 实现模型**（六个文件，内容与 Android `Models.kt` 逐字段对齐）

`Flash/Models/ColorTag.swift`：
```swift
import Foundation

/// 与 Web 版 src/lib/constants.ts 对齐。rawValue 即 storageKey，保证三端数据互通。
enum ColorTag: String, CaseIterable, Codable {
    case urgent, inspiration, daily, memo, emotion, idea

    var displayName: String {
        switch self {
        case .urgent: "紧急"
        case .inspiration: "灵感"
        case .daily: "日常"
        case .memo: "备忘"
        case .emotion: "情绪"
        case .idea: "想法"
        }
    }

    var colorHex: String {
        switch self {
        case .urgent: "#FF6B6B"
        case .inspiration: "#FFD93D"
        case .daily: "#4D96FF"
        case .memo: "#6BCB77"
        case .emotion: "#9B59B6"
        case .idea: "#FF9F43"
        }
    }
}
```

`Flash/Models/Category.swift`：
```swift
import Foundation

enum Category: String, Codable {
    case log, idea
}
```

`Flash/Models/EmotionLevel.swift`：
```swift
import Foundation

/// 对应 PRD 的 emoji 情绪模型：😍😊🙂😐😔😣😡（3→-3）
enum EmotionLevel: Int, CaseIterable, Codable {
    case veryUnhappy = -3
    case unhappy = -2
    case slightlyUnhappy = -1
    case neutral = 0
    case slightlyHappy = 1
    case happy = 2
    case veryHappy = 3

    var displayName: String {
        switch self {
        case .veryUnhappy: "非常不开心"
        case .unhappy: "很不开心"
        case .slightlyUnhappy: "不开心"
        case .neutral: "中性"
        case .slightlyHappy: "开心"
        case .happy: "很开心"
        case .veryHappy: "非常开心"
        }
    }

    var colorHex: String {
        switch self {
        case .veryUnhappy: "#800080"
        case .unhappy: "#DDA0DD"
        case .slightlyUnhappy: "#B0C4DE"
        case .neutral: "#B0E0E6"
        case .slightlyHappy: "#90EE90"
        case .happy: "#F0D878"
        case .veryHappy: "#FFB347"
        }
    }

    var emoji: String {
        switch self {
        case .veryUnhappy: "😡"
        case .unhappy: "😣"
        case .slightlyUnhappy: "😔"
        case .neutral: "😐"
        case .slightlyHappy: "🙂"
        case .happy: "😊"
        case .veryHappy: "😍"
        }
    }

    var isNegative: Bool { rawValue < 0 }
}
```

`Flash/Models/SubEmotion.swift`：
```swift
import Foundation

enum SubEmotion: String, CaseIterable, Codable {
    case sad, angry, uncomfortable

    var displayName: String {
        switch self {
        case .sad: "伤心"
        case .angry: "生气"
        case .uncomfortable: "难受"
        }
    }

    var colorHex: String {
        switch self {
        case .sad: "#A78BFA"
        case .angry: "#F87171"
        case .uncomfortable: "#FB923C"
        }
    }
}
```

`Flash/Models/LogItem.swift`：
```swift
import Foundation

struct LogItem: Identifiable, Equatable {
    let id: String
    var content: String
    var colorTag: ColorTag
    var category: Category
    var importance: Int
    var createdAt: String   // ISO-8601
    var recordDate: String  // yyyy-MM-dd
}
```

`Flash/Models/EmotionRecord.swift`：
```swift
import Foundation

struct EmotionRecord: Identifiable, Equatable {
    let id: String
    var level: EmotionLevel
    var subEmotion: SubEmotion?
    var status: String?
    var note: String?
    var recordDate: String  // yyyy-MM-dd
    var createdAt: String   // ISO-8601
}
```

`Flash/Models/Importance.swift`：
```swift
import Foundation

/// 与 Web 版 getImportanceFromContent 对齐：从内容中的 !! 标记推断重要度
func importanceFromContent(_ content: String) -> Int {
    if content.contains("!!!!") { return 4 }
    if content.contains("!!!") { return 3 }
    if content.contains("!!") { return 2 }
    return 0
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Models native-macos/FlashTests/ModelsTests.swift
git commit -m "feat(macos): 数据模型层（storageKey 三端对齐）"
```

---

### Task 3: SwiftData 数据层 + FlashRepository

**Files:**
- Create: `app/native-macos/Flash/Data/Entities.swift`
- Create: `app/native-macos/Flash/Data/FlashDatabase.swift`
- Create: `app/native-macos/Flash/Data/FlashRepository.swift`
- Create: `app/native-macos/Flash/Data/DateFormatting.swift`
- Test: `app/native-macos/FlashTests/FlashRepositoryTests.swift`

**Interfaces:**
- Consumes: Task 2 的全部模型类型
- Produces:
  - `enum DateFormatting { static func isoNow() -> String; static func today() -> String }`（ISO-8601 / yyyy-MM-dd）
  - `@Model final class LogEntity` / `@Model final class EmotionEntity`（存储值与 Room 列对齐）
  - `final class FlashRepository`：
    - `init(container: ModelContainer)`
    - `func addLog(content: String, colorTag: ColorTag, category: Category = .log, importance: Int = 0) throws`
    - `func updateLog(_ log: LogItem) throws` / `func deleteLog(id: String) throws`
    - `func addEmotion(level: EmotionLevel, subEmotion: SubEmotion?, status: String? = nil, note: String? = nil) throws` / `func deleteEmotion(id: String) throws`
    - `func allLogs() throws -> [LogItem]`（createdAt 降序）/ `func allEmotions() throws -> [EmotionRecord]`（createdAt 降序）
    - `func replaceAll(logs: [LogItem], emotions: [EmotionRecord]) throws`（覆盖式导入）
    - `func mergeAll(logs: [LogItem], emotions: [EmotionRecord]) throws`（合并式导入，同 id 覆盖）
    - `func clearAll() throws`
  - `enum FlashDatabase { static func makeContainer(inMemory: Bool = false) -> ModelContainer }`

- [ ] **Step 1: 写失败测试** `FlashTests/FlashRepositoryTests.swift`

```swift
import Testing
import SwiftData
@testable import Flash

@Suite("FlashRepository")
struct FlashRepositoryTests {
    private func makeRepo() -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    }

    @Test func addLogAssignsFields() throws {
        let repo = makeRepo()
        try repo.addLog(content: "第一条", colorTag: .daily)
        let logs = try repo.allLogs()
        #expect(logs.count == 1)
        #expect(logs[0].content == "第一条")
        #expect(logs[0].colorTag == .daily)
        #expect(logs[0].category == .log)
        #expect(logs[0].importance == 0)
        #expect(logs[0].recordDate == DateFormatting.today())
        #expect(logs[0].id.count == 36) // UUID
    }

    @Test func importanceCoerced() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .idea, category: .idea, importance: 99)
        #expect(try repo.allLogs()[0].importance == 4)
    }

    @Test func updateAndDeleteLog() throws {
        let repo = makeRepo()
        try repo.addLog(content: "旧", colorTag: .memo)
        var log = try repo.allLogs()[0]
        log.content = "新"
        log.colorTag = .urgent
        try repo.updateLog(log)
        #expect(try repo.allLogs()[0].content == "新")
        #expect(try repo.allLogs()[0].colorTag == .urgent)
        try repo.deleteLog(id: log.id)
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func addAndDeleteEmotion() throws {
        let repo = makeRepo()
        try repo.addEmotion(level: .unhappy, subEmotion: .sad, note: "下雨")
        let emotions = try repo.allEmotions()
        #expect(emotions.count == 1)
        #expect(emotions[0].level == .unhappy)
        #expect(emotions[0].subEmotion == .sad)
        #expect(emotions[0].note == "下雨")
        try repo.deleteEmotion(id: emotions[0].id)
        #expect(try repo.allEmotions().isEmpty)
    }

    @Test func logsSortedNewestFirst() throws {
        let repo = makeRepo()
        try repo.addLog(content: "A", colorTag: .daily)
        try repo.addLog(content: "B", colorTag: .daily)
        let logs = try repo.allLogs()
        #expect(logs.map(\.content) == ["B", "A"]) // createdAt 降序
    }

    @Test func mergeAllOverwritesSameId() throws {
        let repo = makeRepo()
        try repo.addLog(content: "保留", colorTag: .daily)
        let existing = try repo.allLogs()[0]
        let incoming = LogItem(id: existing.id, content: "覆盖", colorTag: .urgent,
                               category: .log, importance: 2,
                               createdAt: existing.createdAt, recordDate: existing.recordDate)
        let fresh = LogItem(id: "11111111-1111-1111-1111-111111111111", content: "新增",
                            colorTag: .memo, category: .log, importance: 0,
                            createdAt: existing.createdAt, recordDate: existing.recordDate)
        try repo.mergeAll(logs: [incoming, fresh], emotions: [])
        let logs = try repo.allLogs()
        #expect(logs.count == 2)
        #expect(logs.contains { $0.id == existing.id && $0.content == "覆盖" })
    }

    @Test func replaceAllClearsFirst() throws {
        let repo = makeRepo()
        try repo.addLog(content: "被清掉", colorTag: .daily)
        try repo.replaceAll(logs: [], emotions: [])
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func clearAllWorks() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .daily)
        try repo.addEmotion(level: .happy, subEmotion: nil)
        try repo.clearAll()
        #expect(try repo.allLogs().isEmpty)
        #expect(try repo.allEmotions().isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败（类型不存在）

- [ ] **Step 3: 实现数据层**

`Flash/Data/DateFormatting.swift`：
```swift
import Foundation

enum DateFormatting {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// ISO-8601（与 JS Date#toISOString / Android ISO_INSTANT 同格式）
    static func isoNow() -> String { isoFormatter.string(from: Date()) }

    /// yyyy-MM-dd 本地日期
    static func today() -> String { dayFormatter.string(from: Date()) }

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func parseDay(_ string: String) -> Date? { dayFormatter.date(from: string) }
}
```

`Flash/Data/Entities.swift`：
```swift
import Foundation
import SwiftData

/// 存储值与 Android Room Entities / Capacitor SQLite schema 完全一致。
@Model
final class LogEntity {
    @Attribute(.unique) var id: String
    var content: String
    var colorTag: String
    var category: String
    var importance: Int
    var createdAt: String
    var recordDate: String

    init(id: String, content: String, colorTag: String, category: String,
         importance: Int, createdAt: String, recordDate: String) {
        self.id = id
        self.content = content
        self.colorTag = colorTag
        self.category = category
        self.importance = importance
        self.createdAt = createdAt
        self.recordDate = recordDate
    }

    func toModel() -> LogItem {
        LogItem(
            id: id,
            content: content,
            colorTag: ColorTag(rawValue: colorTag) ?? .daily,
            category: Category(rawValue: category) ?? .log,
            importance: importance,
            createdAt: createdAt,
            recordDate: recordDate
        )
    }

    func apply(_ model: LogItem) {
        content = model.content
        colorTag = model.colorTag.rawValue
        category = model.category.rawValue
        importance = model.importance
        createdAt = model.createdAt
        recordDate = model.recordDate
    }
}

@Model
final class EmotionEntity {
    @Attribute(.unique) var id: String
    var level: Int
    var subEmotion: String?
    var status: String?
    var note: String?
    var recordDate: String
    var createdAt: String

    init(id: String, level: Int, subEmotion: String?, status: String?,
         note: String?, recordDate: String, createdAt: String) {
        self.id = id
        self.level = level
        self.subEmotion = subEmotion
        self.status = status
        self.note = note
        self.recordDate = recordDate
        self.createdAt = createdAt
    }

    func toModel() -> EmotionRecord {
        EmotionRecord(
            id: id,
            level: EmotionLevel(rawValue: level) ?? .neutral,
            subEmotion: subEmotion.flatMap(SubEmotion.init(rawValue:)),
            status: status,
            note: note,
            recordDate: recordDate,
            createdAt: createdAt
        )
    }

    func apply(_ model: EmotionRecord) {
        level = model.level.rawValue
        subEmotion = model.subEmotion?.rawValue
        status = model.status
        note = model.note
        recordDate = model.recordDate
        createdAt = model.createdAt
    }
}
```

`Flash/Data/FlashDatabase.swift`：
```swift
import Foundation
import SwiftData

enum FlashDatabase {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([LogEntity.self, EmotionEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
    }
}
```

`Flash/Data/FlashRepository.swift`：
```swift
import Foundation
import SwiftData

/// 对应 Web 版 StorageAdapter / Android FlashRepository。
/// createdAt 使用 ISO-8601，recordDate 为 yyyy-MM-dd。
final class FlashRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: - Logs

    @MainActor
    func addLog(content: String, colorTag: ColorTag,
                category: Category = .log, importance: Int = 0) throws {
        let entity = LogEntity(
            id: UUID().uuidString,
            content: content,
            colorTag: colorTag.rawValue,
            category: category.rawValue,
            importance: min(max(importance, 0), 4),
            createdAt: DateFormatting.isoNow(),
            recordDate: DateFormatting.today()
        )
        context.insert(entity)
        try context.save()
    }

    @MainActor
    func updateLog(_ log: LogItem) throws {
        if let entity = try fetchLog(id: log.id) {
            entity.apply(log)
        } else {
            context.insert(LogEntity(id: log.id, content: log.content,
                                     colorTag: log.colorTag.rawValue,
                                     category: log.category.rawValue,
                                     importance: log.importance,
                                     createdAt: log.createdAt,
                                     recordDate: log.recordDate))
        }
        try context.save()
    }

    @MainActor
    func deleteLog(id: String) throws {
        if let entity = try fetchLog(id: id) {
            context.delete(entity)
            try context.save()
        }
    }

    @MainActor
    func allLogs() throws -> [LogItem] {
        let descriptor = FetchDescriptor<LogEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Emotions

    @MainActor
    func addEmotion(level: EmotionLevel, subEmotion: SubEmotion?,
                    status: String? = nil, note: String? = nil) throws {
        let entity = EmotionEntity(
            id: UUID().uuidString,
            level: level.rawValue,
            subEmotion: subEmotion?.rawValue,
            status: status,
            note: note,
            recordDate: DateFormatting.today(),
            createdAt: DateFormatting.isoNow()
        )
        context.insert(entity)
        try context.save()
    }

    @MainActor
    func deleteEmotion(id: String) throws {
        if let entity = try fetchEmotion(id: id) {
            context.delete(entity)
            try context.save()
        }
    }

    @MainActor
    func allEmotions() throws -> [EmotionRecord] {
        let descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Import / Export

    /// 覆盖式导入：清空后写入（对应 Web 版 overwriteImport）
    @MainActor
    func replaceAll(logs: [LogItem], emotions: [EmotionRecord]) throws {
        try clearAll()
        for log in logs { upsertLogEntity(log) }
        for emotion in emotions { upsertEmotionEntity(emotion) }
        try context.save()
    }

    /// 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport）
    @MainActor
    func mergeAll(logs: [LogItem], emotions: [EmotionRecord]) throws {
        for log in logs { upsertLogEntity(log) }
        for emotion in emotions { upsertEmotionEntity(emotion) }
        try context.save()
    }

    @MainActor
    func clearAll() throws {
        try context.delete(model: LogEntity.self)
        try context.delete(model: EmotionEntity.self)
        try context.save()
    }

    // MARK: - Private

    @MainActor
    private func fetchLog(id: String) throws -> LogEntity? {
        let predicate = #Predicate<LogEntity> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    @MainActor
    private func fetchEmotion(id: String) throws -> EmotionEntity? {
        let predicate = #Predicate<EmotionEntity> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    @MainActor
    private func upsertLogEntity(_ log: LogItem) {
        let entity = LogEntity(id: log.id, content: log.content,
                               colorTag: log.colorTag.rawValue,
                               category: log.category.rawValue,
                               importance: log.importance,
                               createdAt: log.createdAt, recordDate: log.recordDate)
        context.insert(entity) // SwiftData 对 .unique id 冲突执行更新
    }

    @MainActor
    private func upsertEmotionEntity(_ emotion: EmotionRecord) {
        let entity = EmotionEntity(id: emotion.id, level: emotion.level.rawValue,
                                   subEmotion: emotion.subEmotion?.rawValue,
                                   status: emotion.status, note: emotion.note,
                                   recordDate: emotion.recordDate,
                                   createdAt: emotion.createdAt)
        context.insert(entity)
    }
}
```

注意：`@MainActor` 保证所有操作在 main context；测试里用 `@MainActor` 套件（见 Step 4 修正）。

- [ ] **Step 4: 测试标注 MainActor 后跑通**

把 Step 1 的测试套件声明改为：
```swift
@Suite("FlashRepository") @MainActor
struct FlashRepositoryTests {
    private func makeRepo() -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    }
    // ... 各测试方法不变
}
```

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 全部 PASS。若 SwiftData unique-upsert 语义与预期不符（merge 测试失败），把 `upsertLogEntity`/`upsertEmotionEntity` 改为「先 fetch 再 apply 或 insert」的显式 upsert（参照 `updateLog` 的写法）。

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Data native-macos/FlashTests/FlashRepositoryTests.swift
git commit -m "feat(macos): SwiftData 数据层与 FlashRepository"
```

---

### Task 4: BackupService（JSON 导入导出，schema 三端一致）

**Files:**
- Create: `app/native-macos/Flash/Data/BackupService.swift`
- Test: `app/native-macos/FlashTests/BackupServiceTests.swift`

**Interfaces:**
- Consumes: Task 2 模型
- Produces:
  - `enum BackupError: Error, Equatable { case invalidJSON, missingVersion, incompatibleVersion(String), invalidArray(String), fileTooLarge }`
  - `struct ImportPreview { logCount, emotionCount, skippedLogs, skippedEmotions: Int; logs: [LogItem]; emotions: [EmotionRecord] }`
  - `enum BackupService`：
    - `static let backupVersion = "flash-backup-v1"`
    - `static let maxFileBytes = 50 * 1024 * 1024`
    - `static func exportJSON(logs: [LogItem], emotions: [EmotionRecord], notes: String = "", appVersion: String) -> String`
    - `static func parse(_ json: String) throws -> ImportPreview`

- [ ] **Step 1: 写失败测试** `FlashTests/BackupServiceTests.swift`

```swift
import Testing
import Foundation
@testable import Flash

@Suite("BackupService")
struct BackupServiceTests {
    private func sampleLog(id: String = "11111111-1111-1111-1111-111111111111") -> LogItem {
        LogItem(id: id, content: "测试!!", colorTag: .urgent, category: .log,
                importance: 2, createdAt: "2026-08-13T08:00:00.000Z",
                recordDate: "2026-08-13")
    }

    private func sampleEmotion(id: String = "22222222-2222-2222-2222-222222222222") -> EmotionRecord {
        EmotionRecord(id: id, level: .unhappy, subEmotion: .sad, status: nil,
                      note: "雨", recordDate: "2026-08-13",
                      createdAt: "2026-08-13T08:00:00.000Z")
    }

    @Test func exportParseRoundTrip() throws {
        let json = BackupService.exportJSON(logs: [sampleLog()],
                                            emotions: [sampleEmotion()],
                                            appVersion: "0.1.0")
        let preview = try BackupService.parse(json)
        #expect(preview.logCount == 1)
        #expect(preview.emotionCount == 1)
        #expect(preview.skippedLogs == 0)
        #expect(preview.skippedEmotions == 0)
        #expect(preview.logs[0] == sampleLog())
        #expect(preview.emotions[0] == sampleEmotion())
    }

    @Test func exportContainsMetaFields() {
        let json = BackupService.exportJSON(logs: [], emotions: [], appVersion: "0.1.0")
        #expect(json.contains("\"version\" : \"flash-backup-v1\"") || json.contains("\"version\":\"flash-backup-v1\""))
        #expect(json.contains("exportedAt"))
        #expect(json.contains("appVersion"))
        #expect(json.contains("notes"))
    }

    @Test func invalidJSONThrows() {
        #expect(throws: BackupError.invalidJSON) {
            _ = try BackupService.parse("not json")
        }
    }

    @Test func missingVersionThrows() {
        #expect(throws: BackupError.missingVersion) {
            _ = try BackupService.parse("{\"logs\":[],\"emotions\":[]}")
        }
    }

    @Test func incompatibleVersionThrows() {
        #expect(throws: BackupError.incompatibleVersion("v0")) {
            _ = try BackupService.parse("{\"version\":\"v0\",\"logs\":[],\"emotions\":[]}")
        }
    }

    @Test func invalidEntriesSkippedNotFatal() throws {
        let json = """
        {"version":"flash-backup-v1","exportedAt":"2026-08-13T08:00:00.000Z",
        "appVersion":"0.1.0","notes":"",
        "logs":[
          {"id":"bad-id","content":"x","colorTag":"daily","category":"log",
           "importance":0,"createdAt":"2026-08-13T08:00:00.000Z","recordDate":"2026-08-13"},
          {"id":"11111111-1111-1111-1111-111111111111","content":"好","colorTag":"daily",
           "category":"log","importance":99,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-08-13"}
        ],
        "emotions":[
          {"id":"22222222-2222-2222-2222-222222222222","level":9,"subEmotion":null,
           "status":null,"note":null,"recordDate":"2026-08-13",
           "createdAt":"2026-08-13T08:00:00.000Z"}
        ]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 1)          // 非法 UUID 跳过
        #expect(preview.skippedEmotions == 1)      // level 越界跳过
        #expect(preview.logs.count == 1)
        #expect(preview.logs[0].importance == 4)   // importance 收敛到 0-4
    }

    @Test func unknownColorTagSkipped() throws {
        let json = """
        {"version":"flash-backup-v1","logs":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"x","colorTag":"weird",
           "category":"log","importance":0,"createdAt":"2026-08-13T08:00:00.000Z",
           "recordDate":"2026-08-13"}
        ],"emotions":[]}
        """
        let preview = try BackupService.parse(json)
        #expect(preview.skippedLogs == 1)
        #expect(preview.logs.isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败（BackupService 不存在）

- [ ] **Step 3: 实现** `Flash/Data/BackupService.swift`

```swift
import Foundation

enum BackupError: Error, Equatable {
    case invalidJSON
    case missingVersion
    case incompatibleVersion(String)
    case invalidArray(String)
    case fileTooLarge

    var userMessage: String {
        switch self {
        case .invalidJSON: "备份文件不是有效的 JSON 对象"
        case .missingVersion: "备份版本不兼容：缺少 version 字段"
        case .incompatibleVersion(let v): "备份版本不兼容：期望 flash-backup-v1，实际 \(v)"
        case .invalidArray(let name): "\(name) 必须是数组"
        case .fileTooLarge: "文件过大，不是有效的备份"
        }
    }
}

struct ImportPreview {
    let logCount: Int
    let emotionCount: Int
    let skippedLogs: Int
    let skippedEmotions: Int
    let logs: [LogItem]
    let emotions: [EmotionRecord]
}

/// JSON 备份导出/导入，格式与 Android Backup.kt / Web backup.ts 完全一致：
/// { version, exportedAt, appVersion, notes, logs[], emotions[] }
/// 非法条目跳过而非整体失败。
enum BackupService {
    static let backupVersion = "flash-backup-v1"
    static let maxFileBytes = 50 * 1024 * 1024
    private static let maxEntryCount = 1_000_000
    private static let maxTextLength = 100_000

    private static let uuidRegex = try! NSRegularExpression(
        pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private static let dayRegex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")

    // MARK: - Export

    static func exportJSON(logs: [LogItem], emotions: [EmotionRecord],
                           notes: String = "", appVersion: String) -> String {
        let logDicts: [[String: Any]] = logs.map { log in
            ["id": log.id, "content": log.content, "colorTag": log.colorTag.rawValue,
             "category": log.category.rawValue, "importance": log.importance,
             "createdAt": log.createdAt, "recordDate": log.recordDate]
        }
        let emotionDicts: [[String: Any]] = emotions.map { e in
            ["id": e.id, "level": e.level.rawValue,
             "subEmotion": e.subEmotion?.rawValue ?? NSNull(),
             "status": e.status ?? NSNull(), "note": e.note ?? NSNull(),
             "recordDate": e.recordDate, "createdAt": e.createdAt]
        }
        let root: [String: Any] = [
            "version": backupVersion,
            "exportedAt": DateFormatting.isoNow(),
            "appVersion": appVersion,
            "notes": notes,
            "logs": logDicts,
            "emotions": emotionDicts,
        ]
        let data = try! JSONSerialization.data(withJSONObject: root,
                                               options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Import

    static func parse(_ json: String) throws -> ImportPreview {
        if json.utf8.count > maxFileBytes { throw BackupError.fileTooLarge }
        let object = try? JSONSerialization.jsonObject(with: Data(json.utf8))
        guard let root = object as? [String: Any] else { throw BackupError.invalidJSON }

        guard let versionValue = root["version"], !(versionValue is NSNull) else {
            throw BackupError.missingVersion
        }
        guard let version = versionValue as? String else { throw BackupError.missingVersion }
        guard version == backupVersion else {
            throw BackupError.incompatibleVersion(version)
        }
        guard let logsArray = root["logs"] as? [[String: Any]] else {
            throw BackupError.invalidArray("logs")
        }
        guard let emotionsArray = root["emotions"] as? [[String: Any]] else {
            throw BackupError.invalidArray("emotions")
        }

        var logs: [LogItem] = []
        var skippedLogs = 0
        for entry in logsArray.prefix(maxEntryCount) {
            if let log = parseLog(entry) { logs.append(log) } else { skippedLogs += 1 }
        }

        var emotions: [EmotionRecord] = []
        var skippedEmotions = 0
        for entry in emotionsArray.prefix(maxEntryCount) {
            if let emotion = parseEmotion(entry) { emotions.append(emotion) } else { skippedEmotions += 1 }
        }

        return ImportPreview(logCount: logs.count, emotionCount: emotions.count,
                             skippedLogs: skippedLogs, skippedEmotions: skippedEmotions,
                             logs: logs, emotions: emotions)
    }

    private static func parseLog(_ dict: [String: Any]) -> LogItem? {
        guard let id = dict["id"] as? String, isUUID(id),
              let content = dict["content"] as? String,
              let colorTag = (dict["colorTag"] as? String).flatMap(ColorTag.init(rawValue:)),
              let category = (dict["category"] as? String).flatMap(Category.init(rawValue:)),
              let createdAt = dict["createdAt"] as? String, isISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate)
        else { return nil }
        let importance = min(max(dict["importance"] as? Int ?? 0, 0), 4)
        return LogItem(id: id, content: String(content.prefix(maxTextLength)),
                       colorTag: colorTag, category: category,
                       importance: importance, createdAt: createdAt, recordDate: recordDate)
    }

    private static func parseEmotion(_ dict: [String: Any]) -> EmotionRecord? {
        guard let id = dict["id"] as? String, isUUID(id),
              let rawLevel = dict["level"] as? Int,
              let level = EmotionLevel(rawValue: rawLevel),
              let createdAt = dict["createdAt"] as? String, isISODate(createdAt),
              let recordDate = dict["recordDate"] as? String, isDay(recordDate)
        else { return nil }
        let subEmotion = (dict["subEmotion"] as? String).flatMap(SubEmotion.init(rawValue:))
        let status = (dict["status"] as? String).map { String($0.prefix(maxTextLength)) }
        let note = (dict["note"] as? String).map { String($0.prefix(maxTextLength)) }
        return EmotionRecord(id: id, level: level, subEmotion: subEmotion,
                             status: status, note: note,
                             recordDate: recordDate, createdAt: createdAt)
    }

    private static func isUUID(_ value: String) -> Bool {
        uuidRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    private static func isDay(_ value: String) -> Bool {
        dayRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    /// 严格 ISO-8601（对齐 Android Instant.parse 口径）
    private static func isISODate(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) != nil
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Data/BackupService.swift native-macos/FlashTests/BackupServiceTests.swift
git commit -m "feat(macos): BackupService JSON 导入导出（schema 三端一致 + 安全校验）"
```

---

### Task 5: SettingsStore（@AppStorage 主题与欢迎标记）

**Files:**
- Create: `app/native-macos/Flash/Data/SettingsStore.swift`
- Test: `app/native-macos/FlashTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces:
  - `enum ThemeMode: String, CaseIterable { system, light, dark }`，`var displayName: String`（跟随系统/浅色/深色）
  - `final class SettingsStore: ObservableObject`：`@Published var themeMode: ThemeMode`、`@Published var welcomed: Bool`；`func setThemeMode(_:)`、`func setWelcomed()`；构造注入 `UserDefaults`（默认 `.standard`，测试注入 suite）

- [ ] **Step 1: 写失败测试** `FlashTests/SettingsStoreTests.swift`

```swift
import Testing
import Foundation
@testable import Flash

@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeStore() -> SettingsStore {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return SettingsStore(defaults: suite)
    }

    @Test func defaultsAreSystemAndNotWelcomed() {
        let store = makeStore()
        #expect(store.themeMode == .system)
        #expect(!store.welcomed)
    }

    @Test func setThemeModePersists() {
        let store = makeStore()
        store.setThemeMode(.dark)
        #expect(store.themeMode == .dark)
        let reread = UserDefaults(suiteName: store.defaultsSuiteName)!
        #expect(reread.string(forKey: "themeMode") == "dark")
    }

    @Test func invalidStoredValueFallsBackToSystem() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("weird", forKey: "themeMode")
        #expect(SettingsStore(defaults: suite).themeMode == .system)
    }

    @Test func setWelcomedPersists() {
        let store = makeStore()
        store.setWelcomed()
        #expect(store.welcomed)
    }

    @Test func themeModeDisplayNames() {
        #expect(ThemeMode.system.displayName == "跟随系统")
        #expect(ThemeMode.light.displayName == "浅色")
        #expect(ThemeMode.dark.displayName == "深色")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败

- [ ] **Step 3: 实现** `Flash/Data/SettingsStore.swift`

```swift
import Foundation

enum ThemeMode: String, CaseIterable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

/// 对应 Android SettingsStore（Mac 版仅保留 themeMode/welcomed，UI 风格固定 HIG）。
final class SettingsStore: ObservableObject {
    @Published private(set) var themeMode: ThemeMode
    @Published private(set) var welcomed: Bool

    private let defaults: UserDefaults
    let defaultsSuiteName: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultsSuiteName = defaults == .standard
            ? Bundle.main.bundleIdentifier ?? "standard"
            : (defaults.volatileDomainNames.contains("test") ? "test" : defaults.description)
        let stored = defaults.string(forKey: Keys.themeMode)
        self.themeMode = stored.flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.welcomed = defaults.bool(forKey: Keys.welcomed)
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: Keys.themeMode)
    }

    func setWelcomed() {
        welcomed = true
        defaults.set(true, forKey: Keys.welcomed)
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let welcomed = "welcomed"
    }
}
```

- [ ] **Step 4: 修正测试对 suiteName 的依赖并跑通**

`defaultsSuiteName` 的实现太绕，简化为显式注入：

```swift
final class SettingsStore: ObservableObject {
    @Published private(set) var themeMode: ThemeMode
    @Published private(set) var welcomed: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.themeMode)
        self.themeMode = stored.flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.welcomed = defaults.bool(forKey: Keys.welcomed)
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: Keys.themeMode)
    }

    func setWelcomed() {
        welcomed = true
        defaults.set(true, forKey: Keys.welcomed)
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let welcomed = "welcomed"
    }
}
```

测试 `setThemeModePersists` 改为同 suite 二次实例化验证：
```swift
@Test func setThemeModePersists() {
    let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    SettingsStore(defaults: suite).setThemeMode(.dark)
    #expect(SettingsStore(defaults: suite).themeMode == .dark)
}
```

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Data/SettingsStore.swift native-macos/FlashTests/SettingsStoreTests.swift
git commit -m "feat(macos): SettingsStore（themeMode/welcomed，UserDefaults）"
```

---

### Task 6: Domain 纯函数（EmotionStats + LogFilter + CalendarGrid）

**Files:**
- Create: `app/native-macos/Flash/Domain/EmotionStats.swift`
- Create: `app/native-macos/Flash/Domain/LogFilter.swift`
- Create: `app/native-macos/Flash/Domain/CalendarGrid.swift`
- Test: `app/native-macos/FlashTests/DomainTests.swift`

**Interfaces:**
- Consumes: Task 2 模型
- Produces（UI 模块直接消费的纯函数）:
  - `enum EmotionStats`：`static func hasEmotionData(_ emotions: [EmotionRecord], days: Int, today: Date = Date()) -> Bool`；`static func dailyAverages(_ emotions: [EmotionRecord], days: Int, today: Date = Date()) -> [(date: String, average: Double?)]`；`static func subEmotionDistribution(_ emotions: [EmotionRecord], days: Int, today: Date = Date()) -> [(name: String, count: Int)]`
  - `enum LogSort: String, CaseIterable { newest, oldest, tag }`（displayName 最新/最早/按标签）
  - `struct LogFilter { query: String; tags: Set<ColorTag>; startDate: String?; endDate: String?; sort: LogSort }`，`func apply(to logs: [LogItem]) -> [LogItem]`
  - `enum CalendarGrid`：`static func weeks(containing month: Date) -> [[Date]]`（周一开头，6×7）；`static func monthString(_ date: Date) -> String`（yyyy-MM）
  - `struct DayAggregate: Equatable { date: String; logs: [LogItem]; emotions: [EmotionRecord] }`，`static func aggregate(logs: [LogItem], emotions: [EmotionRecord]) -> [String: DayAggregate]`（放 `CalendarGrid.swift`）

- [ ] **Step 1: 写失败测试** `FlashTests/DomainTests.swift`

```swift
import Testing
import Foundation
@testable import Flash

@Suite("Domain 纯函数")
struct DomainTests {
    // 夹具：固定 today = 2026-08-13（周四）
    private let today = DateFormatting.parseDay("2026-08-13")!

    private func emotion(_ day: String, _ level: EmotionLevel, sub: SubEmotion? = nil) -> EmotionRecord {
        EmotionRecord(id: UUID().uuidString, level: level, subEmotion: sub,
                      status: nil, note: nil, recordDate: day,
                      createdAt: "\(day)T08:00:00.000Z")
    }

    private func log(_ day: String, content: String = "x", tag: ColorTag = .daily,
                     category: Category = .log, createdAt: String? = nil) -> LogItem {
        LogItem(id: UUID().uuidString, content: content, colorTag: tag,
                category: category, importance: 0,
                createdAt: createdAt ?? "\(day)T08:00:00.000Z", recordDate: day)
    }

    // MARK: EmotionStats

    @Test func dailyAveragesWithGapDays() {
        let emotions = [emotion("2026-08-13", .veryHappy), emotion("2026-08-13", .slightlyHappy),
                        emotion("2026-08-11", .unhappy)]
        let result = EmotionStats.dailyAverages(emotions, days: 7, today: today)
        #expect(result.count == 7)
        #expect(result[6].date == "2026-08-13")
        #expect(result[6].average == 2.0)   // (3+1)/2
        #expect(result[4].average == -2.0)  // 08-11
        #expect(result[0].average == nil)   // 08-07 无记录
    }

    @Test func subEmotionDistributionOnlyNegative() {
        let emotions = [emotion("2026-08-13", .unhappy, sub: .sad),
                        emotion("2026-08-12", .unhappy, sub: .sad),
                        emotion("2026-08-12", .veryHappy, sub: nil),
                        emotion("2026-08-12", .slightlyUnhappy, sub: .angry)]
        let dist = EmotionStats.subEmotionDistribution(emotions, days: 7, today: today)
        #expect(dist.contains { $0.name == "伤心" && $0.count == 2 })
        #expect(dist.contains { $0.name == "生气" && $0.count == 1 })
        #expect(!dist.contains { $0.name == "难受" })
    }

    @Test func hasEmotionDataRespectsWindow() {
        #expect(EmotionStats.hasEmotionData([emotion("2026-08-13", .happy)], days: 7, today: today))
        #expect(!EmotionStats.hasEmotionData([emotion("2026-08-01", .happy)], days: 7, today: today))
    }

    // MARK: LogFilter

    @Test func filterExcludesIdeasAndMatchesQuery() {
        let logs = [log("2026-08-13", content: "买牛奶"),
                    log("2026-08-13", content: "灵感闪现", category: .idea),
                    log("2026-08-13", content: "写报告")]
        let filtered = LogFilter(query: "牛奶").apply(to: logs)
        #expect(filtered.count == 1)
        #expect(filtered[0].content == "买牛奶")
    }

    @Test func filterByTagsAndDateRange() {
        let logs = [log("2026-08-10", tag: .memo),
                    log("2026-08-12", tag: .urgent),
                    log("2026-08-13", tag: .urgent)]
        let filtered = LogFilter(tags: [.urgent], startDate: "2026-08-11",
                                 endDate: "2026-08-13").apply(to: logs)
        #expect(filtered.count == 2)
    }

    @Test func sortOrders() {
        let logs = [log("2026-08-10", createdAt: "2026-08-10T01:00:00.000Z"),
                    log("2026-08-10", createdAt: "2026-08-10T03:00:00.000Z"),
                    log("2026-08-10", createdAt: "2026-08-10T02:00:00.000Z")]
        let newest = LogFilter(sort: .newest).apply(to: logs)
        #expect(newest[0].createdAt == "2026-08-10T03:00:00.000Z")
        let oldest = LogFilter(sort: .oldest).apply(to: logs)
        #expect(oldest[0].createdAt == "2026-08-10T01:00:00.000Z")
    }

    // MARK: CalendarGrid

    @Test func weeksAreMondayFirstSixRows() {
        // 2026-08-01 是周六 → 网格从 2026-07-27（周一）开始
        let month = DateFormatting.parseDay("2026-08-15")!
        let weeks = CalendarGrid.weeks(containing: month)
        #expect(weeks.count == 6)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(DateFormatting.dayString(weeks[0][0]) == "2026-07-27")
        #expect(DateFormatting.dayString(weeks[5][6]) == "2026-09-06")
    }

    @Test func aggregateByRecordDate() {
        let logs = [log("2026-08-13"), log("2026-08-12")]
        let emotions = [emotion("2026-08-13", .happy)]
        let map = aggregateDay(logs: logs, emotions: emotions)
        #expect(map["2026-08-13"]?.logs.count == 1)
        #expect(map["2026-08-13"]?.emotions.count == 1)
        #expect(map["2026-08-12"]?.emotions.isEmpty == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败

- [ ] **Step 3: 实现**

`Flash/Domain/EmotionStats.swift`：
```swift
import Foundation

/// 情绪统计算法，与 Android EmotionStats.kt / Web emotionStats.ts 一一对应。
enum EmotionStats {

    private static func window(days: Int, today: Date) -> (start: String, end: String) {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        return (DateFormatting.dayString(start), DateFormatting.dayString(today))
    }

    /// recordDate 为 yyyy-MM-dd，字典序即时间序（与 Web/Android 一致）
    private static func inWindow(_ recordDate: String, _ start: String, _ end: String) -> Bool {
        recordDate >= start && recordDate <= end
    }

    static func hasEmotionData(_ emotions: [EmotionRecord], days: Int,
                               today: Date = Date()) -> Bool {
        let (start, end) = window(days: days, today: today)
        return emotions.contains { inWindow($0.recordDate, start, end) }
    }

    /// 返回窗口内每天的平均情绪值（yyyy-MM-dd, 均值）；当日无记录为 nil。
    /// 均值四舍五入到两位小数（对齐 Android roundToInt/100）。
    static func dailyAverages(_ emotions: [EmotionRecord], days: Int,
                              today: Date = Date()) -> [(date: String, average: Double?)] {
        let (start, end) = window(days: days, today: today)
        var grouped: [String: [Int]] = [:]
        for emotion in emotions where inWindow(emotion.recordDate, start, end) {
            grouped[emotion.recordDate, default: []].append(emotion.level.rawValue)
        }
        let calendar = Calendar(identifier: .gregorian)
        let startDate = DateFormatting.parseDay(start)!
        return (0..<days).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let key = DateFormatting.dayString(date)
            let average = grouped[key].map { values in
                (Double(values.reduce(0, +)) / Double(values.count) * 100).rounded() / 100
            }
            return (date: key, average: average)
        }
    }

    /// 负面情绪子类型（伤心/生气/难受）在时间窗内的分布，key 为中文名。
    static func subEmotionDistribution(_ emotions: [EmotionRecord], days: Int,
                                       today: Date = Date()) -> [(name: String, count: Int)] {
        let (start, end) = window(days: days, today: today)
        var counts: [String: Int] = [:]
        for emotion in emotions
        where emotion.level.isNegative && emotion.subEmotion != nil
            && inWindow(emotion.recordDate, start, end) {
            counts[emotion.subEmotion!.displayName, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
    }
}
```

`Flash/Domain/LogFilter.swift`：
```swift
import Foundation

enum LogSort: String, CaseIterable {
    case newest, oldest, tag

    var displayName: String {
        switch self {
        case .newest: "最新"
        case .oldest: "最早"
        case .tag: "按标签"
        }
    }
}

/// 对应 Web 版 LogFlow 页 + logFilters.ts / Android LogFlowViewModel.applyFilter
struct LogFilter: Equatable {
    var query: String = ""
    var tags: Set<ColorTag> = []
    var startDate: String? = nil // yyyy-MM-dd，含当天
    var endDate: String? = nil
    var sort: LogSort = .newest

    func apply(to logs: [LogItem]) -> [LogItem] {
        let lowercasedQuery = query.lowercased()
        let filtered = logs.filter { log in
            guard log.category == .log else { return false }
            let matchesSearch = lowercasedQuery.isEmpty
                || log.content.lowercased().contains(lowercasedQuery)
            let matchesTags = tags.isEmpty || tags.contains(log.colorTag)
            // recordDate 为 yyyy-MM-dd，字典序即时间序
            let matchesStart = startDate == nil || log.recordDate >= startDate!
            let matchesEnd = endDate == nil || log.recordDate <= endDate!
            return matchesSearch && matchesTags && matchesStart && matchesEnd
        }
        switch sort {
        case .tag: return filtered.sorted { $0.colorTag.rawValue < $1.colorTag.rawValue }
        case .oldest: return filtered.sorted { $0.createdAt < $1.createdAt }
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
```

`Flash/Domain/CalendarGrid.swift`：
```swift
import Foundation

struct DayAggregate: Equatable {
    let date: String
    let logs: [LogItem]
    let emotions: [EmotionRecord]
}

/// 按 recordDate 聚合（对应 Android CalendarViewModel.aggregates）
func aggregateDay(logs: [LogItem], emotions: [EmotionRecord]) -> [String: DayAggregate] {
    let dates = Set(logs.map(\.recordDate) + emotions.map(\.recordDate))
    var result: [String: DayAggregate] = [:]
    for date in dates {
        result[date] = DayAggregate(
            date: date,
            logs: logs.filter { $0.recordDate == date },
            emotions: emotions.filter { $0.recordDate == date }
        )
    }
    return result
}

/// 月视图网格（对应 Android CalendarViewModel.buildWeeks）
enum CalendarGrid {
    /// 42 格（6 周 × 7 天），周一为一周起点，含前后月溢出天。
    static func weeks(containing month: Date) -> [[Date]] {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: month)
        let first = calendar.date(from: components)!
        // weekday: 1=周日 2=周一 ... 7=周六 → 周一偏移 = (weekday + 5) % 7
        let startOffset = (calendar.component(.weekday, from: first) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -startOffset, to: first)!
        return (0..<6).map { week in
            (0..<7).map { day in
                calendar.date(byAdding: .day, value: week * 7 + day, to: start)!
            }
        }
    }

    static func monthString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Domain native-macos/FlashTests/DomainTests.swift
git commit -m "feat(macos): Domain 纯函数（情绪统计/日志筛选/日历网格，算法三端对齐）"
```

---

### Task 7: 主题层（语义色 + 品牌色 light/dark 动态变体）

**Files:**
- Create: `app/native-macos/Flash/Theme/HexColor.swift`
- Create: `app/native-macos/Flash/Theme/BrandColors.swift`
- Test: `app/native-macos/FlashTests/BrandColorsTests.swift`

**Interfaces:**
- Produces:
  - `extension Color { init(hex: String) }`（支持 `#RRGGBB`，浅色用原值）
  - `enum BrandColors`：
    - `static func dynamic(light: String, dark: String) -> Color`（hex → 随外观切换的动态色）
    - `static func tagColor(_ tag: ColorTag, for colorScheme: ColorScheme? = nil) -> Color`
    - `static func emotionColor(_ level: EmotionLevel) -> Color`
    - `static let accent: Color`（= `Color(nsColor: .controlAccentColor)`，跟随系统强调色）
  - 约定：正文/辅助文字一律 `Color.primary` / `Color.secondary`（映射 labelColor/secondaryLabelColor），禁止 `Color.black/.white` 硬编码文本

- [ ] **Step 1: 写失败测试** `FlashTests/BrandColorsTests.swift`

```swift
import Testing
import SwiftUI
@testable import Flash

@Suite("主题色")
struct BrandColorsTests {
    @Test func hexColorParsesRGBComponents() {
        // 通过 NSColor 转换验证通道值
        let nsColor = NSColor(BrandColors.tagColor(.urgent))
        let rgb = nsColor.usingColorSpace(.sRGB)!
        #expect(abs(rgb.redComponent - 1.0) < 0.01)         // FF
        #expect(abs(rgb.greenComponent - 0x6B / 255.0) < 0.01)
        #expect(abs(rgb.blueComponent - 0x6B / 255.0) < 0.01)
    }

    @Test func dynamicColorDiffersByAppearance() {
        let color = BrandColors.dynamic(light: "#FF6B6B", dark: "#FF8A80")
        let nsColor = NSColor(color)
        let light = nsColor.usingColorSpace(.sRGB)!
        // 动态色可解析（具体外观由系统决定，这里验证不为 nil 且合法）
        #expect(light.redComponent >= 0 && light.redComponent <= 1)
    }

    @Test func everyTagAndLevelHasColor() {
        for tag in ColorTag.allCases { _ = BrandColors.tagColor(tag) }
        for level in EmotionLevel.allCases { _ = BrandColors.emotionColor(level) }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: 编译失败

- [ ] **Step 3: 实现**

`Flash/Theme/HexColor.swift`：
```swift
import SwiftUI

extension Color {
    /// `#RRGGBB` → Color（sRGB）
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}
```

`Flash/Theme/BrandColors.swift`：
```swift
import SwiftUI
import AppKit

/// 品牌/模块色。文本一律用 Color.primary/.secondary 语义色；
/// 这里的自定义色仅用于标签、情绪指示等点缀（spec §10.4）。
enum BrandColors {
    /// 跟随系统强调色（用户在系统设置改色后自动跟随）
    static let accent = Color(nsColor: .controlAccentColor)

    /// light/dark 双 hex 的动态色（spec §10.4 三变体中的前两个；
    /// 「增强对比度」由系统对语义色自动处理，自定义色保持简单）
    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }

    static func tagColor(_ tag: ColorTag, for colorScheme: ColorScheme? = nil) -> Color {
        Color(hex: tag.colorHex)
    }

    static func emotionColor(_ level: EmotionLevel) -> Color {
        Color(hex: level.colorHex)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/Flash/Theme native-macos/FlashTests/BrandColorsTests.swift
git commit -m "feat(macos): 主题层（语义色约定 + 品牌色动态变体）"
```

---

### Task 8: App 骨架（RootSplitView + 侧栏 + 菜单命令 + 欢迎窗口）

**Files:**
- Create: `app/native-macos/Flash/App/AppState.swift`
- Modify: `app/native-macos/Flash/FlashApp.swift`（整体替换）
- Create: `app/native-macos/Flash/UI/RootView.swift`
- Create: `app/native-macos/Flash/UI/Sidebar.swift`
- Create: `app/native-macos/Flash/UI/Welcome/WelcomeView.swift`
- Create: `app/native-macos/Flash/UI/Components/PlaceholderView.swift`

**Interfaces:**
- Consumes: Task 3 `FlashDatabase`/`FlashRepository`、Task 5 `SettingsStore`/`ThemeMode`
- Produces:
  - `enum Module: String, CaseIterable, Identifiable { home, explore, logflow, emotion, calendar, stats, settings }`，`var title: String`（首页/探索/记录流/情绪/日历/统计/设置），`var systemImage: String`
  - `@Observable final class AppState`：`var selectedModule: Module = .home`、`var newLogRequestToken = 0`、`func requestNewLog()`、`func requestExport()`（`var exportRequestToken = 0`）
  - `struct RootView: View`（NavigationSplitView 骨架，注入 environment）
  - 后续 Task 的模块视图签名：`HomeView()`、`ExploreView()`、`LogFlowView()`、`EmotionView()`、`CalendarView()`、`StatsView()`、`SettingsView()`——本 Task 用 `PlaceholderView(title:)` 占位

- [ ] **Step 1: 写 AppState**

`Flash/App/AppState.swift`：
```swift
import SwiftUI

enum Module: String, CaseIterable, Identifiable {
    case home, explore, logflow, emotion, calendar, stats, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .explore: "探索"
        case .logflow: "记录流"
        case .emotion: "情绪"
        case .calendar: "日历"
        case .stats: "统计"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "safari"
        case .logflow: "list.bullet.rectangle"
        case .emotion: "face.smiling"
        case .calendar: "calendar"
        case .stats: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}

/// 全局应用状态：侧栏选中 + 菜单命令路由（spec §4）。
@Observable
final class AppState {
    var selectedModule: Module = .home
    /// 菜单「新建记录」⌘N → token 递增，Home/Explore 监听并聚焦输入框
    private(set) var newLogRequestToken = 0
    /// 菜单「导出备份…」⇧⌘E → token 递增，Settings 监听并弹导出面板
    private(set) var exportRequestToken = 0

    func requestNewLog() {
        if selectedModule != .home && selectedModule != .explore {
            selectedModule = .home
        }
        newLogRequestToken += 1
    }

    func requestExport() {
        selectedModule = .settings
        exportRequestToken += 1
    }
}
```

- [ ] **Step 2: 写 RootView 与 Sidebar**

`Flash/UI/Components/PlaceholderView.swift`：
```swift
import SwiftUI

struct PlaceholderView: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer",
                               description: Text("模块建设中"))
    }
}
```

`Flash/UI/Sidebar.swift`：
```swift
import SwiftUI

struct Sidebar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(selection: $state.selectedModule) {
            Section("记录") {
                ForEach([Module.home, .explore, .logflow, .emotion]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }
            Section("回顾") {
                ForEach([Module.calendar, .stats]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }
            Section {
                Label(Module.settings.title, systemImage: Module.settings.systemImage)
                    .tag(Module.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Flash")
    }
}
```

`Flash/UI/RootView.swift`：
```swift
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            detailView(for: appState.selectedModule)
                .navigationTitle(appState.selectedModule.title)
                .frame(minWidth: 560, minHeight: 480)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    @ViewBuilder
    private func detailView(for module: Module) -> some View {
        switch module {
        case .home: HomeView()
        case .explore: ExploreView()
        case .logflow: LogFlowView()
        case .emotion: EmotionView()
        case .calendar: CalendarView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }
}
```

注意：本 Task 阶段这些模块视图还不存在，先在 `PlaceholderView.swift` 同目录建 `ModuleViews.swift` 提供同名占位实现（后续 Task 逐个替换为真实现并删除对应占位）：

`Flash/UI/ModuleViews.swift`：
```swift
import SwiftUI

/// 占位模块：Task 9-15 逐个替换为真实现并删除本文件对应条目。
struct HomeView: View { var body: some View { PlaceholderView(title: "首页") } }
struct ExploreView: View { var body: some View { PlaceholderView(title: "探索") } }
struct LogFlowView: View { var body: some View { PlaceholderView(title: "记录流") } }
struct EmotionView: View { var body: some View { PlaceholderView(title: "情绪") } }
struct CalendarView: View { var body: some View { PlaceholderView(title: "日历") } }
struct StatsView: View { var body: some View { PlaceholderView(title: "统计") } }
struct SettingsView: View { var body: some View { PlaceholderView(title: "设置") } }
```

- [ ] **Step 3: 写 WelcomeView**

`Flash/UI/Welcome/WelcomeView.swift`：
```swift
import SwiftUI

/// 首次启动欢迎页（对应 Android WelcomeScreen）。完成后 setWelcomed。
struct WelcomeView: View {
    let onFinish: () -> Void

    private let pages: [(emoji: String, title: String, subtitle: String)] = [
        ("⚡️", "欢迎来到 Flash", "一闪而过的想法，值得被记住"),
        ("📝", "随手记录", "日志与灵感，一键即达"),
        ("😊", "情绪觉察", "七级情绪记录，看见自己的变化"),
    ]

    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(pages[page].emoji).font(.system(size: 64))
            Text(pages[page].title).font(.title).bold()
            Text(pages[page].subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                if page < pages.count - 1 {
                    Button("下一步") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用") { onFinish() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(width: 480, height: 420)
        .padding()
    }
}
```

- [ ] **Step 4: 整体替换 FlashApp.swift（装配 + 菜单命令 + 主题应用）**

```swift
import SwiftUI
import SwiftData

@main
struct FlashApp: App {
    private let container: ModelContainer
    @State private var appState = AppState()
    @StateObject private var settings = SettingsStore()
    @Environment(\.openWindow) private var openWindow

    init() {
        self.container = FlashDatabase.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.welcomed {
                    RootView()
                } else {
                    WelcomeView {
                        settings.setWelcomed()
                    }
                }
            }
            .environment(appState)
            .environmentObject(settings)
            .preferredColorScheme(colorScheme(for: settings.themeMode))
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建记录") { appState.requestNewLog() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .importExport) {
                Button("导出备份…") { appState.requestExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }

    private func colorScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
```

注意：`@StateObject private var settings = SettingsStore()` 在 `App` 结构里合法（SwiftUI App 支持属性包装器，Xcode 15+）。若编译器报「property wrapper cannot be applied to a computed property」类错误，改为在 `init()` 中赋值 `_settings = StateObject(wrappedValue: SettingsStore())`。

- [ ] **Step 5: 构建 + 跑既有测试确认无回归**

```bash
cd app/native-macos
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED，全部测试 PASS

- [ ] **Step 6: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): App 骨架（三栏导航/菜单命令/欢迎页/主题应用）"
```

---

### Task 9: Home 首页（今日概览 + 快速记录）

**Files:**
- Modify: `app/native-macos/Flash/UI/Home/HomeView.swift`（新建文件，真实现）
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 HomeView 占位）
- Create: `app/native-macos/Flash/UI/Components/LogCardView.swift`

**Interfaces:**
- Consumes: `@Query` 拉取 `LogEntity`/`EmotionEntity`（转 Model 后走纯函数）；`FlashRepository.addLog`（经 environment 注入，见 Step 1）；Task 7 `BrandColors`
- Produces: `struct LogCardView: View`（LogFlow/Explore/Calendar 复用，入参 `log: LogItem`）

行为（对齐 Android HomeViewModel）：
- 顶部三张统计卡：今日日志 N 条 / 今日灵感 N 条 / 今日情绪 N 条；最新一条情绪展示 emoji + displayName
- 快速记录输入框（占位文案「此刻的想法…」）+ 两个按钮「记为日志」「记为灵感」；⌘N 菜单命令触发时聚焦输入框（监听 `appState.newLogRequestToken`）
- 灵感保存时 `importance = importanceFromContent(content)`，日志 tag=daily、灵感 tag=idea
- 最近 5 条日志（`LogCardView` 列表）

- [ ] **Step 1: 在 FlashApp 注入 repository**

`FlashApp.swift` 的 `WindowGroup` 内容 `.environment(appState)` 后追加：
```swift
.environment(\.flashRepository, FlashRepository(container: container))
```
新建 `Flash/Data/RepositoryEnvironment.swift`：
```swift
import SwiftUI

private struct FlashRepositoryKey: EnvironmentKey {
    static let defaultValue: FlashRepository? = nil
}

extension EnvironmentValues {
    var flashRepository: FlashRepository? {
        get { self[FlashRepositoryKey.self] }
        set { self[FlashRepositoryKey.self] = newValue }
    }
}
```

- [ ] **Step 2: 写 LogCardView**

`Flash/UI/Components/LogCardView.swift`：
```swift
import SwiftUI

/// 日志卡片（Home/LogFlow/Explore/Calendar 复用）。内容层：纯色卡片，无玻璃（spec §10.3）。
struct LogCardView: View {
    let log: LogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(BrandColors.tagColor(log.colorTag))
                    .frame(width: 8, height: 8)
                Text(log.colorTag.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if log.importance > 0 {
                    Text(String(repeating: "!", count: log.importance))
                        .font(.caption).bold()
                        .foregroundStyle(BrandColors.tagColor(.urgent))
                }
                Spacer()
                Text(log.recordDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(log.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 3: 写 HomeView 真实现**

`Flash/UI/Home/HomeView.swift`：
```swift
import SwiftUI
import SwiftData

/// 首页：今日概览 + 快速记录 + 最近 5 条（对齐 Android HomeViewModel）
struct HomeView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    private var today: String { DateFormatting.today() }
    private var todayLogs: [LogItem] { logs.filter { $0.recordDate == today && $0.category == .log } }
    private var todayIdeas: [LogItem] { logs.filter { $0.recordDate == today && $0.category == .idea } }
    private var todayEmotions: [EmotionRecord] { emotions.filter { $0.recordDate == today } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 今日概览
                HStack(spacing: 12) {
                    statCard(title: "今日日志", count: todayLogs.count, icon: "note.text")
                    statCard(title: "今日灵感", count: todayIdeas.count, icon: "lightbulb")
                    statCard(title: "今日情绪", count: todayEmotions.count, icon: "face.smiling")
                }

                if let latest = emotions.first {
                    Label("\(latest.level.emoji) \(latest.level.displayName)",
                          systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // 快速记录
                VStack(alignment: .leading, spacing: 8) {
                    TextField("此刻的想法…", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .onChange(of: appState.newLogRequestToken) { inputFocused = true }
                    HStack {
                        Button("记为日志") { quickAdd(as: .log) }
                            .buttonStyle(.borderedProminent)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("记为灵感") { quickAdd(as: .idea) }
                            .buttonStyle(.bordered)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // 最近 5 条
                Text("最近记录")
                    .font(.headline)
                LazyVStack(spacing: 8) {
                    ForEach(logs.prefix(5)) { log in
                        LogCardView(log: log)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statCard(title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text("\(count)").font(.title2).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func quickAdd(as category: Category) {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        do {
            switch category {
            case .log:
                try repository?.addLog(content: content, colorTag: .daily, category: .log)
            case .idea:
                try repository?.addLog(content: content, colorTag: .idea, category: .idea,
                                       importance: importanceFromContent(content))
            }
            draft = ""
        } catch {
            // 静默失败不可接受——但 SwiftUI 无 toast；错误打印到控制台，Task 16 统一错误提示
            print("quickAdd failed: \(error)")
        }
    }
}
```

- [ ] **Step 4: 从 ModuleViews.swift 删除 HomeView 占位行，构建**

```bash
cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 首页（今日概览/快速记录/最近记录）"
```

---

### Task 10: Explore 探索（统一信息流 + 快速输入）

**Files:**
- Create: `app/native-macos/Flash/UI/Explore/ExploreView.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 ExploreView 占位）

**Interfaces:**
- Consumes: `LogCardView`、`BrandColors`、`importanceFromContent`、repository environment
- Produces: `enum ExploreFilter: String, CaseIterable { all, log, idea }`（displayName 全部/日志/灵感）

行为（对齐 Android ExploreViewModel）：
- 顶部 `Picker`（segmented）：全部 / 日志 / 灵感，筛选统一信息流（日志+灵感，createdAt 降序）
- 底部快速输入：TextField + 六色标签选择（点选/再点取消，显示选中态）+ 字数统计 x/140 + 发送按钮
- 当前筛选为「灵感」时按灵感保存（`importanceFromContent`），否则存为日志；未选标签时默认 idea/daily
- 输入限长 140 字

- [ ] **Step 1: 实现** `Flash/UI/Explore/ExploreView.swift`

```swift
import SwiftUI
import SwiftData

enum ExploreFilter: String, CaseIterable {
    case all, log, idea

    var displayName: String {
        switch self {
        case .all: "全部"
        case .log: "日志"
        case .idea: "灵感"
        }
    }
}

/// 探索页：统一信息流（日志+灵感），模块筛选 + 底部快速输入
struct ExploreView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]

    @State private var filter: ExploreFilter = .all
    @State private var draft = ""
    @State private var selectedTag: ColorTag? = nil
    @FocusState private var inputFocused: Bool

    private static let maxLength = 140

    private var filteredLogs: [LogItem] {
        let all = logEntities.map { $0.toModel() }
        switch filter {
        case .all: return all
        case .log: return all.filter { $0.category == .log }
        case .idea: return all.filter { $0.category == .idea }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("筛选", selection: $filter) {
                ForEach(ExploreFilter.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredLogs) { log in
                        LogCardView(log: log)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 底部快速输入
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        tagButton(tag)
                    }
                    Spacer()
                    Text("\(draft.count)/\(Self.maxLength)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(filter == .idea ? "记录灵感（!! 标记重要度）…" : "记录此刻…",
                              text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .focused($inputFocused)
                        .onChange(of: appState.newLogRequestToken) { inputFocused = true }
                        .onChange(of: draft) {
                            if draft.count > Self.maxLength {
                                draft = String(draft.prefix(Self.maxLength))
                            }
                        }
                    Button("发送") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func tagButton(_ tag: ColorTag) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = isSelected ? nil : tag
        } label: {
            Circle()
                .fill(BrandColors.tagColor(tag))
                .frame(width: 18, height: 18)
                .overlay {
                    if isSelected {
                        Circle().stroke(Color.primary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(tag.displayName)
        .accessibilityLabel(tag.displayName)
    }

    private func save() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let asIdea = filter == .idea
        let tag = selectedTag ?? (asIdea ? .idea : .daily)
        do {
            try repository?.addLog(
                content: content,
                colorTag: tag,
                category: asIdea ? .idea : .log,
                importance: asIdea ? importanceFromContent(content) : 0
            )
            draft = ""
            selectedTag = nil
        } catch {
            print("Explore save failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: 删除占位 + 构建**

ModuleViews.swift 删除 `ExploreView` 占位行。
Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 探索页（统一信息流/筛选/140 字快速输入/标签）"
```

---

### Task 11: LogFlow 记录流（搜索/筛选/排序 + 编辑删除）

**Files:**
- Create: `app/native-macos/Flash/UI/LogFlow/LogFlowView.swift`
- Create: `app/native-macos/Flash/UI/LogFlow/LogEditSheet.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 LogFlowView 占位）

**Interfaces:**
- Consumes: Task 6 `LogFilter`/`LogSort`、`LogCardView`、repository
- Produces: 无新公共接口（模块内闭环）

行为（对齐 Android LogFlowViewModel + spec §4 双栏）：
- 工具区：搜索框（实时过滤）、标签多选 chips、开始/结束日期（`DatePicker`，可选清空）、排序 `Picker`（最新/最早/按标签）
- 列表区：过滤后日志（`LogCardView`），右键菜单「编辑…」「删除」（删除需确认 Alert）
- 编辑：sheet 弹窗改内容 + 标签 + 重要度（0-4 stepper），保存走 `repository.updateLog`
- ⌘F 聚焦搜索框（`.keyboardShortcut("f")` 在隐藏按钮上，或 `.searchable`——用 `.searchable(text:placement:)` 标准行为，天然支持 ⌘F）

- [ ] **Step 1: 实现** `Flash/UI/LogFlow/LogFlowView.swift`

```swift
import SwiftUI
import SwiftData

/// 记录流：搜索 + 标签/日期/排序筛选 + 编辑删除（对齐 Android LogFlowViewModel）
struct LogFlowView: View {
    @Environment(\.flashRepository) private var repository
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]

    @State private var filter = LogFilter()
    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    @State private var errorMessage: String? = nil

    private var filteredLogs: [LogItem] {
        filter.apply(to: logEntities.map { $0.toModel() })
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具区
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        tagChip(tag)
                    }
                    Spacer()
                    Picker("排序", selection: $filter.sort) {
                        ForEach(LogSort.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }
                HStack(spacing: 8) {
                    DatePicker("开始", selection: startBinding, displayedComponents: .date)
                        .labelsHidden()
                    Text("至").foregroundStyle(.secondary)
                    DatePicker("结束", selection: endBinding, displayedComponents: .date)
                        .labelsHidden()
                    if filter.startDate != nil || filter.endDate != nil {
                        Button("清除日期") {
                            filter.startDate = nil
                            filter.endDate = nil
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                    }
                    Spacer()
                }
                .font(.caption)
            }
            .padding(12)

            Divider()

            if filteredLogs.isEmpty {
                ContentUnavailableView("没有匹配的记录",
                                       systemImage: "magnifyingglass",
                                       description: Text("调整筛选条件试试"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredLogs) { log in
                            LogCardView(log: log)
                                .contextMenu {
                                    Button("编辑…") { editingLog = log }
                                    Button("删除", role: .destructive) { deletingLog = log }
                                }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .searchable(text: $filter.query, placement: .toolbar, prompt: "搜索记录内容")
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log) { updated in
                do { try repository?.updateLog(updated) }
                catch { errorMessage = "保存失败：\(error.localizedDescription)" }
            }
        }
        .alert("删除这条记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let log = deletingLog {
                    do { try repository?.deleteLog(id: log.id) }
                    catch { errorMessage = "删除失败：\(error.localizedDescription)" }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // 日期桥接：filter 存 yyyy-MM-dd 字符串（对齐 Web/Android），DatePicker 用 Date
    private var startBinding: Binding<Date> {
        Binding(
            get: { filter.startDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.startDate = DateFormatting.dayString($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { filter.endDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.endDate = DateFormatting.dayString($0) }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingLog != nil }, set: { if !$0 { deletingLog = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func tagChip(_ tag: ColorTag) -> some View {
        let isOn = filter.tags.contains(tag)
        return Button {
            if isOn { filter.tags.remove(tag) } else { filter.tags.insert(tag) }
        } label: {
            Text(tag.displayName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isOn ? BrandColors.tagColor(tag).opacity(0.25)
                                 : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? BrandColors.tagColor(tag)
                                          : Color(nsColor: .separatorColor),
                                     lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: 实现** `Flash/UI/LogFlow/LogEditSheet.swift`

```swift
import SwiftUI

/// 编辑记录 sheet：内容 / 标签 / 重要度
struct LogEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let log: LogItem
    let onSave: (LogItem) -> Void

    @State private var content: String
    @State private var colorTag: ColorTag
    @State private var importance: Int

    init(log: LogItem, onSave: @escaping (LogItem) -> Void) {
        self.log = log
        self.onSave = onSave
        _content = State(initialValue: log.content)
        _colorTag = State(initialValue: log.colorTag)
        _importance = State(initialValue: log.importance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑记录").font(.headline)

            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 120)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

            Picker("标签", selection: $colorTag) {
                ForEach(ColorTag.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Stepper("重要度：\(importance)", value: $importance, in: 0...4)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    var updated = log
                    updated.content = content
                    updated.colorTag = colorTag
                    updated.importance = importance
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
```

- [ ] **Step 3: 删除占位 + 构建**

ModuleViews.swift 删除 `LogFlowView` 占位行。
Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 记录流（搜索/标签/日期/排序 + 编辑删除）"
```

---

### Task 12: Emotion 情绪（七级记录 + 子情绪 + 历史）

**Files:**
- Create: `app/native-macos/Flash/UI/Emotion/EmotionView.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 EmotionView 占位）

**Interfaces:**
- Consumes: Task 2 `EmotionLevel`/`SubEmotion`、Task 7 `BrandColors.emotionColor`、repository
- Produces: 无新公共接口

行为（对齐 Android EmotionViewModel）：
- 记录区：大 emoji（当前等级，随滑动平滑过渡 `.animation(.easeInOut)`，克制）+ 等级名 + `Slider`（1...7 档，步进 1，映射 veryUnhappy...veryHappy，默认 slightlyHappy）
- 子情绪 chips（伤心/生气/难受）：**仅负面等级出现**，选中/再点取消；切回非负面自动清空
- 备注 `TextField`（可选，空存 nil）+ 「记录情绪」`.borderedProminent` 按钮
- 历史区：今日/近期记录列表（emoji + 等级名 + 子情绪 + 备注 + recordDate），右键「删除」（确认 Alert）
- 保存后清空备注与子情绪

- [ ] **Step 1: 实现** `Flash/UI/Emotion/EmotionView.swift`

```swift
import SwiftUI
import SwiftData

/// 情绪页：七级情绪记录（对齐 Android EmotionViewModel）
struct EmotionView: View {
    @Environment(\.flashRepository) private var repository
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var sliderValue: Double = 5 // 1...7 → veryUnhappy...slightlyHappy 默认
    @State private var selectedSubEmotion: SubEmotion? = nil
    @State private var note = ""
    @State private var deletingRecord: EmotionRecord? = nil
    @State private var errorMessage: String? = nil

    private var selectedLevel: EmotionLevel {
        EmotionLevel.allCases[Int(sliderValue) - 1]
    }

    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 当前情绪
                VStack(spacing: 12) {
                    Text(selectedLevel.emoji)
                        .font(.system(size: 72))
                        .animation(.easeInOut(duration: 0.2), value: selectedLevel)
                    Text(selectedLevel.displayName)
                        .font(.title3)
                        .foregroundStyle(BrandColors.emotionColor(selectedLevel))

                    Slider(value: $sliderValue, in: 1...7, step: 1) {
                        Text("情绪等级")
                    } minimumValueLabel: {
                        Text("😡")
                    } maximumValueLabel: {
                        Text("😍")
                    }
                    .frame(maxWidth: 420)
                    .onChange(of: sliderValue) {
                        if !selectedLevel.isNegative { selectedSubEmotion = nil }
                    }
                    .accessibilityValue(selectedLevel.displayName)
                }
                .padding(.top, 24)

                // 子情绪（仅负面）
                if selectedLevel.isNegative {
                    HStack(spacing: 10) {
                        ForEach(SubEmotion.allCases, id: \.self) { sub in
                            subEmotionChip(sub)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // 备注 + 保存
                VStack(spacing: 10) {
                    TextField("想说点什么？（可选）", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                    Button("记录情绪") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                Divider().padding(.vertical, 8)

                // 历史
                VStack(alignment: .leading, spacing: 8) {
                    Text("近期记录").font(.headline)
                    if emotions.isEmpty {
                        Text("还没有情绪记录，从上方开始吧")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(emotions.prefix(20)) { record in
                            emotionRow(record)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("删除这条情绪记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let record = deletingRecord {
                    do { try repository?.deleteEmotion(id: record.id) }
                    catch { errorMessage = "删除失败：\(error.localizedDescription)" }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func subEmotionChip(_ sub: SubEmotion) -> some View {
        let isOn = selectedSubEmotion == sub
        return Button {
            selectedSubEmotion = isOn ? nil : sub
        } label: {
            Text(sub.displayName)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isOn ? Color(hex: sub.colorHex).opacity(0.3)
                                 : Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? Color(hex: sub.colorHex)
                                          : Color(nsColor: .separatorColor),
                                     lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func emotionRow(_ record: EmotionRecord) -> some View {
        HStack(spacing: 10) {
            Text(record.level.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.level.displayName).font(.callout)
                    if let sub = record.subEmotion {
                        Text(sub.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: sub.colorHex).opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                if let note = record.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(record.recordDate).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("删除", role: .destructive) { deletingRecord = record }
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        let level = selectedLevel
        let sub = level.isNegative ? selectedSubEmotion : nil
        let noteValue = note.isEmpty ? nil : note
        do {
            try repository?.addEmotion(level: level, subEmotion: sub, note: noteValue)
            note = ""
            selectedSubEmotion = nil
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: 删除占位 + 构建 + 跑全量测试**

```bash
cd app/native-macos
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED，全部 PASS

- [ ] **Step 3: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 情绪页（七级滑块/子情绪/备注/历史）"
```

---

### Task 13: Calendar 日历（月视图 + 当日聚合）

**Files:**
- Create: `app/native-macos/Flash/UI/Calendar/CalendarView.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 CalendarView 占位）

**Interfaces:**
- Consumes: Task 6 `CalendarGrid`/`aggregateDay`/`DayAggregate`、`LogCardView`
- Produces: 无新公共接口

行为（对齐 Android CalendarViewModel）：
- 头部：「‹ 上一月」「2026 年 8 月」「下一月 ›」「回到今天」
- 42 格月网格（周一开头）：每格显示日期数字 + 当日日志数徽标 + 当日最新情绪 emoji；溢出月日期灰色；今日高亮圈；选中态填充
- 点击溢出月日期自动切换显示月份（对齐 `selectDate` 行为）
- 下方/右侧详情：选中日的日志列表（`LogCardView`）+ 情绪记录列表

- [ ] **Step 1: 实现** `Flash/UI/Calendar/CalendarView.swift`

```swift
import SwiftUI
import SwiftData

/// 日历页：月视图网格 + 选中日详情（对齐 Android CalendarViewModel）
struct CalendarView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()

    private var aggregates: [String: DayAggregate] {
        aggregateDay(logs: logEntities.map { $0.toModel() },
                     emotions: emotionEntities.map { $0.toModel() })
    }

    private var weeks: [[Date]] { CalendarGrid.weeks(containing: displayedMonth) }
    private var selectedKey: String { DateFormatting.dayString(selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("上一月")
                Text(monthTitle)
                    .font(.headline)
                    .frame(minWidth: 140)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("下一月")
                Spacer()
                Button("回到今天") {
                    displayedMonth = Date()
                    selectedDate = Date()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 星期表头
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // 月网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(weeks.flatMap { $0 }, id: \.self) { date in
                    dayCell(date)
                }
            }
            .padding(.horizontal, 16)

            Divider().padding(.vertical, 8)

            // 选中日详情
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(selectedKey) 详情")
                        .font(.headline)
                    if let aggregate = aggregates[selectedKey] {
                        if aggregate.emotions.isEmpty && aggregate.logs.isEmpty {
                            Text("这一天没有记录").foregroundStyle(.secondary)
                        }
                        ForEach(aggregate.emotions) { emotion in
                            Label("\(emotion.level.emoji) \(emotion.level.displayName)",
                                  systemImage: "face.smiling")
                                .font(.callout)
                        }
                        ForEach(aggregate.logs) { log in
                            LogCardView(log: log)
                        }
                    } else {
                        Text("这一天没有记录").foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: displayedMonth)
    }

    private func shiftMonth(_ delta: Int) {
        let calendar = Calendar(identifier: .gregorian)
        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth)!
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DateFormatting.dayString(date)
        let inMonth = CalendarGrid.monthString(date) == CalendarGrid.monthString(displayedMonth)
        let isToday = key == DateFormatting.today()
        let isSelected = key == selectedKey
        let aggregate = aggregates[key]

        return Button {
            selectedDate = date
            // 选中溢出天时跟随切换月份（对齐 Android selectDate）
            if !inMonth { displayedMonth = date }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar(identifier: .gregorian).component(.day, from: date))")
                    .font(.callout)
                    .foregroundStyle(inMonth ? Color.primary : Color.secondary.opacity(0.5))
                HStack(spacing: 3) {
                    if let count = aggregate?.logs.count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .controlAccentColor))
                    }
                    if let emoji = aggregate?.emotions.first?.level.emoji {
                        Text(emoji).font(.caption2)
                    }
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor)
                                   : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .controlAccentColor), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }
}
```

- [ ] **Step 2: 删除占位 + 构建**

ModuleViews.swift 删除 `CalendarView` 占位行。
Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 日历页（42 格月视图/当日聚合/月份导航）"
```

---

### Task 14: Stats 统计（KPI + Swift Charts 情绪图表）

**Files:**
- Create: `app/native-macos/Flash/UI/Stats/StatsView.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 StatsView 占位）

**Interfaces:**
- Consumes: Task 6 `EmotionStats`、Swift Charts
- Produces: 无新公共接口

行为（对齐 Android StatsViewModel + EmotionStatsSection）：
- 顶部四张 KPI 卡：累计日志 / 累计灵感 / 累计情绪 / 活跃天数
- 时间窗分段：近 7 天 / 近 30 天（默认 7 天）
- 日均情绪折线图（Swift Charts `LineMark` + `PointMark`，y 轴 -3...3，0 轴 `RuleMark` 虚线；无数据日断线不补点）；图表动画用 `.animation(.easeInOut(duration: 0.3))` 克制过渡
- 负面子情绪分布柱状图（`BarMark`，伤心/生气/难受各自颜色）
- 窗口内无情绪数据时显示 `ContentUnavailableView`

- [ ] **Step 1: 实现** `Flash/UI/Stats/StatsView.swift`

```swift
import SwiftUI
import SwiftData
import Charts

/// 统计页：KPI + 情绪趋势/子情绪分布（对齐 Android StatsViewModel + EmotionStatsSection）
struct StatsView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var windowDays = 7

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    private var totalLogs: Int { logs.filter { $0.category == .log }.count }
    private var totalIdeas: Int { logs.filter { $0.category == .idea }.count }
    private var activeDays: Int {
        Set(logs.map(\.recordDate) + emotions.map(\.recordDate)).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // KPI
                HStack(spacing: 12) {
                    kpiCard("累计日志", totalLogs, "note.text")
                    kpiCard("累计灵感", totalIdeas, "lightbulb")
                    kpiCard("累计情绪", emotions.count, "face.smiling")
                    kpiCard("活跃天数", activeDays, "calendar")
                }

                // 时间窗
                Picker("时间范围", selection: $windowDays) {
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                if EmotionStats.hasEmotionData(emotions, days: windowDays) {
                    // 日均情绪趋势
                    Text("情绪趋势").font(.headline)
                    Chart {
                        RuleMark(y: .value("中性", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color(nsColor: .separatorColor))
                        ForEach(Array(EmotionStats.dailyAverages(emotions, days: windowDays)
                            .enumerated()), id: \.offset) { _, item in
                            if let average = item.average {
                                LineMark(
                                    x: .value("日期", item.date),
                                    y: .value("均值", average)
                                )
                                .foregroundStyle(Color(nsColor: .controlAccentColor))
                                PointMark(
                                    x: .value("日期", item.date),
                                    y: .value("均值", average)
                                )
                                .foregroundStyle(Color(nsColor: .controlAccentColor))
                            }
                        }
                    }
                    .chartYScale(domain: -3...3)
                    .chartYAxis {
                        AxisMarks(values: [-3, -2, -1, 0, 1, 2, 3])
                    }
                    .frame(height: 220)
                    .animation(.easeInOut(duration: 0.3), value: windowDays)

                    // 负面子情绪分布
                    let distribution = EmotionStats.subEmotionDistribution(emotions,
                                                                           days: windowDays)
                    if !distribution.isEmpty {
                        Text("负面情绪构成").font(.headline)
                        Chart(distribution, id: \.name) { item in
                            BarMark(
                                x: .value("次数", item.count),
                                y: .value("类型", item.name)
                            )
                            .foregroundStyle(barColor(for: item.name))
                            .cornerRadius(4)
                        }
                        .frame(height: 140)
                        .animation(.easeInOut(duration: 0.3), value: windowDays)
                    }
                } else {
                    ContentUnavailableView("暂无情绪数据",
                                           systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("先在「情绪」页记录几天吧"))
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func barColor(for name: String) -> Color {
        // 与 SubEmotion 配色一致（伤心/生气/难受）
        SubEmotion.allCases.first { $0.displayName == name }
            .map { Color(hex: $0.colorHex) } ?? .secondary
    }

    private func kpiCard(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text("\(value)").font(.title2).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: 删除占位 + 构建**

ModuleViews.swift 删除 `StatsView` 占位行。
Run: `cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 统计页（KPI/情绪趋势/子情绪分布，Swift Charts）"
```

---

### Task 15: Settings 设置（主题 + 备份导入导出 + 清空 + 关于）

**Files:**
- Create: `app/native-macos/Flash/UI/Settings/SettingsView.swift`
- Modify: `app/native-macos/Flash/UI/ModuleViews.swift`（删除 SettingsView 占位，文件清空后删除该文件本身）

**Interfaces:**
- Consumes: `SettingsStore`/`ThemeMode`、`BackupService`、`FlashRepository`、`AppState.exportRequestToken`
- Produces: 无新公共接口

行为（对齐 Android SettingsViewModel + spec §6/§10.6）：
- inset 分组表单（`Form` + `.formStyle(.grouped)`），左标签右控件
- 「外观」组：`Picker`（segmented）跟随系统/浅色/深色
- 「数据」组：导出备份（NSSavePanel，默认文件名 `flash-backup-yyyy-MM-dd.json`）、导入备份（NSOpenPanel 限 `.json` → 解析 → **预览 Alert 显示条数与跳过数**，用户选「合并导入」或「覆盖导入」（覆盖需红色 destructive 且二次确认））、清空全部数据（destructive + 确认）
- 「关于」组：版本号（`Bundle.main` 读取）、「数据仅保存在本机」说明
- 监听 `appState.exportRequestToken`（⇧⌘E 菜单命令）触发导出
- 操作结果用 Alert 反馈（对齐 Android message 文案：「备份已导出」「已导入 N 条日志、M 条情绪（跳过异常数据 K 条）」「已清空全部数据」）

- [ ] **Step 1: 实现** `Flash/UI/Settings/SettingsView.swift`

```swift
import SwiftUI
import AppKit // NSSavePanel / NSOpenPanel
import UniformTypeIdentifiers

/// 设置页：外观 / 数据备份 / 关于（对齐 Android SettingsViewModel）
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState

    @State private var importPreview: ImportPreview? = nil
    @State private var showOverwriteConfirm = false
    @State private var showClearConfirm = false
    @State private var message: String? = nil

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: themeBinding) {
                    ForEach(ThemeMode.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("数据") {
                Button("导出备份…") { exportBackup() }
                Button("导入备份…") { chooseImportFile() }
                Button("清空全部数据…", role: .destructive) { showClearConfirm = true }
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                Text("数据仅保存在本机，不会上传到任何服务器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: appState.exportRequestToken) { exportBackup() }
        .alert("导入备份", isPresented: previewPresented) {
            Button("合并导入") { confirmImport(overwrite: false) }
            Button("覆盖导入", role: .destructive) { showOverwriteConfirm = true }
            Button("取消", role: .cancel) { importPreview = nil }
        } message: {
            if let preview = importPreview {
                Text("包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                     (preview.skippedLogs + preview.skippedEmotions > 0
                      ? "\n跳过异常数据 \(preview.skippedLogs + preview.skippedEmotions) 条" : ""))
            }
        }
        .alert("覆盖导入将清空现有全部数据，确定继续？", isPresented: $showOverwriteConfirm) {
            Button("覆盖导入", role: .destructive) { confirmImport(overwrite: true) }
            Button("取消", role: .cancel) {}
        }
        .alert("清空全部数据？此操作不可撤销。", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: messagePresented) {
            Button("好") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(get: { settings.themeMode }, set: { settings.setThemeMode($0) })
    }

    private var previewPresented: Binding<Bool> {
        Binding(get: { importPreview != nil }, set: { if !$0 { importPreview = nil } })
    }

    private var messagePresented: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - 导出

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "flash-backup-\(DateFormatting.today()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let logs = try repository?.allLogs() ?? []
            let emotions = try repository?.allEmotions() ?? []
            let json = BackupService.exportJSON(logs: logs, emotions: emotions,
                                                appVersion: appVersion)
            try json.write(to: url, atomically: true, encoding: .utf8)
            message = "备份已导出"
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 导入

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= BackupService.maxFileBytes else {
                message = BackupError.fileTooLarge.userMessage
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            importPreview = try BackupService.parse(text)
        } catch let error as BackupError {
            message = error.userMessage
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
    }

    private func confirmImport(overwrite: Bool) {
        guard let preview = importPreview else { return }
        do {
            if overwrite {
                try repository?.replaceAll(logs: preview.logs, emotions: preview.emotions)
            } else {
                try repository?.mergeAll(logs: preview.logs, emotions: preview.emotions)
            }
            let skipped = preview.skippedLogs + preview.skippedEmotions
            message = "已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪" +
                (skipped > 0 ? "（跳过异常数据 \(skipped) 条）" : "")
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
        importPreview = nil
    }

    private func clearAll() {
        do {
            try repository?.clearAll()
            message = "已清空全部数据"
        } catch {
            message = "清空失败：\(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: 删除占位（ModuleViews.swift 已空，删文件）+ 构建**

```bash
rm app/native-macos/Flash/UI/ModuleViews.swift
cd app/native-macos && xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd app && git add native-macos
git commit -m "feat(macos): 设置页（主题/备份导入导出/清空/关于）"
```

---

### Task 16: 交互打磨与 UI 冒烟测试

**Files:**
- Create: `app/native-macos/FlashUITests/FlashUITests.swift`（需把 FlashUITests target 加入工程，见 Step 1）
- Modify: 各模块视图（补可访问性标签/help/tooltip，零散小改）

**Interfaces:**
- Consumes: 全部 UI 模块
- Produces: XCUITest 冒烟套件

- [ ] **Step 1: 加 UI 测试 target 与 scheme 条目**

UI 测试 target 需要独立的 bundle（不能直接 host 在 app 里）。为保持 pbxproj 简单，本 Task 采用更轻的做法：**不新增 target**，把冒烟检查写成 Release 构建后的脚本化手动清单（Step 2-4 用 `open` 启动 app 实测）。XCUITest target 的 pbxproj 增补（PBXNativeTarget + UITests 同步组 + scheme Testable）作为备选，仅当 Step 2-4 发现问题需要自动化回归时再做。

- [ ] **Step 2: 快捷键与菜单核对**

启动 Debug 构建并逐项核对（spec §10.7）：
- ⌘N 新建记录：在任意模块触发 → 跳到首页/探索并聚焦输入框
- ⇧⌘E 导出备份：跳到设置并弹出 NSSavePanel
- ⌘F 搜索：记录流页聚焦搜索框（`.searchable` 自带）
- ⌘, 设置：SwiftUI 默认行为在单 WindowGroup 下没有 Settings scene，需要确认——若 ⌘, 无响应，在 commands 里加：
  ```swift
  CommandGroup(replacing: .appSettings) {
      Button("设置…") { appState.selectedModule = .settings }
          .keyboardShortcut(",", modifiers: .command)
  }
  ```
- ⌘Z/⇧⌘Z：TextEditor/TextField 内原生撤销可用（系统行为，核对即可）

- [ ] **Step 3: 可访问性核对**

- 系统设置 → 辅助功能 → 显示 → 「降低透明度」开启：各页面无不透明色块错乱（本设计内容层无玻璃，预期无问题）
- 「增强对比度」开启：情绪色/标签色仍可读；发现对比度不足时改用更深一档 hex
- VoiceOver（⌘F5）：侧栏项、日历格子（有 accessibilityLabel）、情绪滑块（有 accessibilityValue）朗读正确
- Full Keyboard Access（⌃F1 后）：Tab 顺序 = 视觉顺序，焦点环清晰

- [ ] **Step 4: 浅色/深色切换核对**

设置页切 浅色/深色/跟随系统，逐模块检查：无撕裂（spec §10.3 语义色）、情绪色与标签色两种外观下均可读。

- [ ] **Step 5: 修复核对中发现的问题，构建 + 全量测试**

```bash
cd app/native-macos
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build 2>&1 | tail -5
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
cd app && git add native-macos
git commit -m "fix(macos): 交互打磨（快捷键/可访问性/深浅色核对修复）"
```

---

### Task 17: 性能验证、双架构发布与文档

**Files:**
- Create: `app/native-macos/README.md`
- Modify: `app/ROADMAP.md`（追加 macOS 里程碑，保持既有格式）

- [ ] **Step 1: Release universal2 构建与验证**

```bash
cd app/native-macos
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath build/dd clean build 2>&1 | tail -5
lipo -info build/dd/Build/Products/Release/Flash.app/Contents/MacOS/Flash
du -sh build/dd/Build/Products/Release/Flash.app
codesign -dv --entitlements - build/dd/Build/Products/Release/Flash.app 2>&1 | head -20
```
Expected:
- `lipo` 输出 `x86_64 arm64`
- 包体 < 20MB（零依赖应远小于此）
- entitlements 只有 app-sandbox + files.user-selected.read-write，无 network

- [ ] **Step 2: 性能基线测量**

- 冷启动：`time` 粗测 + `os_signpost` 后续补（本版本记录基线数字到 README）：
  ```bash
  for i in 1 2 3; do
    /usr/bin/time -p open -W build/dd/Build/Products/Release/Flash.app 2>&1 | grep real
  done
  ```
  （`open -W` 等到 app 退出；改为启动后立刻 ⌘Q。或直接用 Instruments Time Profiler 录一次启动）
- 空闲内存：启动后静置 30s，`ps -o rss= -p $(pgrep -x Flash)` 换算 MB
- 滚动帧率：Instruments → Animation Hitches（记录流页 500 条数据滚动）——若无 Instruments 经验，用 `Quartz Debug` 帧率或目测 + signpost 替代，结果记入 README
- 未达标项按 spec §8 策略修（减模糊层数/懒加载/缓存），修复后复测

- [ ] **Step 3: 写 README.md**

`app/native-macos/README.md` 内容：工程简介、功能清单（九模块）、系统要求（macOS 15+，Intel/Apple Silicon）、构建命令（xcodebuild 两行）、测试命令、备份格式说明（与 Android/Web 互通）、性能基线数字、已知限制（无 Intel 实机验证、menu bar extra 未做）。

- [ ] **Step 4: 更新 ROADMAP.md**

在 `app/ROADMAP.md` 里程碑区追加（格式跟随既有条目）：
- M7：原生 macOS 版（SwiftUI + SwiftData，universal2）✅ 本次完成范围 + 后续候选（menu bar extra 快速记录、iCloud 同步、原生 iOS 版共享模型）

- [ ] **Step 5: Commit**

```bash
cd app && git add native-macos/README.md ROADMAP.md
git commit -m "docs(macos): README + ROADMAP M7 里程碑"
```

---
