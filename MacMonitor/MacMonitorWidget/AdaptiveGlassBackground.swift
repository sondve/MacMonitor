import SwiftUI
import WidgetKit

/// 专为 macOS 26 桌面小组件打造的光学背景：
/// - 0% ~ 45% (液态玻璃态)：采用 .dark 深色毛玻璃 + 冰海蓝透光衬底，确保白色文字在任何浅色壁纸下都如预览图般清晰锐利
/// - 45% ~ 100% (纯白卡片态)：采用 .light 明亮毛玻璃 + 纯白瓷叠加层，配合深色炭黑文字
public struct AdaptiveGlassBackground: View {
    var opacityFactor: Double

    public init(opacityFactor: Double = 0.0) {
        self.opacityFactor = min(1.0, max(0.0, opacityFactor))
    }

    public var body: some View {
        ZStack {
            if opacityFactor < 0.45 {
                // 0% ~ 45% 液态玻璃模式 (与控制面板内嵌预览窗 100% 同源)
                let glassProgress = opacityFactor / 0.45

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.36, blue: 0.56).opacity(0.42 * (1.0 - glassProgress * 0.5)),
                        Color(red: 0.10, green: 0.24, blue: 0.38).opacity(0.55 * (1.0 - glassProgress * 0.5))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ContainerRelativeShape()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            } else {
                // 45% ~ 100% 纯白卡片模式
                let whiteProgress = (opacityFactor - 0.45) / 0.55

                Rectangle()
                    .fill(.regularMaterial)
                    .environment(\.colorScheme, .light)

                Rectangle()
                    .fill(Color.white.opacity(0.68 + 0.32 * whiteProgress))
            }
        }
    }
}
