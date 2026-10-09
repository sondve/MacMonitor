import Foundation
import Combine
import SwiftUI
import AppKit
import ServiceManagement
import IOKit
import IOKit.ps
import Darwin
import Metal
import WidgetKit

// MARK: - 状态栏重构通知定义
extension Notification.Name {
    static let rebuildStatusItems = Notification.Name("MacMonitorRebuildStatusItems")
}

// MARK: - 多语言支持定义
enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

// MARK: - 轻量本地化词典助手
struct L10n {
    static func t(_ zh: String, _ en: String) -> String {
        return AppSettings.shared.language == .en ? en : zh
    }
}

// MARK: - 显示模式枚举
enum MetricDisplayStyle: Int {
    case gauge = 1   // 放大版圆环仪表盘模式 (CPU ⭕)
    case text = 0    // 字母+数字模式 (CPU: 24%)
}

// MARK: - 可排序状态栏标识
enum StatusItemType: String, CaseIterable, Identifiable {
    case network = "network"
    case cpu = "cpu"
    case gpu = "gpu"
    case battery = "battery"

    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .network: return L10n.t("实时网速", "Network Speed")
        case .cpu: return L10n.t("CPU 处理器", "CPU Processor")
        case .gpu: return L10n.t("GPU 核心", "GPU Core")
        case .battery: return L10n.t("电池状态", "Battery Status")
        }
    }

    var description: String {
        switch self {
        case .network: return L10n.t("显示实时上行与下行吞吐带宽", "Monitor real-time upload and download throughput")
        case .cpu: return L10n.t("监控多核活动与综合占用负荷", "Track per-core activity and overall processor load")
        case .gpu: return L10n.t("Metal 渲染与图形核心瞬时负荷", "Metal rendering and graphics core utilization")
        case .battery: return L10n.t("电量百分比、真彩流转与充电状态", "Battery level, dynamic color filling, and charging status")
        }
    }

    var iconName: String {
        switch self {
        case .network: return "arrow.up.arrow.down.circle.fill"
        case .cpu: return "cpu.fill"
        case .gpu: return "square.stack.3d.up.fill"
        case .battery: return "battery.100.bolt"
        }
    }

    var themeColor: Color {
        switch self {
        case .network: return .blue
        case .cpu: return .orange
        case .gpu: return Color(red: 0.0, green: 0.48, blue: 1.0)  // GPU 统一为纯蓝色
        case .battery: return .green
        }
    }
}

