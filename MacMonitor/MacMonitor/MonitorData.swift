import Foundation
import SwiftUI
import Combine
import AppKit
import IOKit
import IOKit.ps
import Metal
import Darwin
import ServiceManagement
import CoreWLAN
import UserNotifications

// MARK: - 状态栏模块枚举 (6 大核心模块)
public enum StatusItemType: String, CaseIterable, Identifiable {
    case cpu = "cpu"
    case gpu = "gpu"
    case memory = "memory"
    case disk = "disk"
    case network = "network"
    case battery = "battery"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cpu: return L10n.t("CPU 处理器", "CPU")
        case .gpu: return L10n.t("GPU 图形核心", "GPU")
        case .memory: return L10n.t("内存与交换空间", "Memory & Swap")
        case .disk: return L10n.t("磁盘与读写吞吐", "Disk & I/O")
        case .network: return L10n.t("网络吞吐与连接", "Network & Wi-Fi")
        case .battery: return L10n.t("电池与电源", "Battery & Power")
        }
    }

    public var description: String {
        switch self {
        case .cpu: return L10n.t("监控 P/E 大小核负载率与高占用进程", "Monitor P/E cores usage and top processes")
        case .gpu: return L10n.t("监控图形处理器负载与点阵瀑布图", "Monitor GPU load and matrix history")
        case .memory: return L10n.t("监控物理内存压力、压缩内存与 Swap 交换", "Monitor RAM breakdown and Swap usage")
        case .disk: return L10n.t("监控系统盘可用空间与 SSD 实时读写速率", "Monitor free disk space and R/W speeds")
        case .network: return L10n.t("监控实时上下行速率、局域网 IP 与 Wi-Fi", "Monitor speeds, local IP, and Wi-Fi link")
        case .battery: return L10n.t("监控电量、健康度、温度与实时瓦数", "Monitor battery health, temp, and wattage")
        }
    }

    public var iconName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "display"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        }
    }

    public var themeColor: Color {
        switch self {
        case .cpu: return .cyan
        case .gpu: return Color(red: 0.35, green: 0.78, blue: 0.98)
        case .memory: return .purple
        case .disk: return .indigo
        case .network: return .green
        case .battery: return .orange
        }
    }
}

// MARK: - 进程占用条目结构
public struct ProcessMetricItem: Identifiable {
    public let id: pid_t
    public let name: String
    public let icon: NSImage?
    public let memoryBytes: UInt64
    public let formattedValue: String
}

// MARK: - 内存与 Swap 详细数据结构
public struct MemoryDetailInfo {
    public var usagePercent: Double = 0.0
    public var totalGB: Double = 16.0
    public var usedGB: Double = 0.0
    public var appGB: Double = 0.0
    public var wiredGB: Double = 0.0
    public var compressedGB: Double = 0.0
    public var freeGB: Double = 16.0
    public var swapUsedMB: Double = 0.0
    public var pressureLevel: Int = 0

    public var usedFormatted: String {
        String(format: "%.1f / %.0f GB", usedGB, totalGB)
    }

    public var swapFormatted: String {
        if swapUsedMB >= 1024 {
            return String(format: "%.2f GB", swapUsedMB / 1024.0)
        } else {
            return String(format: "%.0f MB", swapUsedMB)
        }
    }

    public init() {}
}

// MARK: - 磁盘与 I/O 详细数据结构
public struct DiskDetailInfo {
    public var usagePercent: Double = 0.0
    public var totalGB: Double = 512.0
    public var freeGB: Double = 256.0
    public var usedGB: Double = 256.0
    public var readBytesPerSec: Double = 0.0
    public var writeBytesPerSec: Double = 0.0
    public var readFormatted: String = "0 KB/s"
    public var writeFormatted: String = "0 KB/s"

    public var spaceFormatted: String {
        String(format: "%.0f GB 可用 / 共 %.0f GB", freeGB, totalGB)
    }

    public init() {}
}

// MARK: - 网络传输与连接详细数据结构
public struct NetworkSpeedInfo {
    public var uploadSpeed: Double = 0.0
    public var downloadSpeed: Double = 0.0
    public var uploadFormatted: String = "0 KB/s"
    public var downloadFormatted: String = "0 KB/s"
    public var totalUploadedFormatted: String = "0 MB"
    public var totalDownloadedFormatted: String = "0 MB"
    public var activeInterface: String = "en0"
    public var localIP: String = "127.0.0.1"
    public var wifiSSID: String = ""
    public var wifiRSSI: Int = 0
    public var wifiTxRate: Double = 0.0

