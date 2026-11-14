# 加密备份信封 `flash-backup-enc-v1`

> 状态：**已批准并实现**（2026-11-08，按 §8 建议默认值）｜范围：Android / iOS / macOS（FlashKit）/ HarmonyOS<br>
> 来源：2026-11-08 安全审查延后项「备份加密」。不改 `flash-backup-v2` 本身，只在其外面包一层可选的口令加密信封。<br>
> 结构 Schema：[flash-backup-enc-v1.schema.json](flash-backup-enc-v1.schema.json)｜参考实现：[envelope.cjs](../../scripts/backup-contract/envelope.cjs)｜共用样例：[fixtures/encrypted/](fixtures/encrypted/cases.json)

## 1. 目标与边界

- **保护**：备份文件离开设备后的静态与传输安全（云盘、聊天、邮件、U 盘丢失）。没有口令的人读不到内容，也无法在不被发现的情况下篡改内容。
- **不保护**：设备上的数据库；弱口令被离线暴力猜解（KDF 只能拖慢）；文件大小及“这是一份 Flash 加密备份”这一事实；发送者身份（任何知道口令的人都能做出合法文件）。
- **明文导出保留**：导出时用户在“加密”和“不加密”中二选一，“不加密”沿用现有明文警告与 `flash-backup-v2` 格式，字节完全不变。
- **不新增第三方加密库**：四端都只用系统加密 API，参考实现用 Node 内置 `node:crypto`。

## 2. 信封格式

信封本身是 UTF-8 JSON（无 BOM），沿用现有严格 JSON 扫描：拒绝重复键、限制嵌套深度与值数量，所有对象禁止未声明字段。

```json
{
  "version": "flash-backup-enc-v1",
  "kdf": { "name": "PBKDF2-HMAC-SHA256", "iterations": 600000, "salt": "<base64，16 字节>" },
  "cipher": { "name": "AES-256-GCM", "nonce": "<base64，12 字节>" },
  "ciphertext": "<base64，密文 || 16 字节认证标签>"
}
```

| 字段 | 规则 |
| --- | --- |
| `version` | 固定为 `flash-backup-enc-v1` |
| `kdf.name` | 只允许 `PBKDF2-HMAC-SHA256` |
| `kdf.iterations` | 整数值（与现有口径一致，`1.0` 可接受，布尔拒绝），导入接受 100,000–10,000,000，导出固定写 600,000。设上限是为了防止恶意文件写入极大迭代数卡死导入 |
| `kdf.salt` | 解码后恰好 16 字节；每次导出用系统 CSPRNG 新生成 |
| `cipher.name` | 只允许 `AES-256-GCM` |
| `cipher.nonce` | 解码后恰好 12 字节；每次导出新生成，不复用 |
| `ciphertext` | 解码后 ≥ 16 字节，≤ 52,428,800 + 16 字节；末尾 16 字节为 GCM 标签 |

Base64 用 RFC 4648 §4 标准字母表、带 `=` 填充、不含空白或换行，且必须是规范编码（解码后再编码要等于原文），否则拒绝。

### 密码学定义

- **口令预处理**：Unicode NFC 规范化后编码为 UTF-8。不去除首尾空格，空格也是口令的一部分。NFC 防止 macOS、iOS、Android、HarmonyOS 输入法对“é”这类字符产生不同字节。
- **密钥**：`key = PBKDF2-HMAC-SHA256(P = UTF-8(NFC(口令)), S = salt, c = iterations, dkLen = 32)`。
- **加密**：AES-256-GCM，96 位 nonce，128 位标签。AAD 为 `version` 字段的 UTF-8 字节（`flash-backup-enc-v1`）。
- **明文**：一份完整 `flash-backup-v2` 正式导出的原始 UTF-8 字节，即现在写进 `.json` 文件的同一串字节。

只把 `version` 放进 AAD 就够了。`salt` 和 `iterations` 决定密钥，`nonce` 进入 GCM，这三项任何改动都会使认证失败。两个 `name` 只有一个合法值，未知值在解密前就拒绝。AAD 绑定版本是为了防止将来版本间的降级或混用。

### 大小上限

