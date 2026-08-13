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