    public init() {}
}

// MARK: - 电池与传感器详细数据结构
public struct BatteryAdvancedInfo {
    public var hasBattery: Bool = true
    public var percentage: Int = 100
    public var isPluggedIn: Bool = false
    public var isCharging: Bool = false
    public var isFullyCharged: Bool = false
    public var isDischarging: Bool = false
    public var isLowPowerMode: Bool = false
    public var wattage: Double = 0.0
    public var healthPercent: Int = 100
    public var cycleCount: Int = 0
    public var temperature: Double = 28.5
    public var voltage: Double = 12.0
    public var amperage: Double = 0.0
    public var fanSpeedRPM: Int = 0
    public var timeRemainingMin: Int? = nil

    public init() {}
}

// MARK: - 样式与语言枚举
public enum MetricDisplayStyle: String, CaseIterable, Identifiable {
    case gauge = "gauge"
    case text = "text"
    public var id: String { rawValue }
}

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zh = "zh"
    case en = "en"
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

// MARK: - 多语言支持
public struct L10n {
    public static func t(_ zh: String, _ en: String) -> String {
        let lang = AppSettings.shared.language
        switch lang {
        case .zh:
            return zh
        case .en:
            return en
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "zh"
            return preferred.contains("zh") ? zh : en
        }
    }
}

// MARK: - 广播通知定义
extension Notification.Name {
    public static let rebuildStatusItems = Notification.Name("rebuildStatusItems")
    public static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
}