- 信封文件 ≤ 75,497,472 字节（72 MiB）：50 MiB 明文的 Base64 约 66.7 MiB，再加信封头的余量。
- 解密后的明文仍执行现有文件层检查：≤ 50 MiB、UTF-8、无 BOM。
- 50 MiB 远低于单个 GCM 消息约 64 GiB 的上限，所以整份文件一次性做 AEAD，不分块。现有解析本来就要把整份文件读进内存。HarmonyOS 可以分段调用 `update()`，GCM 的输出与一次性计算相同。

## 3. 导入：识别与拒绝

新客户端的标准导入和恢复入口共用以下步骤（各端实现：FlashKit `BackupImportCoordinator.parseBackupText`、Android `BackupEncryption.parseText`、HarmonyOS `BackupEncryption.parseText`）：

1. 流式读取，上限 72 MiB。
2. 现有严格 JSON 扫描，检查重复键、深度和值数量。
3. 读取顶层 `version`：
   - `flash-backup-v2` / `flash-backup-v1`：文件超过 50 MiB 则报“文件过大”，否则走现有流程，行为不变。
   - `flash-backup-enc-v1`：按 §2 严格校验信封，然后请用户输入口令，派生密钥并解密。解密得到的明文字节回到现有流程：标准入口走 `parseStrict`，恢复入口走 `parseRecovery`。
   - 以 `flash-backup-enc-` 开头的其他值：提示“需要更新 Flash 才能打开此加密备份”。
   - 其他值：沿用现有“版本不兼容”。
4. 解密出的明文如果本身又是信封，直接拒绝，不递归解密。

恢复入口不修复信封：GCM 无法部分解密，所以信封必须完整合法；“跳过坏记录”只作用于解密后的内容。

信封校验顺序是契约的一部分，决定报哪种错误：

1. 根必须是对象，`version` 是以 `flash-backup-enc-` 开头的字符串；不等于 `flash-backup-enc-v1` 即“不支持”（不再检查其余字段，未来版本可能字段不同）。
2. 根字段集合必须恰好是 `version` / `kdf` / `cipher` / `ciphertext`。
3. `kdf` 必须是对象、`kdf.name` 必须是字符串；名称未知即“不支持”；之后才检查 `kdf` 字段集合、迭代数与 salt。
4. `cipher` 同上：名称未知即“不支持”；之后检查字段集合与 nonce。
5. `ciphertext` 长度 ≤ 69,905,088 个字符，再做规范 Base64 解码，解码后 ≥ 16 字节。

重复键、非法 JSON 语法与 BOM 由各端现有严格 JSON 扫描先行拒绝（样例期望值 `invalidJSON`）。

### 新增错误

| 错误 | 含义 | 用户可见文案（中文原文，其余 7 种语言同步翻译） |
| --- | --- | --- |
| `encryptedInvalidEnvelope(path)` | 信封不符合 §2 | 加密备份文件已损坏或格式不正确 |
| `encryptedUnsupported` | 未知信封版本、KDF 或算法 | 需要更新 Flash 才能打开此加密备份 |
| `encryptedAuthenticationFailed` | GCM 认证失败 | 口令错误，或文件已损坏 |

口令错误和文件损坏在 GCM 下无法区分，因此合并成一条提示。口令错误时用户可以直接重试，不必重新选文件。导入不限制重试次数，因为攻击者手里本来就有文件，限次没有意义。

### 旧客户端（已发布版本）

旧客户端读到加密文件时：小于 50 MiB 的报“备份版本不兼容：期望 flash-backup-v2 或 v1，实际 flash-backup-enc-v1”，大于 50 MiB 的报“文件过大”。两种情况都不写库，符合“不静默丢弃”原则。这一点写进发布说明即可。

## 4. 导出