// MARK: - 用户偏好配置
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let suiteName = "group.com.local.macmonitor"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published var itemSpacing: Double {
        didSet {
            UserDefaults.standard.set(itemSpacing, forKey: "itemSpacing")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published var widgetOpacity: Double {
        didSet {
            UserDefaults.standard.set(widgetOpacity, forKey: "widgetOpacity")
            if let sharedDefaults = UserDefaults(suiteName: suiteName) {
                sharedDefaults.set(widgetOpacity, forKey: "widget_opacity")
                sharedDefaults.synchronize()
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
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
                    print("开机自启注册失败: \(error)")
                }
            }
        }
    }

    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
            DispatchQueue.main.async {
                let policy: NSApplication.ActivationPolicy = self.showDockIcon ? .regular : .accessory
                NSApp.setActivationPolicy(policy)
                if self.showDockIcon {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    @Published var allowFullScreenOverlay: Bool {
        didSet { UserDefaults.standard.set(allowFullScreenOverlay, forKey: "allowFullScreenOverlay") }
    }

    @Published var showCPU: Bool {
        didSet {
            UserDefaults.standard.set(showCPU, forKey: "showCPU")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }
    @Published var showGPU: Bool {
        didSet {
            UserDefaults.standard.set(showGPU, forKey: "showGPU")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }
    @Published var showNetwork: Bool {
        didSet {
            UserDefaults.standard.set(showNetwork, forKey: "showNetwork")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }
    @Published var showBattery: Bool {
        didSet {
            UserDefaults.standard.set(showBattery, forKey: "showBattery")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published var displayStyle: MetricDisplayStyle {
        didSet {
            UserDefaults.standard.set(displayStyle.rawValue, forKey: "displayStyle")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published var itemOrder: [String] {
        didSet {
            UserDefaults.standard.set(itemOrder, forKey: "itemOrder")
            NotificationCenter.default.post(name: .rebuildStatusItems, object: nil)
        }
    }

    @Published var enableDoubleClickOpenSettings: Bool {
        didSet {
            if !enableDoubleClickOpenSettings && !enableRightClickOpenSettings {
                enableDoubleClickOpenSettings = true
                return
            }
            UserDefaults.standard.set(enableDoubleClickOpenSettings, forKey: "enableDoubleClickOpenSettings")
        }
    }

    @Published var enableRightClickOpenSettings: Bool {
        didSet {
            if !enableRightClickOpenSettings && !enableDoubleClickOpenSettings {
                enableRightClickOpenSettings = true
                return
            }
            UserDefaults.standard.set(enableRightClickOpenSettings, forKey: "enableRightClickOpenSettings")
        }
    }

    init() {
        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
        self.language = AppLanguage(rawValue: langRaw) ?? .zh

        self.itemSpacing = UserDefaults.standard.object(forKey: "itemSpacing") as? Double ?? 10.0

        let savedOpacity = UserDefaults.standard.object(forKey: "widgetOpacity") as? Double
        let defaultOpacity = savedOpacity ?? 0.65
        self.widgetOpacity = defaultOpacity

        if let sharedDefaults = UserDefaults(suiteName: "group.com.local.macmonitor") {
            if sharedDefaults.object(forKey: "widget_opacity") == nil {
                sharedDefaults.set(defaultOpacity, forKey: "widget_opacity")
            }
        }

        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            self.launchAtLogin = false
        }

        self.showDockIcon = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? false
        self.allowFullScreenOverlay = UserDefaults.standard.object(forKey: "allowFullScreenOverlay") as? Bool ?? true
        self.showCPU = UserDefaults.standard.object(forKey: "showCPU") as? Bool ?? true
        self.showGPU = UserDefaults.standard.object(forKey: "showGPU") as? Bool ?? true
        self.showNetwork = UserDefaults.standard.object(forKey: "showNetwork") as? Bool ?? true
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? true

        let styleVal = UserDefaults.standard.integer(forKey: "displayStyle")
        self.displayStyle = MetricDisplayStyle(rawValue: styleVal) ?? .gauge

        let defaultOrder = [
            StatusItemType.network.rawValue,
            StatusItemType.cpu.rawValue,
            StatusItemType.gpu.rawValue,
            StatusItemType.battery.rawValue
        ]
        self.itemOrder = UserDefaults.standard.stringArray(forKey: "itemOrder") ?? defaultOrder

        self.enableDoubleClickOpenSettings = UserDefaults.standard.object(forKey: "enableDoubleClickOpenSettings") as? Bool ?? true
        self.enableRightClickOpenSettings = UserDefaults.standard.object(forKey: "enableRightClickOpenSettings") as? Bool ?? true
    }

    func moveItem(from index: Int, up: Bool) {
        let targetIndex = up ? index - 1 : index + 1
        guard targetIndex >= 0 && targetIndex < itemOrder.count else { return }
        itemOrder.swapAt(index, targetIndex)
    }

    func isItemVisible(type: StatusItemType) -> Bool {
        switch type {
        case .network: return showNetwork
        case .cpu: return showCPU
        case .gpu: return showGPU
        case .battery: return showBattery
        }
    }

    func setItemVisible(type: StatusItemType, isVisible: Bool) {
        switch type {
        case .network: showNetwork = isVisible
        case .cpu: showCPU = isVisible
        case .gpu: showGPU = isVisible
        case .battery: showBattery = isVisible
        }
    }
}

// MARK: - 硬件数据模型
struct BatteryAdvancedInfo {
    var percentage: Int = 100
    var isPluggedIn: Bool = false
    var isCharging: Bool = false
    var isFullyCharged: Bool = false
    var isLowPowerMode: Bool = false
    var cycleCount: Int = 0
    var healthPercent: Int = 100
    var temperature: Double = 28.0
    var wattage: Double = 0.0
    var voltage: Double = 0.0
    var amperage: Double = 0.0
    var isDischarging: Bool = false
}

struct NetworkSpeedInfo {
    var uploadSpeed: Double = 0.0
    var downloadSpeed: Double = 0.0

    var uploadFormatted: String { NetworkSpeedInfo.formatSpeed(uploadSpeed) }
    var downloadFormatted: String { NetworkSpeedInfo.formatSpeed(downloadSpeed) }

    static func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f M/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.0f K/s", max(0, bytesPerSec / 1024))
        }
    }
}

// MARK: - 系统硬件监控引擎
final class SystemMonitor {
    static let shared = SystemMonitor()
    private let suiteName = "group.com.local.macmonitor"
    private var userDefaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    private var prevCPUTicks: [processor_cpu_load_info] = []
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var lastNetworkSampleTime: Date = Date()

    var gpuModelName: String {
        let tag = L10n.t("(内建)", "(Internal)")
        if let device = MTLCreateSystemDefaultDevice() {
            return "\(device.name) \(tag)"
        }
        return "Apple Silicon \(tag)"
    }

    func getPerCoreCPUUsage() -> [Double] {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)
        guard kr == KERN_SUCCESS, let cpuInfo = cpuInfo else { return [] }

        let numCPUs = Int(numCPUsU)
        var coreUsages: [Double] = []

        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: numCPUs) {
            Array(UnsafeBufferPointer(start: $0, count: numCPUs))
        }

        if prevCPUTicks.count == numCPUs {
            for i in 0..<numCPUs {
                let cur = cpuLoadInfo[i]
                let prev = prevCPUTicks[i]

                let user = Double(cur.cpu_ticks.0 - prev.cpu_ticks.0)
                let sys = Double(cur.cpu_ticks.1 - prev.cpu_ticks.1)
                let idle = Double(cur.cpu_ticks.2 - prev.cpu_ticks.2)
                let nice = Double(cur.cpu_ticks.3 - prev.cpu_ticks.3)

                let total = user + sys + idle + nice
                let usage = total > 0 ? ((user + sys + nice) / total) * 100.0 : 0.0
                coreUsages.append(min(100.0, max(0.0, usage)))
            }
        } else {
            coreUsages = Array(repeating: 5.0, count: numCPUs)
        }

        prevCPUTicks = cpuLoadInfo
        let cpuInfoSize = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)

        return coreUsages
    }

    func getGPUUsage() -> Double {
        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("IOAccelerator")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator)
        guard kr == KERN_SUCCESS else { return 0.0 }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = stats["Device Utilization %"] as? Double {
                    return util
                } else if let intUtil = stats["Device Utilization %"] as? Int {
                    return Double(intUtil)
                }
            }
        }
        return 0.0
    }

    func getBatteryDetails() -> BatteryAdvancedInfo {
        var info = BatteryAdvancedInfo()
        info.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for item in list {
                if let desc = IOPSGetPowerSourceDescription(blob, item)?.takeUnretainedValue() as? [String: Any] {
                    info.percentage = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                    let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
                    let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                    info.isPluggedIn = (state == kIOPSACPowerValue) || isCharging
                    info.isCharging = isCharging
                    info.isFullyCharged = (desc[kIOPSIsChargedKey] as? Bool) ?? (info.percentage >= 100)
                }
            }
        }

        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("AppleSmartBattery")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator)
        if kr == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            let entry = IOIteratorNext(iterator)
            if entry != 0 {
                defer { IOObjectRelease(entry) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    info.cycleCount = dict["CycleCount"] as? Int ?? 0

                    let designCap = dict["DesignCapacity"] as? Int ?? 0
                    let nomCap = dict["NominalChargeCapacity"] as? Int ?? 0
                    let rawMaxCap = dict["AppleRawMaxCapacity"] as? Int ?? 0
                    let realFullCap = nomCap > 0 ? nomCap : (rawMaxCap > 0 ? rawMaxCap : 0)

                    if designCap > 0 && realFullCap > 0 {
                        info.healthPercent = min(100, Int((Double(realFullCap) / Double(designCap)) * 100.0))
                    } else if let maxCap = dict["MaxCapacity"] as? Int, maxCap > 0 && maxCap <= 100 {
                        info.healthPercent = maxCap
                    } else {
                        info.healthPercent = 100
                    }

                    if let rawTemp = dict["Temperature"] as? Double {
                        info.temperature = max(10.0, min(80.0, rawTemp / 100.0))
                    }

                    let rawVoltage = dict["Voltage"] as? Double ?? 0.0
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
        }
        return info
    }

    func getNetworkSpeed() -> NetworkSpeedInfo {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return NetworkSpeedInfo()
        }
        defer { freeifaddrs(ifaddr) }

        var currentBytesIn: UInt64 = 0
        var currentBytesOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = cursor {
            let flags = Int32(ptr.pointee.ifa_flags)
            if (flags & (IFF_UP | IFF_RUNNING)) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = ptr.pointee.ifa_data {
                        let netData = data.assumingMemoryBound(to: if_data.self)
                        currentBytesIn += UInt64(netData.pointee.ifi_ibytes)
                        currentBytesOut += UInt64(netData.pointee.ifi_obytes)
                    }
                }
            }
            cursor = ptr.pointee.ifa_next
        }

        let now = Date()
        let interval = max(0.5, now.timeIntervalSince(lastNetworkSampleTime))
        lastNetworkSampleTime = now

        var upSpeed: Double = 0
        var downSpeed: Double = 0
        if prevBytesIn > 0 && currentBytesIn >= prevBytesIn {
            downSpeed = Double(currentBytesIn - prevBytesIn) / interval
        }
        if prevBytesOut > 0 && currentBytesOut >= prevBytesOut {
            upSpeed = Double(currentBytesOut - prevBytesOut) / interval
        }

        prevBytesIn = currentBytesIn
        prevBytesOut = currentBytesOut

        return NetworkSpeedInfo(uploadSpeed: upSpeed, downloadSpeed: downSpeed)
    }

    func appendGPUHistory(val: Double) {
        var history = userDefaults?.array(forKey: "gpu_history") as? [Double] ?? []
        history.append(val)
        if history.count > 50 { history.removeFirst() }
        userDefaults?.set(history, forKey: "gpu_history")
    }

    func loadGPUHistory() -> [Double] {
        return userDefaults?.array(forKey: "gpu_history") as? [Double] ?? []
    }
}