// MARK: - 全局设置中心
public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    private var isInitializing = true

    @Published public var showDockIcon: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showDockIcon, forKey: "mm_show_dock")
            DispatchQueue.main.async {
                let policy: NSApplication.ActivationPolicy = self.showDockIcon ? .regular : .accessory
                NSApp.setActivationPolicy(policy)
                if self.showDockIcon {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    @Published public var enableDoubleClickOpenSettings: Bool = true {
        didSet {
            guard !isInitializing else { return }
            if !enableDoubleClickOpenSettings && !enableRightClickOpenSettings {
                enableDoubleClickOpenSettings = true
                return
            }
            UserDefaults.standard.set(enableDoubleClickOpenSettings, forKey: "mm_double_click")
        }
    }

    @Published public var enableRightClickOpenSettings: Bool = true {
        didSet {
            guard !isInitializing else { return }
            if !enableRightClickOpenSettings && !enableDoubleClickOpenSettings {
                enableRightClickOpenSettings = true
                return
            }
            UserDefaults.standard.set(enableRightClickOpenSettings, forKey: "mm_right_click")
        }
    }

    @Published public var allowFullScreenOverlay: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(allowFullScreenOverlay, forKey: "mm_fullscreen_overlay")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    /// 新增：是否仅在主屏幕显示状态栏图标（关闭则在所有显示器上同步显示）
    @Published public var showOnMainScreenOnly: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showOnMainScreenOnly, forKey: "mm_main_screen_only")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(launchAtLogin, forKey: "mm_launch_login")
            if #available(macOS 13.0, *) {
                do {
                    if launchAtLogin {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    }
                } catch {
                    print("SMAppService 切换开机自启失败: \(error)")
                }
            }
        }
    }

    @Published public var showCPU: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showCPU, forKey: "mm_show_cpu")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var showGPU: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showGPU, forKey: "mm_show_gpu")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var showMemory: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showMemory, forKey: "mm_show_memory")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var showDisk: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showDisk, forKey: "mm_show_disk")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var showNetwork: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showNetwork, forKey: "mm_show_net")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var showBattery: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showBattery, forKey: "mm_show_battery")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var displayStyle: MetricDisplayStyle = .gauge {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(displayStyle.rawValue, forKey: "mm_display_style")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var itemSpacing: Double = 4.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(itemSpacing, forKey: "mm_item_spacing")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var widgetOpacity: Double = 0.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(widgetOpacity, forKey: "widget_opacity")
            WidgetConfig.updateOpacityAndReload(widgetOpacity)
        }
    }

    @Published public var refreshInterval: Double = 1.5 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(refreshInterval, forKey: "mm_refresh_interval")
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }

    @Published public var autoLowPowerThrottle: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(autoLowPowerThrottle, forKey: "mm_auto_throttle")
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }

    @Published public var enableHardwareAlerts: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(enableHardwareAlerts, forKey: "mm_hw_alerts")
            if enableHardwareAlerts {
                ThresholdAlertManager.shared.requestAuthorization()
            }
        }
    }

    @Published public var language: AppLanguage = .system {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(language.rawValue, forKey: "mm_language")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published public var itemOrder: [String] = ["cpu", "gpu", "memory", "disk", "network", "battery"]

    private init() {
        let defaults = UserDefaults.standard

        if let savedOrder = defaults.stringArray(forKey: "mm_item_order"), !savedOrder.isEmpty {
            var merged = savedOrder
            for type in StatusItemType.allCases where !merged.contains(type.rawValue) {
                merged.append(type.rawValue)
            }
            itemOrder = merged
        }
        if defaults.object(forKey: "mm_show_dock") != nil {
            showDockIcon = defaults.bool(forKey: "mm_show_dock")
        }
        if defaults.object(forKey: "mm_double_click") != nil {
            enableDoubleClickOpenSettings = defaults.bool(forKey: "mm_double_click")
        }
        if defaults.object(forKey: "mm_right_click") != nil {
            enableRightClickOpenSettings = defaults.bool(forKey: "mm_right_click")
        }
        if defaults.object(forKey: "mm_fullscreen_overlay") != nil {
            allowFullScreenOverlay = defaults.bool(forKey: "mm_fullscreen_overlay")
        }
        if defaults.object(forKey: "mm_main_screen_only") != nil {
            showOnMainScreenOnly = defaults.bool(forKey: "mm_main_screen_only")
        }
        if #available(macOS 13.0, *) {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else if defaults.object(forKey: "mm_launch_login") != nil {
            launchAtLogin = defaults.bool(forKey: "mm_launch_login")
        }
        if defaults.object(forKey: "mm_show_cpu") != nil {
            showCPU = defaults.bool(forKey: "mm_show_cpu")
        }
        if defaults.object(forKey: "mm_show_gpu") != nil {
            showGPU = defaults.bool(forKey: "mm_show_gpu")
        }
        if defaults.object(forKey: "mm_show_memory") != nil {
            showMemory = defaults.bool(forKey: "mm_show_memory")
        }
        if defaults.object(forKey: "mm_show_disk") != nil {
            showDisk = defaults.bool(forKey: "mm_show_disk")
        }
        if defaults.object(forKey: "mm_show_net") != nil {
            showNetwork = defaults.bool(forKey: "mm_show_net")
        }
        if defaults.object(forKey: "mm_show_battery") != nil {
            showBattery = defaults.bool(forKey: "mm_show_battery")
        }
        if let styleRaw = defaults.string(forKey: "mm_display_style"),
           let style = MetricDisplayStyle(rawValue: styleRaw) {
            displayStyle = style
        }
        if defaults.object(forKey: "mm_item_spacing") != nil {
            itemSpacing = defaults.double(forKey: "mm_item_spacing")
        }
        if defaults.object(forKey: "mm_refresh_interval") != nil {
            refreshInterval = max(0.5, defaults.double(forKey: "mm_refresh_interval"))
        }
        if defaults.object(forKey: "mm_auto_throttle") != nil {
            autoLowPowerThrottle = defaults.bool(forKey: "mm_auto_throttle")
        }
        if defaults.object(forKey: "mm_hw_alerts") != nil {
            enableHardwareAlerts = defaults.bool(forKey: "mm_hw_alerts")
        }
        if let langRaw = defaults.string(forKey: "mm_language"),
           let lang = AppLanguage(rawValue: langRaw) {
            language = lang
        }

        if defaults.object(forKey: "widget_opacity") != nil {
            widgetOpacity = defaults.double(forKey: "widget_opacity")
        } else {
            widgetOpacity = WidgetConfig.backgroundOpacity
        }
        WidgetConfig.backgroundOpacity = widgetOpacity

        if !enableDoubleClickOpenSettings && !enableRightClickOpenSettings {
            enableRightClickOpenSettings = true
        }

        isInitializing = false
    }

    public func isItemVisible(type: StatusItemType) -> Bool {
        switch type {
        case .cpu: return showCPU
        case .gpu: return showGPU
        case .memory: return showMemory
        case .disk: return showDisk
        case .network: return showNetwork
        case .battery: return showBattery
        }
    }

    public func setItemVisible(type: StatusItemType, isVisible: Bool) {
        switch type {
        case .cpu: showCPU = isVisible
        case .gpu: showGPU = isVisible
        case .memory: showMemory = isVisible
        case .disk: showDisk = isVisible
        case .network: showNetwork = isVisible
        case .battery: showBattery = isVisible
        }
    }

    public func moveItem(from index: Int, up: Bool) {
        let targetIndex = up ? index - 1 : index + 1
        guard targetIndex >= 0 && targetIndex < itemOrder.count else { return }
        itemOrder.swapAt(index, targetIndex)
        UserDefaults.standard.set(itemOrder, forKey: "mm_item_order")
        NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
    }

    public func updateItemOrder(_ newOrder: [String]) {
        itemOrder = newOrder
        UserDefaults.standard.set(itemOrder, forKey: "mm_item_order")
        NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
    }
}

