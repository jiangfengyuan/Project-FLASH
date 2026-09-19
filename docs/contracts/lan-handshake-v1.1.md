# Flash Aero 局域网备份 — 认证握手 v1.1（三端统一实施规格）

> 背景：安全审计（2026-09-19）发现 FLASH-AERO/1 握手将 PIN 明文上链、发送方无需证明 PIN 知识（伪造 mDNS 服务可注入数据）、payload 无完整性校验。本规格取代旧首包明文 PIN 格式。**三端必须逐字一致实现**，任何一端偏差都会导致跨端配对失败或安全降级。

## 符号约定

- `PIN`：发送方屏幕显示的 **6 位十进制数字**（由 4 位升级为 6 位，三端 UI 文案与输入框同步改）。
- `HMAC`：HMAC-SHA256。
- `hex(x)`：小写十六进制编码。
- 行分隔：`\n`（LF），行内字段单空格分隔。
- 随机数：16 字节密码学安全随机数。

## 握手流程

1. **接收方**在 TCP 连接建立后立即发送一行：
   ```
   CHALLENGE <nonce>\n
   ```
   `nonce = hex(16 字节随机数)`（32 个十六进制字符）。每个连接一个独立 nonce。
2. **发送方**回复：
   ```
   FLASH-AERO/1 <proof>\n
   ```
   `proof = hex(HMAC-SHA256(key = PIN 的 ASCII 字节, msg = "flash-aero-handshake:" || nonce))[0:32]`（取前 16 字节，32 个 hex 字符）。
   接收方用本地输入的 PIN 计算同一 proof，**常数时间比较**；不等即拒绝该次握手并按下方尝试限制计数。
3. 通过后**发送方**发送头行与负载：
   ```
   OK <size> <mac>\n<payload>
   ```
   - `size`：payload 十进制字节数（严格数字格式 `/^\d+$/` 或等价严格解析，拒绝尾随字符）。
   - `mac = hex(HMAC-SHA256(key = PIN 的 ASCII 字节, msg = payload 字节))[0:64]`（取前 32 字节，64 个 hex 字符）。
   - 接收方读满 size 字节后校验 mac，不等即**整体丢弃并报错**，不得进入解析/预览。
4. 负载校验上限不变：`size ≤ 50MB`、头行 ≤ 64 字节、导入侧既有 StrictJson 契约校验全部保留。

## 限制与计时

- proof 验证失败：每连接最多 5 次；第 1–4 次失败后响应延迟按 **1s、2s、4s、8s** 递增；第 5 次失败即断开该连接并计数。会话 60s 总窗口不变。
- 连接空闲超时 15s 不变；**新增传输总时长硬顶 120s**（防慢速滴流占用缓冲与连接槽），先到先触发。
- 发送方监听仍为本机全接口（实现现状），由 UI「仅可信局域网」提示兜底；本规格不解决 E2E 加密（后续 PAKE 另立项），但 PIN 从此不再出现在链路上。

## 设备发现

- 设备条目键改为 `host:port`（而非 serviceName），同名伪造服务不得互相顶替；同名条目并列显示。

## 兼容性

- 旧版（明文 PIN 首包）发送方/接收方与新版本均无法配对（握手第一步即不匹配）。**本应用三端同仓同发，接受此断裂**，文案无需兼容提示。
- 协议版本字符串仍为 `FLASH-AERO/1`（版本号字段本身未变，仅握手语义升级；如实现中有独立版本协商字段可标 `1.1`）。

## 各端实现提示

- **Android (Kotlin)**：`javax.crypto.Mac` + `MessageDigest.isEqual` 常数时间比较；nonce 用 `SecureRandom`。
- **macOS (Swift)**：CryptoKit `HMAC<SHA256>`；`SymmetricKey` 由 PIN ASCII 字节构造；比较用 `Array` 常数时间循环或 `CryptoKit` 无内建时手写。
- **HarmonyOS (ArkTS)**：`@kit.NetworkKit`/`@ohos.security.cryptoFramework` 的 Hmac（如 API 受限则在报告中说明并给出等价实现）；手写常数时间比较。

## 测试要求

- 各端更新/新增协议测试：正确 proof 通过、错误 proof 拒绝、5 次后断开、OK 行严格解析（`OK 123abc` 拒绝）、mac 篡改整体丢弃、6 位 PIN 生成格式。
- HarmonyOS 主机测试（node --test）保持可加载；UI/系统 API 部分以编译（hvigor）覆盖。
