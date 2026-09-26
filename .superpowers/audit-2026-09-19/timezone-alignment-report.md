# 时区口径对齐报告

> 终审要求：将原生时区校验收紧到参考校验器白名单，拒绝 ICU 别名（`utc`、`Zulu`、`GMT0`、`US/Eastern`、`EST` 等）。

## 修复内容

### 1. 契约校验器白名单化

- 新增 `scripts/backup-contract/canonical-timezones.json`
  - 由 `Intl.supportedValuesOf('timeZone')` 生成，并显式补入 `UTC`、`Etc/UTC`。
  - 共 420 条标准 IANA 时区 ID，作为三端统一的唯一合法清单。
- `scripts/backup-contract/validate.cjs`
  - 由运行时 `Intl.supportedValuesOf('timeZone')` 改为读取上述 JSON 做精确集合匹配。
- `scripts/backup-contract/generate-cases.cjs`
  - 增加别名负例：`utc`、`Zulu`、`GMT0`、`US/Eastern`、`EST`。
  - 正例增加 `UTC`（上海/纽约/柏林/东京/悉尼/UTC）。
- `scripts/backup-contract/contract.test.cjs`
  - 时区测试改用 `canonical-timezones.json` 作为期望集合。
- 重新生成共享语料：`docs/contracts/fixtures/invalid-alias-*.json`、`valid-time-zones.json`、`cases.json`。

### 2. 三端原生解析器对齐

为彻底拒绝 ICU 别名，各端在原有 native API 基础上增加了由 `canonical-timezones.json` 生成的白名单常量：

| 端 | 新增/修改文件 | 口径 |
|---|---|---|
| Android | `android/app/src/main/java/com/flash/app/data/CanonicalTimeZones.kt`（新增）<br>`android/app/src/main/java/com/flash/app/data/Backup.kt` | `ZoneId.of(id)` 可解析、输入等于 `zone.id`、且 `id ∈ CanonicalTimeZones.ALL`。 |
| macOS | `macos/Flash/Data/CanonicalTimeZones.swift`（新增）<br>`macos/Flash/Data/BackupService.swift` | `TimeZone(identifier:)` 可解析、且 `zone ∈ CanonicalTimeZones.all`。返回白名单 ID 本身存储，避免 Foundation 把 `UTC` 显示为 `GMT`。 |
| HarmonyOS | `harmonyos/entry/src/main/ets/data/CanonicalTimeZones.ets`（新增）<br>`harmonyos/entry/src/main/ets/data/BackupService.ets` | `CANONICAL_TIME_ZONES.includes(value)` 且 `Intl.DateTimeFormat` 可解析；返回白名单 ID 本身存储，避免 Node/HarmonyOS `resolvedOptions().timeZone` 把 `Etc/UTC` 等折叠为 `UTC`。 |

> 说明：原方案「仅依赖 native API 规范化后比较输入 == 规范化结果」在 Android/macOS 上无法覆盖所有别名（例如 `ZoneId.of("US/Eastern")` 返回 `US/Eastern`、`TimeZone(identifier: "US/Eastern")` 也返回 `US/Eastern`），因此引入白名单作为终审所需的「参考校验器白名单」口径。

### 3. 顺手修复：macOS LAN OK 头行缓冲

- `macos/Flash/Data/LocalBackupTransfer.swift`：`maxOKHeaderBytes` 由 76 改为 128，与 Android/HarmonyOS 一致。
- `macos/FlashTests/LocalBackupTransferTests.swift`：同步更新 oversized header 测试用例长度与注释（>128 字节）。

## 测试结论

以下命令均已在本机跑通：

```bash
cd /Users/haydenjiang/Documents/DEV/flash-Alpha/app && npm test --prefix scripts/backup-contract
```

- 63/63 通过。

```bash
cd /Users/haydenjiang/Documents/DEV/flash-Alpha/app/android && ./gradlew test
```

- BUILD SUCCESSFUL；70 个单元测试通过。

```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project /Users/haydenjiang/Documents/DEV/flash-Alpha/app/macos/Flash.xcodeproj -scheme Flash -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

- **TEST SUCCEEDED**；全部用例通过（含 `BackupContractTests/sharedStrictCorpus` 与修复后的 `oversizedOKHeaderWithoutNewlineIsRejected`）。

```bash
cd /Users/haydenjiang/Documents/DEV/flash-Alpha/app/harmonyos && node --test
```

- 98/98 通过。

## 跨端口径说明

- **参考源**：`scripts/backup-contract/canonical-timezones.json`。
- **合法值**：该 JSON 中列出的标准 IANA 时区 ID（含 `UTC`、`Etc/UTC`）。
- **拒绝项**：
  - ICU 别名：`utc`、`Zulu`、`GMT0`、`GMT`、`US/Eastern`、`EST` 等。
  - 偏移写法：`+08:00`、`GMT+08:00` 等。
  - 未知或无法解析的字符串。
- **存储值**：导入/导出时均存储白名单中的标准 ID，保证同一备份在三端及契约校验器下的判定完全一致，避免跨端数据丢失。

## Commit 列表

```
4e4a12a feat(backup-contract): canonical timezone whitelist and alias negative cases
e8b8630 fix(android): canonicalize task timeZone and reject IANA aliases
42f8ce4 fix(macos): canonicalize task timeZone, reject aliases; align OK header buffer to 128
5231c71 fix(harmonyos): canonicalize task timeZone via Intl resolvedOptions and reject aliases
1378c4d fix(all-native): use generated canonical timezone whitelist in Android/macOS/HarmonyOS parsers
1c75aba fix(macos): raise LAN OK header buffer to 128 and update test fixture
```