// MARK: - 智能硬件阈值通知中心
public final class ThresholdAlertManager {
    public static let shared = ThresholdAlertManager()
    private var lastAlertTimes: [String: Date] = [:]
    private var highCPUTicks: Int = 0

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func evaluate(cpu: Double, memory: MemoryDetailInfo, battery: BatteryAdvancedInfo) {
        guard AppSettings.shared.enableHardwareAlerts else { return }

        if cpu >= 90.0 {
            highCPUTicks += 1
            if highCPUTicks >= 5 {
                sendAlert(
                    id: "high_cpu",
                    title: L10n.t("⚠️ CPU 持续高负载", "⚠️ Sustained High CPU Load"),
                    body: L10n.t(String(format: "当前 CPU 占用率已连续超过 %.0f%%，点击状态栏查看高占用进程。", cpu),
                                 String(format: "CPU usage has exceeded %.0f%% continuously.", cpu))
                )
                highCPUTicks = 0
            }
        } else {
            highCPUTicks = 0
        }

        if memory.usagePercent >= 90.0 || memory.pressureLevel >= 2 {
            sendAlert(
                id: "high_memory",
                title: L10n.t("⚠️ 内存空间告急", "⚠️ High Memory Pressure"),
                body: L10n.t(String(format: "内存已使用 %.0f%% (Swap: %@)，建议清理后台高占用应用。", memory.usagePercent, memory.swapFormatted),
                             String(format: "Memory at %.0f%% (Swap: %@).", memory.usagePercent, memory.swapFormatted))
            )
        }

        if battery.hasBattery {
            if battery.isCharging && battery.percentage == 80 {
                sendAlert(
                    id: "battery_80",
                    title: L10n.t("🔋 电池已充至 80%", "🔋 Battery Reached 80%"),
                    body: L10n.t("日常保持 20%~80% 电量有助于延缓锂电池循环寿命衰减。", "Keeping battery between 20%-80% helps extend battery lifespan.")
                )
            } else if !battery.isPluggedIn && battery.percentage <= 15 {
                sendAlert(
                    id: "battery_low",
                    title: L10n.t("🪫 电池电量过低 (\(battery.percentage)%)", "🪫 Low Battery (\(battery.percentage)%)"),
                    body: L10n.t("当前剩余电量不足 15%，请及时连接电源。", "Battery is below 15%, please connect to power.")
                )
            }
        }
    }

    private func sendAlert(id: String, title: String, body: String) {
        let now = Date()
        if let last = lastAlertTimes[id], now.timeIntervalSince(last) < 900 {
            return
        }
        lastAlertTimes[id] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(identifier: "macmonitor.\(id).\(Int(now.timeIntervalSince1970))", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - 真实硬件监控采集引擎
public final class SystemMonitor {
    public static let shared = SystemMonitor()

    private var rawDeviceName: String = "Apple Silicon GPU"
    public var gpuModelName: String {
        let tag = L10n.t("(内建)", "(Internal)")
        return "\(rawDeviceName) \(tag)"
    }

    public private(set) var pCoreCount: Int = 0
    public private(set) var eCoreCount: Int = 0

    private var prevCPUTicks: [processor_cpu_load_info] = []
    private var cpuLock = NSLock()

    private var prevNetBytesIn: UInt64 = 0
    private var prevNetBytesOut: UInt64 = 0
    private var bootNetBytesIn: UInt64 = 0
    private var bootNetBytesOut: UInt64 = 0
    private var prevNetTime: Date?
    private var cachedWiFiTime: Date = .distantPast
    private var cachedSSID: String = ""
    private var cachedRSSI: Int = 0
    private var cachedTxRate: Double = 0.0

    private var prevDiskReadBytes: UInt64 = 0
    private var prevDiskWriteBytes: UInt64 = 0
    private var prevDiskTime: Date?

    private init() {
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            rawDeviceName = defaultDevice.name
        }

        var perf0: Int32 = 0
        var perf1: Int32 = 0
        var s0 = MemoryLayout<Int32>.size
        var s1 = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.logicalcpu", &perf0, &s0, nil, 0) == 0,
           sysctlbyname("hw.perflevel1.logicalcpu", &perf1, &s1, nil, 0) == 0 {
            pCoreCount = Int(perf0)
            eCoreCount = Int(perf1)
        }
    }

    public func getPerCoreCPUUsage() -> [Double] {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)
        guard kr == KERN_SUCCESS, let cpuInfo = cpuInfo else { return [] }

        cpuLock.lock()
        defer {
            let cpuInfoSize = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)
            cpuLock.unlock()
        }

        let numCPUs = Int(numCPUsU)
        var coreUsages: [Double] = []

        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: numCPUs) {
            Array(UnsafeBufferPointer(start: $0, count: numCPUs))
        }