- 导出与系统分享共用同一个选择：**加密** 或 **不加密**，默认值见 §8 待决定项。
- 加密：输入两遍口令，至少 8 个 Unicode 字符（NFC 之后计数），上限 1,024 个。界面明确提示“Flash 不保存口令，忘记后无法恢复”。只在导出时检查最短长度；导入时任何非空口令都接受。
- 不加密：沿用现有明文警告。
- 流程：先执行现有正式导出和自校验（例如 macOS 的 `exportStrictJSON`），得到明文字节，再加密。不会生成本端解不开或明文本身不合格的加密文件。实现上加密后立即解密自检一次。
- 文件名：`flash-backup-YYYY-MM-DD-encrypted.json`。扩展名保持 `.json`，因为三端的文件选择器（iOS/macOS `UTType.json`、Android `application/json`、HarmonyOS 选择器）都按 JSON 过滤，不需要注册新的文件类型。
- 不保存口令：不进钥匙串，不用生物识别，不记住上次口令。派生密钥在后台线程执行并显示进度，用完尽力清零字节缓冲区。Swift String、JS 字符串和 Java String 无法保证清零，这是已知限制。
- 分享副本：加密的分享副本同样放进现有缓存目录，沿用 24 小时清理。

## 5. 各端使用的系统 API

| 端 | KDF | AES-256-GCM | 随机数 | NFC |
| --- | --- | --- | --- | --- |
| Android（minSdk 26） | `SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")`（API 26+） | `Cipher "AES/GCM/NoPadding"` + `GCMParameterSpec(128, nonce)` + `updateAAD` | `SecureRandom` | `java.text.Normalizer` |
| iOS 18 / macOS 15（FlashKit） | CommonCrypto `CCKeyDerivationPBKDF(kCCPBKDF2, …, kCCPRFHmacAlgSHA256, …)`（CryptoKit 不提供 PBKDF2） | CryptoKit `AES.GCM.seal/open(…, authenticating:)` | `SecRandomCopyBytes` | `precomposedStringWithCanonicalMapping` |
| HarmonyOS（兼容 API 12） | `@kit.CryptoArchitectureKit` `cryptoFramework.createKdf('PBKDF2\|SHA256')`（API 11+） | `createCipher('AES256\|GCM\|NoPadding')` + `GcmParamsSpec{iv, aad, authTag}`；加密时 `doFinal` 返回的标签拼在密文后，解密时拆出末 16 字节作 `authTag` | `createRandom().generateRandomSync` | `String.prototype.normalize('NFC')` |
| 参考实现（Node 20+） | `crypto.pbkdf2Sync` | `createCipheriv('aes-256-gcm')` | `crypto.randomBytes` | `normalize('NFC')` |

注意事项：

- **Android**：`PBKDF2WithHmacSHA256` 接收 `char[]`。2026-11-08 在 API 36 模拟器上用 `BackupEncryptionDeviceTest` 跑完全部共用样例（含中文、带重音及 NFD 口令），确认 Android 的实现按 UTF-8 编码，无需手写 PBKDF2。
- **HarmonyOS**：主机测试用 Node `crypto` 替身（`harmonyos/tests/crypto-fake.cjs`）代替 `@kit.CryptoArchitectureKit`，验证的是编解码与流程逻辑，不是原生加密。hvigor 未签名 HAP 构建已通过（`String.normalize`、异步 `createKdf` / `createCipher` 均可编译），原生 cryptoFramework 的实际输出仍待真机或模拟器验证，验收记录如实标注。

### 为什么选这些方案

- **为什么用 PBKDF2，而不用 Argon2id 或 scrypt**：Android 与 Apple 都没有系统级的 Argon2/scrypt，要用就得引入第三方库。PBKDF2-HMAC-SHA256 迭代 600,000 次是 OWASP 当前对该算法的推荐值。将来如果要换算法，用新的 `kdf.name` 加升级规则演进，或者升级到 `flash-backup-enc-v2`。
- **为什么用 JSON 信封，而不用二进制格式**：二进制可以省掉约 33% 的 Base64 膨胀，但三端的选择器都按 `.json` 过滤，旧客户端也只会报“不是有效 JSON”，而不是明确的版本提示。备份文件不大，这点体积可以接受。
- **为什么不分块（类似 age 的 STREAM 结构）**：50 MiB 上限下一次性 GCM 足够安全，分块只会给四份实现增加出错的地方。

## 6. 契约样例与测试

