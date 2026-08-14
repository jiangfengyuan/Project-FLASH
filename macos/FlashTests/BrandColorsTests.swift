import Testing
import SwiftUI
import AppKit
@testable import Flash

@Suite("主题色")
struct BrandColorsTests {
    /// 在指定外观下把动态色解析为 sRGB，返回可断言通道的 NSColor
    private func resolve(_ color: Color, as appearance: NSAppearance.Name) -> NSColor {
        let nsColor = NSColor(color)
        var rgb: NSColor!
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            rgb = nsColor.usingColorSpace(.sRGB)
        }
        return rgb
    }

    @Test func hexColorParsesRGBComponents() {
        // 固定浅色外观，验证 urgent 的 light 变体 #FF6B6B
        let rgb = resolve(ColorTag.urgent.color, as: .aqua)
        #expect(abs(rgb.redComponent - 1.0) < 0.01)         // FF
        #expect(abs(rgb.greenComponent - 0x6B / 255.0) < 0.01)
        #expect(abs(rgb.blueComponent - 0x6B / 255.0) < 0.01)
    }

    @Test func dynamicColorDiffersByAppearance() {
        let color = BrandColors.dynamic(light: "#FF6B6B", dark: "#FF8A80")
        let light = resolve(color, as: .aqua)
        let dark = resolve(color, as: .darkAqua)
        // light 外观解析为 #FF6B6B
        #expect(abs(light.redComponent - 1.0) < 0.01)
        #expect(abs(light.greenComponent - 0x6B / 255.0) < 0.01)
        #expect(abs(light.blueComponent - 0x6B / 255.0) < 0.01)
        // dark 外观解析为 #FF8A80（与 light 确实不同）
        #expect(abs(dark.redComponent - 1.0) < 0.01)
        #expect(abs(dark.greenComponent - 0x8A / 255.0) < 0.01)
        #expect(abs(dark.blueComponent - 0x80 / 255.0) < 0.01)
    }

    @Test func everyTagAndLevelHasColor() {
        for tag in ColorTag.allCases {
            _ = BrandColors.tagColor(tag)
            #expect(tag.colorHex != tag.darkColorHex)
        }
        for level in EmotionLevel.allCases {
            _ = BrandColors.emotionColor(level)
            #expect(level.colorHex != level.darkColorHex)
        }
        for sub in SubEmotion.allCases {
            _ = sub.color
            #expect(sub.colorHex != sub.darkColorHex)
        }
    }
}