        if prevCPUTicks.count == numCPUs {
            for i in 0..<numCPUs {
                let cur = cpuLoadInfo[i]
                let prev = prevCPUTicks[i]

                let user = Double(cur.cpu_ticks.0 &- prev.cpu_ticks.0)
                let sys = Double(cur.cpu_ticks.1 &- prev.cpu_ticks.1)
                let idle = Double(cur.cpu_ticks.2 &- prev.cpu_ticks.2)
                let nice = Double(cur.cpu_ticks.3 &- prev.cpu_ticks.3)

                let total = user + sys + idle + nice
                let usage = total > 0 ? ((user + sys + nice) / total) * 100.0 : 0.0
                coreUsages.append(min(100.0, max(0.0, usage)))
            }
        } else {
            coreUsages = Array(repeating: 5.0, count: numCPUs)
        }

        prevCPUTicks = cpuLoadInfo
        return coreUsages
    }

    public func getGPUUsage() -> Double {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)

        if result == kIOReturnSuccess {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let perfStats = dict["PerformanceStatistics"] as? [String: Any] {

                    let possibleKeys = ["Device Utilization %", "GPU Activity (%)", "Renderer Utilization %", "Tiler Utilization %"]
                    for key in possibleKeys {
                        if let val = (perfStats[key] as? NSNumber)?.doubleValue {
                            return min(100.0, max(0.0, val))
                        }
                    }
                }
                service = IOIteratorNext(iterator)
            }
        }
        return 0.0
    }

    public func getMemoryDetails() -> MemoryDetailInfo {
        var info = MemoryDetailInfo()
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        info.totalGB = totalBytes / (1024 * 1024 * 1024)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if kr == KERN_SUCCESS {
            let pageSize = Double(vm_kernel_page_size)
            let active = Double(vmStats.active_count) * pageSize
            let wired = Double(vmStats.wire_count) * pageSize
            let compressed = Double(vmStats.compressor_page_count) * pageSize
            let external = Double(vmStats.external_page_count) * pageSize

            let appBytes = max(0, active - external)
            let usedBytes = min(totalBytes, appBytes + wired + compressed)

            let gbDiv = 1024.0 * 1024.0 * 1024.0
            info.appGB = appBytes / gbDiv
            info.wiredGB = wired / gbDiv
            info.compressedGB = compressed / gbDiv
            info.usedGB = usedBytes / gbDiv
            info.freeGB = max(0, info.totalGB - info.usedGB)
            info.usagePercent = min(100.0, max(0.0, (usedBytes / totalBytes) * 100.0))
        }

        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
            info.swapUsedMB = Double(swapUsage.xsu_used) / (1024.0 * 1024.0)
        }

        if info.usagePercent >= 88.0 || info.swapUsedMB >= 8192 {
            info.pressureLevel = 2
        } else if info.usagePercent >= 75.0 || info.swapUsedMB >= 2048 {
            info.pressureLevel = 1
        } else {
            info.pressureLevel = 0
        }

        return info
    }

    public func getDiskDetails() -> DiskDetailInfo {
        var info = DiskDetailInfo()
        let gbDiv = 1024.0 * 1024.0 * 1024.0

        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? NSNumber)?.doubleValue ?? (512.0 * gbDiv)
            let free = (attrs[.systemFreeSize] as? NSNumber)?.doubleValue ?? (256.0 * gbDiv)
            let used = max(0, total - free)
            info.totalGB = total / gbDiv
            info.freeGB = free / gbDiv
            info.usedGB = used / gbDiv
            info.usagePercent = total > 0 ? min(100.0, max(0.0, (used / total) * 100.0)) : 0.0
        }

        var iterator: io_iterator_t = 0
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == kIOReturnSuccess {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let stats = dict["Statistics"] as? [String: Any] {
                    if let r = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value {
                        totalRead += r
                    }
                    if let w = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value {
                        totalWrite += w
                    }
                }
                service = IOIteratorNext(iterator)
            }
        }

        let now = Date()
        if let lastTime = prevDiskTime {
            let dt = max(0.5, now.timeIntervalSince(lastTime))
            let rSpeed = Double(totalRead >= prevDiskReadBytes ? totalRead - prevDiskReadBytes : 0) / dt
            let wSpeed = Double(totalWrite >= prevDiskWriteBytes ? totalWrite - prevDiskWriteBytes : 0) / dt
            info.readBytesPerSec = rSpeed
            info.writeBytesPerSec = wSpeed
            info.readFormatted = formatSpeed(rSpeed)
            info.writeFormatted = formatSpeed(wSpeed)
        }
        prevDiskReadBytes = totalRead
        prevDiskWriteBytes = totalWrite
        prevDiskTime = now

        return info
    }

    public func getNetworkSpeed() -> NetworkSpeedInfo {
        var info = NetworkSpeedInfo()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return info
        }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0
        var activeName = "en0"
        var localIPv4 = "127.0.0.1"

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = cursor {
            let flags = Int32(ptr.pointee.ifa_flags)
            let name = String(cString: ptr.pointee.ifa_name)

            if (flags & (IFF_UP | IFF_RUNNING)) != 0 && (flags & IFF_LOOPBACK) == 0,
               let addr = ptr.pointee.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_LINK), let data = ptr.pointee.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self)
                    totalBytesIn += UInt64(ifData.pointee.ifi_ibytes)
                    totalBytesOut += UInt64(ifData.pointee.ifi_obytes)
                } else if family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254") {
                            localIPv4 = ip
                            activeName = name
                        }
                    }
                }
            }
            cursor = ptr.pointee.ifa_next
        }

        let now = Date()
        if let lastTime = prevNetTime {
            let timeDelta = max(0.5, now.timeIntervalSince(lastTime))
            let uploadBytes = Double(totalBytesOut >= prevNetBytesOut ? totalBytesOut - prevNetBytesOut : 0) / timeDelta
            let downloadBytes = Double(totalBytesIn >= prevNetBytesIn ? totalBytesIn - prevNetBytesIn : 0) / timeDelta

            info.uploadSpeed = uploadBytes
            info.downloadSpeed = downloadBytes
            info.uploadFormatted = formatSpeed(uploadBytes)
            info.downloadFormatted = formatSpeed(downloadBytes)
        } else {
            bootNetBytesIn = totalBytesIn
            bootNetBytesOut = totalBytesOut
        }

        prevNetBytesIn = totalBytesIn
        prevNetBytesOut = totalBytesOut
        prevNetTime = now

        let sessionUp = totalBytesOut >= bootNetBytesOut ? totalBytesOut - bootNetBytesOut : totalBytesOut
        let sessionDown = totalBytesIn >= bootNetBytesIn ? totalBytesIn - bootNetBytesIn : totalBytesIn
        info.totalUploadedFormatted = formatTotalBytes(sessionUp)
        info.totalDownloadedFormatted = formatTotalBytes(sessionDown)
        info.activeInterface = activeName
        info.localIP = localIPv4

        if now.timeIntervalSince(cachedWiFiTime) >= 6.0 {
            cachedWiFiTime = now
            if let iface = CWWiFiClient.shared().interface() {
                cachedSSID = iface.ssid() ?? "Wi-Fi"
                cachedRSSI = iface.rssiValue()
                cachedTxRate = iface.transmitRate()
            }
        }
        info.wifiSSID = cachedSSID
        info.wifiRSSI = cachedRSSI
        info.wifiTxRate = cachedTxRate

        return info
    }

    public func getTopProcesses(limit: Int = 5) -> [ProcessMetricItem] {
        let apps = NSWorkspace.shared.runningApplications
        var items: [ProcessMetricItem] = []

        for app in apps {
            let pid = app.processIdentifier
            guard pid > 0, let name = app.localizedName, !name.isEmpty else { continue }

            var rusage = rusage_info_v4()
            let kr = withUnsafeMutablePointer(to: &rusage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { ptr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, ptr)
                }
            }

            if kr == 0 {
                let footprint = rusage.ri_phys_footprint
                if footprint > 20 * 1024 * 1024 {
                    let mb = Double(footprint) / (1024.0 * 1024.0)
                    let str = mb >= 1024.0 ? String(format: "%.2f GB", mb / 1024.0) : String(format: "%.0f MB", mb)
                    items.append(ProcessMetricItem(
                        id: pid,
                        name: name,
                        icon: app.icon,
                        memoryBytes: footprint,
                        formattedValue: str
                    ))
                }
            }
        }

        items.sort { $0.memoryBytes > $1.memoryBytes }
        return Array(items.prefix(limit))
    }

    public func getBatteryDetails() -> BatteryAdvancedInfo {
        var info = BatteryAdvancedInfo()
        info.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        var foundBattery = false

        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    foundBattery = true
                    let currentCap = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 100
                    let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
                    info.percentage = maxCap > 0 ? Int((Double(currentCap) / Double(maxCap)) * 100) : 100
                    let state = desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
                    let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
                    info.isPluggedIn = (state == kIOPSACPowerValue) || isCharging
                    info.isCharging = isCharging
                    info.isFullyCharged = (desc[kIOPSIsChargedKey as String] as? Bool) ?? (info.percentage >= 100)
                    break
                }
            }
        }

        info.hasBattery = foundBattery
        if !foundBattery {
            info.isPluggedIn = true
            info.isFullyCharged = true
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any] {

                info.cycleCount = dict["CycleCount"] as? Int ?? 0

                let designCap = dict["DesignCapacity"] as? Int ?? 0
                let nomCap = dict["NominalChargeCapacity"] as? Int ?? 0
                let rawMaxCap = dict["AppleRawMaxCapacity"] as? Int ?? 0
                let realFullCap = nomCap > 0 ? nomCap : (rawMaxCap > 0 ? rawMaxCap : 0)

                if designCap > 0 && realFullCap > 0 {
                    info.healthPercent = min(100, max(1, Int(round((Double(realFullCap) / Double(designCap)) * 100.0))))
                } else if let maxCap = dict["MaxCapacity"] as? Int, maxCap > 0 && maxCap <= 100 {
                    info.healthPercent = maxCap
                }

                if let rawTemp = dict["Temperature"] as? Double {
                    info.temperature = max(10.0, min(80.0, rawTemp / 100.0))
                }

                let rawVoltage = dict["Voltage"] as? Double ?? 12000.0
                let signedAmperage = dict["Amperage"] as? Double ?? 0.0

                info.voltage = max(0.0, rawVoltage / 1000.0)
                info.amperage = abs(signedAmperage)

                let isExternalConnected = (dict["ExternalConnected"] as? Bool) ?? info.isPluggedIn
                let isIsCharging = (dict["IsCharging"] as? Bool) ?? info.isCharging
                let isBatteryFullyCharged = (dict["FullyCharged"] as? Bool) ?? info.isFullyCharged

                info.isPluggedIn = isExternalConnected
                info.isCharging = isIsCharging
                info.isFullyCharged = isBatteryFullyCharged

                if !isExternalConnected {
                    info.isDischarging = true
                    info.wattage = (rawVoltage * abs(signedAmperage)) / 1_000_000.0
                } else {
                    if isIsCharging && signedAmperage > 0 {
                        info.isDischarging = false
                        info.wattage = (rawVoltage * signedAmperage) / 1_000_000.0
                    } else if isBatteryFullyCharged || abs(signedAmperage) < 50 {
                        info.isDischarging = false
                        info.wattage = 0.0
                        info.amperage = 0.0
                    } else if signedAmperage < 0 {
                        info.isDischarging = true
                        info.wattage = (rawVoltage * abs(signedAmperage)) / 1_000_000.0
                    } else {
                        info.isDischarging = false
                        info.wattage = 0.0
                    }
                }
            }
        }

        return info
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.0f KB/s", max(0, bytesPerSec / 1024))
        }
    }

    private func formatTotalBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.0f MB", mb)
        }
    }
}
