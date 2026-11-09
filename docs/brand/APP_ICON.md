# Flash 一闪 · 官方 App 图标规范

版本：**2026-11-09**（平台集成于同日审计修订） · 状态：**Approved / Standard**

![Flash 一闪标准图标](../../assets/brand/flash-standard-icon.png)

## 品牌基准

以 `assets/brand/flash-standard-icon.png` 为**唯一跨平台视觉主资源**（1024 × 1024、透明 PNG、带 Alpha）。
各平台资源全部由脚本从它派生，**不要手工修改派生文件**，也不要改动主资源本身。

- **材质与配色**：温暖米白色磨砂纸，杏色、淡桃色背纸，真实纸张纤维与自然漫反射，柔和接触阴影。
- **构图**：2–3 层错位叠放的圆角纸张；最上层**右上角内卷折角**清晰可见。
- **手写主题**：`Make It Possible` 为铅笔灰色两行手写文字；保留 `It` 旁的三笔强调线。
- **下划线**：位于 `Possible` 下方，保持**浅而平缓的弧度**，不作明显向下弯曲。
- **铅笔**：自然木色六角笔杆、金色金属箍与粉色橡皮，斜置于右侧；石墨笔尖触碰下划线终点。
- **边缘**：圆润且有自然厚度，禁止添加白底、绘制棋盘格、擅自改变物件数量、文字或铅笔朝向。

> 主资源现为 8 位调色板 PNG（256 色，Alpha 最高 253）。派生资源沿用这一色彩精度；若日后取得 32 位 RGBA 原稿，
> 应替换主资源后重新生成（见「重新生成」），渐变与纸张纹理会更细腻。

## 底色

需要不透明底的场合统一使用暖米白 **`#FBF6EE`**：iOS 默认图标、macOS 底板、Android 自适应背景、HarmonyOS 背景层。

## 各端集成

| 平台 | 资源 | 规则 |
| --- | --- | --- |
| iOS 18+ | `ios/Flash/Assets.xcassets/AppIcon.appiconset/`：`AppIcon-1024.png`（默认）、`-dark`、`-tinted` | 单尺寸 1024，系统缩放其余尺寸。默认图为主资源 1:1 合成到 `#FBF6EE` 的**不透明 RGB**（App Store 不接受透明图标）；系统圆角遮罩不会裁到纸张。深色 = 同构图、**透明底**、亮度 ×0.9；着色 = 同构图的**灰度**（亮度通道）+ 透明底。见下方外观矩阵 |
| macOS 15+ | `macos/Flash/Assets.xcassets/AppIcon.appiconset/`：16–1024 七个尺寸（十个槽位） | macOS 需要逐尺寸资源。按 Big Sur–macOS 15 网格：1024 画布中 **824 px 连续圆角底板**（四周约 100 px 透明边距 + 柔和投影），底板内容即 iOS 默认图。旧版铺满画布的透明纸张会比 Dock 中其它图标大约两成，且不符合系统圆角形状 |
| Android 8.0+（minSdk 26） | `res/mipmap-anydpi-v26/ic_launcher.xml` → 背景 `@color/ic_launcher_background`（`#FBF6EE`）、前景 `drawable-nodpi/flash_launcher_foreground.png`、单色 `drawable-nodpi/flash_launcher_monochrome.png`（均 432 px = 108 dp @xxxhdpi） | 前景最远像素距中心 ≤ 32.5 dp，完整落在 66 dp 安全区内，任何启动器遮罩（圆形、方圆、圆角方、水滴）都不会裁切。单色层为**专门派生的剪影**：实心纸张，镂空手写字、下划线、折角与纸张层边、铅笔轮廓；系统只取 Alpha 并着色（Android 13+ 主题图标） |
| HarmonyOS | 桌面图标：`entry/src/main/resources/base/media/layered_image.json`；应用级图标：`AppScope/resources/base/media/app_layered_image.json`；两者都引用 `flash_icon_foreground.png`（1024 透明）与 `flash_icon_background.png`（1024 不透明 `#FBF6EE`）；启动页图标 `flash_standard_icon.png`（512 透明） | 华为图标资源规范：**必须为分层资源**、1024 × 1024、正方形无圆角（系统生成遮罩）、PNG、**背景不得含透明像素**，否则无法通过上架检查。前景占画布 84%，远离四角。AppScope 与模块同名资源在构建时由 AppScope 覆盖，因此两处文件必须一致（脚本保证）。启动页背景色在 `dark/element/color.json` 中提供深色版本 |

### iOS 外观矩阵

| 外观 | 实现 | 说明 |
| --- | --- | --- |
| Default / Light | 资源 `AppIcon-1024.png` | 不透明 |
| Dark | 资源 `AppIcon-1024-dark.png`（透明底） | 纸张占图标约 95%，故略降亮度；系统深色底只在边缘可见 |
| Tinted Light / Tinted Dark | 资源 `AppIcon-1024-tinted.png`（灰度） | 系统按用户色调着色：浅色纸张变为色调色，铅笔灰手写字保持深色、可读 |
| Clear Light / Clear Dark | 系统生成（iOS 26+） | 资源目录无 Clear 槽位；系统由位图图标自动分割前后景并生成。手写字等细线不会获得玻璃效果，属预期 |

暂不使用 Icon Composer（`.icon`）：Apple 说明加入 `.icon` 会**取代**现有资源目录，iOS 18 / macOS 15 只能得到 Xcode 生成的近似版本；本项目最低版本仍为 iOS 18 / macOS 15，资源目录是最简单且完全受支持的方案。若日后最低版本提升到 iOS 26 / macOS 26，或需要精确控制 Clear 外观，再用纸张、文字、铅笔分层制作 `.icon`。

## 重新生成与校验

```bash
pip install pillow numpy                                   # 仅开发工具依赖
python3 scripts/brand/generate_app_icons.py                # 从主资源重新生成全部派生资源
python3 scripts/brand/generate_app_icons.py --check        # 校验派生资源与主资源一致、各端配置引用正确
python3 scripts/brand/generate_app_icons.py --preview /tmp/icon-preview   # 生成合成预览（非真机截图）
```

`--check` 还校验：iOS 默认图无 Alpha、HarmonyOS 背景层无透明像素、Android 前景不超出安全区、
`ic_launcher.xml` 单色层与 HarmonyOS 两处 `icon` 引用正确。

Android 单色层中的铅笔是按主资源实测锚点绘制的简化剪影（`PENCIL_*` 常量，单位为主资源像素）。
**更换主资源时须重新测量这些锚点**：用 `--preview` 输出的 Android 主题图标检查铅笔是否与彩色版重合。

## 变更要求

- 不要将旧版蓝色闪电图案作为新的全彩 App 图标（旧的 `ic_launcher_foreground.xml` 与 `icon.svg` 已删除）。
- 所有尺寸由此版设计等比缩放，不单独修改文字、折角、铅笔或纸张层数。
- 后续若变更图标，应先更新主资源和本文规范，再运行脚本同步各端资产。
- 图标变更需要在对应平台的构建产物与主屏实际展示中检查；**仅提交图片或合成预览不代表已完成真机验收**。
