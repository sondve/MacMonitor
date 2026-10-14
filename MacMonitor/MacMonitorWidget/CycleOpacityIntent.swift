import AppIntents
import WidgetKit

@available(macOS 14.0, *)
struct CycleOpacityIntent: AppIntent {
    static var title: LocalizedStringResource = "切换小组件透明度"
    static var description = IntentDescription("在 0%、50%、100% 三档透明度之间循环切换")

    @MainActor
    func perform() async throws -> some IntentResult {
        let current = WidgetConfig.backgroundOpacity
        let next: Double
        if current < 0.25 {
            next = 0.50
        } else if current < 0.85 {
            next = 1.00
        } else {
            next = 0.00
        }

        WidgetConfig.updateOpacityAndReload(next)
        return .result()
    }
}

@available(macOS 14.0, *)
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "立即刷新监控数据"
    static var description = IntentDescription("手动触发小组件重新读取最新硬件状态并重绘")

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetConfig.reloadWidgets()
        return .result()
    }
}
