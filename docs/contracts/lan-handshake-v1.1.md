# Flash Aero 局域网备份 — 认证握手 v1.1（三端统一实施规格，修正版）

> 背景：安全审计（2026-09-19）发现 FLASH-AERO/1 握手将 PIN 明文上链、发送方无需证明 PIN 知识（伪造 mDNS 服务可注入数据）、payload 无完整性校验。**本规格是 v1.1 最终修正版，方向与编码已经过三端仲裁**。任何一端偏差都会直接导致跨端配对失败或安全降级。

## 角色定义（务必遵守）

- **发送方**：运行「局域网发送/发送备份」的一方。它在本地监听 TCP 端口，通过 mDNS/Bonjour 广播服务，屏幕显示 PIN。**发送方必须能证明它知道这个 PIN**。
- **接收方**：运行「局域网接收」的一方。它浏览 mDNS 发现发送方服务、点击某个设备、输入该设备屏幕上显示的 PIN，然后主动发起 TCP 连接到发送方。**接收方必须先发送 CHALLENGE，并验证发送方返回的 proof**。

**仲裁说明**：评审中发现 Android/macOS 初版实现把 CHALLENGE 方向做反了（发送方发 CHALLENGE、接收方证明 PIN）。该方向无法抵御伪造发送方攻击——伪造方无需知道 PIN 即可坐等接收方自证，随后注入 payload。**最终方向以本文件为准：接收方发 CHALLENGE，发送方证明 PIN。**

## 符号约定

- `PIN`：发送方屏幕显示的 **6 位十进制数字**（由 4 位升级为 6 位，三端 UI 文案与输入框同步改）。
- `HMAC`：HMAC-SHA256。
- `hex(x)`：小写十六进制编码。
- 行分隔：`\n`（LF），行内字段单空格分隔。
- 随机数：16 字节密码学安全随机数。
- `nonceHex = hex(16 字节随机数)`（32 个十六进制字符，出现在链上）。

## 握手流程

1. **接收方**在 TCP 连接建立后立即发送一行：
   ```
   CHALLENGE <nonceHex>\n
   ```
2. **发送方**回复：
   ```
   FLASH-AERO/1 <proof>\n
   ```
   `proof = hex(HMAC-SHA256(key = PIN 的 ASCII 字节, msg = "flash-aero-handshake:" || nonceHex 的 ASCII 字节))[0:32]`
   （取 HMAC 输出的前 16 字节，编码为 32 个 hex 字符）。

   接收方用本地输入的 PIN 和刚才发出去的 `nonceHex` 字符串重新计算 `proof`，**常数时间比较**；不等即拒绝该次 proof 并按下方尝试限制计数。
3. proof 通过后，**发送方**发送头行与负载：
   ```
   OK <size> <mac>\n<payload>
   ```
   - `size`：payload 十进制字节数（严格数字格式 `/^\d+$/`，拒绝前导零、尾随字符、科学计数等）。
   - `mac = hex(HMAC-SHA256(key = PIN 的 ASCII 字节, msg = payload 字节))[0:64]`（取前 32 字节，64 个 hex 字符）。
   - 接收方读满 `size` 字节后校验 `mac`，不等即**整体丢弃并报错**，不得进入解析/预览。

## 行长度限制

- `CHALLENGE <32hex>\n` 与 `FLASH-AERO/1 <32hex>\n` 均 ≤ 64 字节。
- `OK <size> <64hex>\n` 实际长度取决于 `size` 的十进制位数（最多 8 位），范围为 68–77 字节；因此 **OK 头行上限取 96 字节**（含换行），并以严格正则 `^OK \d+ [0-9a-f]{64}$` 解析。实现中可统一取 128 字节缓冲。
- 任何头行超过对应上限即判为非法并断开。

## 限制与计时

- proof 验证失败按**每连接**计数，最多 5 次；第 1–4 次失败后响应延迟按 **1s、2s、4s、8s** 递增；第 5 次失败即断开该连接。会话 60s 总窗口不变。
- 连接空闲超时 15s 不变；**新增传输总时长硬顶 120s**（防慢速滴流占用缓冲与连接槽），先到先触发。
- 发送方监听仍为本机全接口（实现现状），由 UI「仅可信局域网」提示兜底；本规格不解决端到端加密（后续 PAKE 另立项）。

## 设备发现

- 设备条目键改为 `host:port`（而非 serviceName），同名伪造服务不得互相顶替；同名条目并列显示。

## 兼容性

- 旧版（明文 PIN 首包）发送方/接收方与新版本均无法配对。**本应用三端同仓同发，接受此断裂**，文案无需兼容提示。

## 各端实现提示

- **Android (Kotlin)**：`javax.crypto.Mac` + `MessageDigest.isEqual` 常数时间比较；nonce 用 `SecureRandom`；proof/mac 的 HMAC 消息必须是**字符串** `flash-aero-handshake:<nonceHex>` 与 payload 字节。
- **macOS (Swift)**：CryptoKit `HMAC<SHA256>`；`SymmetricKey` 由 PIN ASCII 字节构造；比较用常数时间循环。
- **HarmonyOS (ArkTS)**：`@ohos.security.cryptoFramework` 的 Hmac；手写常数时间比较；当前 HarmonyOS 实现已与本规格一致，可作为另外两端的参考实现。

## 测试要求

- 各端更新/新增协议测试：正确 proof 通过、错误 proof 拒绝、5 次后断开、OK 行严格解析（`OK 123abc` 等拒绝）、mac 篡改整体丢弃、6 位 PIN 生成格式、方向反置配对失败。
- 三端互操作：修复后必须至少完成一对跨端组合的真机/模拟器传输验证（如 Android 发送 ↔ HarmonyOS 接收）。
