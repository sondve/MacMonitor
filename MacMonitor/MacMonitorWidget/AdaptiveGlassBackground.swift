import SwiftUI
import WidgetKit

/// 1:1 复刻 macOS 左上角原生「电池小组件」与「控制面板预览框」的天空蓝液态玻璃视觉效果
/// 彻底封死系统底层那块刺眼的纯白底板，在太浩湖蓝天壁纸上呈现浑然一体的光学玻璃质感！
public struct AdaptiveGlassBackground: View {
    var opacityFactor: Double

    public init(opacityFactor: Double = 0.0) {
        self.opacityFactor = min(1.0, max(0.0, opacityFactor))
    }

    public var body: some View {
        ZStack {
            if opacityFactor < 0.45 {
                // 0% ~ 45%：精确复刻左上角原生电池小组件 & 控制面板预览框的「天空冰蓝玻璃」色值
                let glassProgress = opacityFactor / 0.45 // 0.0 -> 1.0

                // 1. 100% 不透明的天空蓝光学基底（彻底盖死底下的系统白板，颜色与左上角电池组件完全一致）
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.55, blue: 0.82), // 顶部清澈天空蓝
                        Color(red: 0.26, green: 0.62, blue: 0.84), // 中部太浩湖水蓝
                        Color(red: 0.16, green: 0.46, blue: 0.68)  // 底部深邃折射蓝
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 2. 液态玻璃顶部柔光镜面感
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18 * (1.0 - glassProgress * 0.5)),
                        Color.clear,
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 3. 随滑块向右拉动 (0% -> 45%) 平滑增加白雾过渡
                Color.white.opacity(glassProgress * 0.25)
            } else {
                // 45% ~ 100%：平滑过渡为左侧「天气」小组件同款的纯白瓷底板（此时文字自动切换为深黑色）
                let whiteProgress = (opacityFactor - 0.45) / 0.55

                Color(red: 0.90, green: 0.95, blue: 0.99)
                Color.white.opacity(0.75 + 0.25 * whiteProgress)
            }
        }
    }
}

/// 液态玻璃边缘高光折射描边（与左上角原生电池组件的亮白细边框完全一致）
public struct LiquidGlassSurfaceModifier: ViewModifier {
    let opacity: Double

    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ContainerRelativeShape()
                    .strokeBorder(
                        LinearGradient(
                            colors: opacity < 0.45
                                ? [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.38)
                                ]
                                : [
                                    Color.black.opacity(0.08),
                                    Color.black.opacity(0.04)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
    }
}

extension View {
    public func liquidGlassSurface(opacity: Double) -> some View {
        self.modifier(LiquidGlassSurfaceModifier(opacity: opacity))
    }
}
