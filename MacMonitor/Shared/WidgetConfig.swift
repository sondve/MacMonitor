import Foundation
import WidgetKit

/// 跨进程共享数据快照结构体
public struct SharedMonitorPayload: Codable, Sendable {
    public var opacity: Double = 0.0
    public var cpuUsage: Double = 0.0
    public var cpuCores: [Double] = []
    public var gpuUsage: Double = 0.0
    public var gpuHistory: [Double] = []
    public var memUsage: Double = 0.0
    public var memUsedStr: String = "0 / 16 GB"
    public var memSwapStr: String = "0 MB"
    public var diskUsage: Double = 0.0
    public var diskFreeStr: String = "256 GB"
    public var diskReadStr: String = "0 KB/s"
    public var diskWriteStr: String = "0 KB/s"
    public var netUpload: Double = 0.0
    public var netDownload: Double = 0.0
    public var netUploadStr: String = "0 KB/s"
    public var netDownloadStr: String = "0 KB/s"
    public var netLocalIP: String = "127.0.0.1"
    public var batteryPercent: Int = 100
    public var batteryPlugged: Bool = true
    public var batteryWattage: Double = 0.0
    public var batteryTemp: Double = 29.0

    public init() {}
}

public struct WidgetConfig {
    public static let appGroupID = "group.com.local.macmonitor"
    public static let defaultOpacity: Double = 0.0

    /// 固定使用 /Users/Shared 公共目录作为主程序与小组件的跨进程高速交换区
    private static let sharedFileURL = URL(fileURLWithPath: "/Users/Shared/macmonitor_shared_state.json")

    public static func loadPayload() -> SharedMonitorPayload {
        guard let data = try? Data(contentsOf: sharedFileURL),
              let payload = try? JSONDecoder().decode(SharedMonitorPayload.self, from: data) else {
            return SharedMonitorPayload()
        }
        return payload
    }

    public static func savePayload(_ payload: SharedMonitorPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: sharedFileURL, options: .atomic)
        }
    }

    /// 获取或设置透明度 (0.0: 液态玻璃 ~ 1.0: 纯白卡片)
    public static var backgroundOpacity: Double {
        get {
            let p = loadPayload()
            return min(1.0, max(0.0, p.opacity))
        }
        set {
            var p = loadPayload()
            p.opacity = min(1.0, max(0.0, newValue))
            savePayload(p)
        }
    }

    /// 统一通知小组件重新绘制快照
    public static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 保存透明度并立即刷新所有桌面小组件
    public static func updateOpacityAndReload(_ opacity: Double) {
        backgroundOpacity = opacity
        reloadWidgets()
    }
}
