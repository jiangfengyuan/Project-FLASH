# Flash 一闪 · 官方 App 图标规范

版本：**2026-11-09** · 状态：**Approved / Standard**

![Flash 一闪标准图标](../../assets/brand/flash-standard-icon.png)

## 品牌基准

以 `assets/brand/flash-standard-icon.png` 为**唯一跨平台视觉主资源**（1024 × 1024、透明 PNG、带 Alpha）。

- **材质与配色**：温暖米白色磨砂纸，杏色、淡桃色背纸，真实纸张纤维与自然漫反射，柔和接触阴影。
- **构图**：2–3 层错位叠放的圆角纸张；最上层**右上角内卷折角**清晰可见。
- **手写主题**：`Make It Possible` 为铅笔灰色两行手写文字；保留 `It` 旁的三笔强调线。
- **下划线**：位于 `Possible` 下方，保持**浅而平缓的弧度**，不作明显向下弯曲。
- **铅笔**：自然木色六角笔杆、金色金属箍与粉色橡皮，斜置于右侧；石墨笔尖触碰下划线终点。
- **边缘**：圆润且有自然厚度，禁止添加白底、绘制棋盘格、擅自改变物件数量、文字或铅笔朝向。

## 各端集成

| 平台 | 路径及规则 |
| --- | --- |
| 品牌主资源 | `assets/brand/flash-standard-icon.png`，1024 像素透明 PNG |
| iOS | `ios/Flash/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`。因 Apple App 图标的提交限制，采用米白底**无 Alpha**衍生版；视觉主体不变 |
| macOS | `macos/Flash/Assets.xcassets/AppIcon.appiconset/`，16–1024 像素完整资源组（透明 PNG） |
| Android | `android/app/src/main/res/drawable-nodpi/flash_launcher_foreground.png`，432 像素带安全边距的自适应图标前景；使用暖米白底色 |
| HarmonyOS | `harmonyos/entry/src/main/resources/base/media/flash_standard_icon.png`，512 像素透明 PNG，在 `module.json5` 中引用 |

## 变更要求

- 不要将旧版蓝色闪电图案作为新的全彩 App 图标。
- 所有尺寸由此版设计等比缩放，不单独修改文字、折角、铅笔或纸张层数。
- 后续若变更图标，应先更新主资源和本文规范，再同步各端资产。
- 图标变更需要在对应平台的构建产物与主屏实际展示中检查；**仅提交图片不代表已完成真机验收**。