所有样例放在 `fixtures/encrypted/`，由 `scripts/backup-contract/generate-encrypted.cjs` 用固定的 salt、nonce 和口令确定性生成；`--check` 模式与 `npm test` 都会核对提交的样例与生成结果逐字节一致，CI 同样运行 `--check`。结构由 `flash-backup-enc-v1.schema.json` 描述，参考实现 `envelope.cjs` 执行上面的分阶段校验。清单是独立的 `fixtures/encrypted/cases.json`（不并入明文 `cases.json`，避免现有消费方把信封当 v2 文档读）：`passphrase` 为共用口令，每条用例有 `file`、`expect`（`ok` / `invalidJSON` / `invalidEnvelope` / `unsupported` / `authenticationFailed`），以及可选的 `passphrase`、`plaintext`（相对 `fixtures/`）与 `innerValid`（明文能否通过严格入口）。清单是纯 ASCII，口令用 `\u` 转义，防止编辑器改写 NFC/NFD。样例用 100,000 次迭代以加快四端测试，`valid-enc-minimal.json` 用正式导出的 600,000 次。

- 共用口令：含中文与带重音字符的 NFC 口令。另有一条用例把同一口令的 NFD 形式输入后必须能解开。
- 正例：`valid-full.json`、`valid-schema2.json`、`valid-minimal.json` 分别加密，解密后的明文字节与原样例逐字节相同。
- 认证失败：错误口令、密文翻转一位、标签翻转一位。
- 不支持：`flash-backup-enc-v9`、未知 KDF、未知 cipher。
- 信封非法：迭代数 99,999、10,000,001 或为布尔值，salt 为 15 字节，nonce 为 13 字节，非规范 Base64，含空白，未知字段，缺少字段，重复键。
- 内层：解密得到 `invalid-importance-range.json`，标准入口失败并带内层路径，恢复入口跳过一条日志；内层又是一个信封时拒绝。
- 生成器自测：改动 AAD 后解密失败。

各端测试：

- 读取全部共用样例并核对期望结果。
- 加密后再解密的往返测试，salt 和 nonce 可注入，以便与样例逐字节对比。
- 导出选择“不加密”时，输出与现有明文导出逐字节相同。
- 旧明文 v1/v2 文件导入行为不变：现有所有样例继续通过。

## 7. 实施顺序（已完成）

1. 契约：本文定稿，加入 Schema、生成器、样例和 `cases.json` 条目；修改 README §1“本次不定义……加密”的表述，并在 acceptance.md 增加验收行。`npm test` 必须保持通过。
2. FlashKit：新增 `BackupEncryption.swift`，在 `BackupImportCoordinator` 中加入口令步骤，并在 iOS 与 macOS 设置页加入导出选择和导入口令框。
3. Android：新增 `data/BackupEncryption.kt`，在 `SettingsViewModel` 的导入状态机中加入口令步骤，修改导出对话框与 `BackupTransfer`。
4. HarmonyOS：新增 `data/BackupEncryption.ets`，修改 `BackupController`、`ProfilePage` 与 `ShareService`，并在 `ets-loader.cjs` 中加入加密替身。
5. 八种语言的新文案、CHANGELOG 与验收记录。

四端同仓同发。如果需要分批发布，必须先让四端都能读取加密文件，再开放导出加密文件，否则会出现本仓库自己的旧版本读不了新文件的情况。

## 8. 决定项（2026-11-08 按建议批准）

| # | 问题 | 决定 |
| --- | --- | --- |
| 1 | 导出时默认选中哪一项 | **默认加密**。用户仍可一步改为不加密 |
| 2 | 口令最短长度 | **8 个字符**，不做强度评分 |
| 3 | KDF | **PBKDF2-HMAC-SHA256，600,000 次**，不引入 Argon2 第三方库 |
| 4 | 系统分享是否同样提供加密 | **是**，与文件导出共用同一个选择 |


## 2026-11-14 内层版本扩展

外层信封与密码算法不变。新版 Apple 可加密/解密完整 flash-backup-v3 快照，并继续支持 v2；解密后的严格校验、版本拒绝和事务边界见 [v3 规格](flash-backup-v3.md)。旧客户端解密后遇到未知内层版本必须拒绝且不写库。
