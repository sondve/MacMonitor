import SwiftUI
import AppKit
import WidgetKit
import CoreGraphics

@main
struct MacMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsDashboardView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var containerView: UnifiedBarContainerView!
    var popover: NSPopover?
    var timer: Timer?
    private var currentActiveInterval: TimeInterval = 1.5

    var currentShowingType: StatusItemType?

    // 硬件指标缓存
    var currentCores: [Double] = []
    var currentGPU: Double = 0
    var currentMemory = MemoryDetailInfo()
    var currentDisk = DiskDetailInfo()
    var currentNet = NetworkSpeedInfo()
    var currentBattery = BatteryAdvancedInfo()
    var gpuHistory: [Double] = []
    var currentTopProcesses: [ProcessMetricItem] = []

    // 小组件刷新节流计数器
    private var widgetRefreshTick: Int = 0

    // MARK: - 全屏检测引擎
    private func isSystemInFullScreen(for targetScreen: NSScreen?) -> Bool {
        guard let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            return false
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let notchHeight = screen.safeAreaInsets.top
            let screenWidth = screen.frame.width
            let screenHeight = screen.frame.height
            let contentHeightUnderNotch = screenHeight - notchHeight

            for info in windowList {
                if let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == myPID {
                    continue
                }

                guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                    continue
                }

                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                    continue
                }

                let isWidthMatch = abs(rect.width - screenWidth) <= 5
                let isHeightMatch = abs(rect.height - screenHeight) <= 5 || abs(rect.height - contentHeightUnderNotch) <= 5

                if isWidthMatch && isHeightMatch {
                    return true
                }
            }
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        if AppSettings.shared.enableHardwareAlerts {
            ThresholdAlertManager.shared.requestAuthorization()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        containerView = UnifiedBarContainerView()

        containerView.onItemClick = { [weak self] type, targetView in
            self?.handleClick(type: type, sender: targetView)
        }

        containerView.onDoubleClick = { [weak self] in
            if AppSettings.shared.enableDoubleClickOpenSettings {
                self?.closePopover()
                SettingsWindowManager.shared.open()
            }
        }

        containerView.onRightClick = { [weak self] targetView in
            self?.handleRightClick(sender: targetView)
        }

        if let button = statusItem.button {
            button.title = ""
            button.addSubview(containerView)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRebuildNotification),
            name: .rebuildStatusItems,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRefreshIntervalChanged),
            name: .refreshIntervalChanged,
            object: nil
        )

        let hasLaunchedKey = "mm_has_launched_before"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            SettingsWindowManager.shared.open()
        }

        refresh()
        rescheduleTimer()
    }

    private func effectiveInterval() -> TimeInterval {
        let base = max(0.5, AppSettings.shared.refreshInterval)
        if AppSettings.shared.autoLowPowerThrottle && (!currentBattery.isPluggedIn || currentBattery.isLowPowerMode) {
            return max(base, 3.0)
        }
        return base
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        let target = effectiveInterval()
        currentActiveInterval = target
        let newTimer = Timer(timeInterval: target, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    @objc func onRefreshIntervalChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.rescheduleTimer()
        }
    }

    @objc func onRebuildNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBarUI()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.open()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func closePopover() {
        if let currentPopover = popover {
            currentPopover.delegate = nil
            currentPopover.animates = false
            currentPopover.close()
            self.popover = nil
            self.currentShowingType = nil
        }
    }

    func handleClick(type: StatusItemType, sender: NSView) {
        if let currentPopover = popover, currentPopover.isShown && currentShowingType == type {
            closePopover()
            return
        }

        let isFullScreen = isSystemInFullScreen(for: sender.window?.screen)
        if !AppSettings.shared.allowFullScreenOverlay && isFullScreen {
            currentShowingType = nil
            return
        }

        if type == .cpu || type == .memory {
            currentTopProcesses = SystemMonitor.shared.getTopProcesses(limit: 5)
        }

        currentShowingType = type
        showOrUpdatePopover(for: type, positioningView: sender)
    }

    private func showOrUpdatePopover(for type: StatusItemType, positioningView: NSView? = nil) {
        switch type {
        case .cpu:
            let view = CPUDetailView(coreUsages: currentCores, topProcesses: currentTopProcesses)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<CPUDetailView> {
                host.rootView = view
            }
        case .gpu:
            let view = GPUHistoryDotMatrixWindowView(history: gpuHistory, modelName: SystemMonitor.shared.gpuModelName)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<GPUHistoryDotMatrixWindowView> {
                host.rootView = view
            }
        case .memory:
            let view = MemoryDetailView(mem: currentMemory, topProcesses: currentTopProcesses)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<MemoryDetailView> {
                host.rootView = view
            }
        case .disk:
            let view = DiskDetailView(disk: currentDisk)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<DiskDetailView> {
                host.rootView = view
            }
        case .network:
            let view = NetworkDetailView(net: currentNet)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<NetworkDetailView> {
                host.rootView = view
            }
        case .battery:
            let view = BatteryDetailView(battery: currentBattery)
            if let posView = positioningView {
                showPopover(content: view, positioningView: posView)
            } else if let host = popover?.contentViewController as? NSHostingController<BatteryDetailView> {
                host.rootView = view
            }
        }
    }

    func handleRightClick(sender: NSView) {
        let menu = NSMenu()
        if AppSettings.shared.enableRightClickOpenSettings {
            menu.addItem(NSMenuItem(title: L10n.t("打开控制面板...", "Open Settings..."), action: #selector(openPreferences), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(NSMenuItem(title: L10n.t("退出 MacMonitor", "Quit MacMonitor"), action: #selector(quitApp), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
    }

    @objc func openPreferences() {
        SettingsWindowManager.shared.open()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showPopover<V: View>(content: V, positioningView: NSView) {
        closePopover()

        let allowOverlay = AppSettings.shared.allowFullScreenOverlay
        let isFullScreen = isSystemInFullScreen(for: positioningView.window?.screen)

        if !allowOverlay && isFullScreen {
            currentShowingType = nil
            return
        }

        if allowOverlay {
            NSApp.activate(ignoringOtherApps: true)
        }

        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.animates = true
        newPopover.delegate = self
        self.popover = newPopover

        let controller = NSHostingController(rootView: content)
        let fittingSize = controller.view.fittingSize
        controller.preferredContentSize = fittingSize
        newPopover.contentSize = fittingSize
        newPopover.contentViewController = controller

        newPopover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)

        if let window = newPopover.contentViewController?.view.window {
            if allowOverlay {
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.level = .statusBar
                window.makeKeyAndOrderFront(nil)
            } else {
                window.collectionBehavior = []
                window.level = .normal
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        currentShowingType = nil
        popover = nil
    }

    func refresh() {
        // 1. 采集全维度硬件数据
        currentCores = SystemMonitor.shared.getPerCoreCPUUsage()
        let avgCPU = currentCores.isEmpty ? 0.0 : currentCores.reduce(0, +) / Double(currentCores.count)

        currentGPU = SystemMonitor.shared.getGPUUsage()
        gpuHistory.append(currentGPU)
        if gpuHistory.count > 50 { gpuHistory.removeFirst() }

        currentMemory = SystemMonitor.shared.getMemoryDetails()
        currentDisk = SystemMonitor.shared.getDiskDetails()
        currentNet = SystemMonitor.shared.getNetworkSpeed()
        currentBattery = SystemMonitor.shared.getBatteryDetails()

        if abs(effectiveInterval() - currentActiveInterval) > 0.1 {
            rescheduleTimer()
        }

        ThresholdAlertManager.shared.evaluate(cpu: avgCPU, memory: currentMemory, battery: currentBattery)

        // 2. 通过无权限拦截的 JSON 管道同步给桌面小组件
        var payload = SharedMonitorPayload()
        payload.opacity = AppSettings.shared.widgetOpacity
        payload.cpuUsage = avgCPU
        payload.cpuCores = currentCores
        payload.gpuUsage = currentGPU
        payload.gpuHistory = gpuHistory
        payload.memUsage = currentMemory.usagePercent
        payload.memUsedStr = currentMemory.usedFormatted
        payload.memSwapStr = currentMemory.swapFormatted
        payload.diskUsage = currentDisk.usagePercent
        payload.diskFreeStr = String(format: "%.0f GB", currentDisk.freeGB)
        payload.diskReadStr = currentDisk.readFormatted
        payload.diskWriteStr = currentDisk.writeFormatted
        payload.netUpload = currentNet.uploadSpeed
        payload.netDownload = currentNet.downloadSpeed
        payload.netUploadStr = currentNet.uploadFormatted
        payload.netDownloadStr = currentNet.downloadFormatted
        payload.netLocalIP = currentNet.localIP
        payload.batteryPercent = currentBattery.percentage
        payload.batteryPlugged = currentBattery.isPluggedIn
        payload.batteryWattage = currentBattery.wattage
        payload.batteryTemp = currentBattery.temperature
        WidgetConfig.savePayload(payload)

        // 3. 节流刷新桌面小组件：每 8 次采样通知一次 WidgetKit
        widgetRefreshTick += 1
        if widgetRefreshTick % 8 == 0 {
            WidgetCenter.shared.reloadAllTimelines()
        }

        // 4. 更新状态栏与已打开的实时弹窗
        updateStatusBarUI()
        if let activeType = currentShowingType, let pop = popover, pop.isShown {
            if activeType == .cpu || activeType == .memory {
                currentTopProcesses = SystemMonitor.shared.getTopProcesses(limit: 5)
            }
            showOrUpdatePopover(for: activeType)
        }
    }

    private func updateStatusBarUI() {
        let avgCPU = currentCores.isEmpty ? 0.0 : currentCores.reduce(0, +) / Double(currentCores.count)
        containerView.update(
            cpuUsage: avgCPU,
            gpuUsage: currentGPU,
            memUsage: currentMemory.usagePercent,
            diskUsage: currentDisk.usagePercent,
            net: currentNet,
            battery: currentBattery,
            settings: AppSettings.shared
        )
        statusItem.length = containerView.frame.width
    }
}

// MARK: - 统一状态栏无缝容器 (支持 6 大模块)
class UnifiedBarContainerView: NSView {
    var onItemClick: ((StatusItemType, NSView) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSView) -> Void)?

    private var subviewsMap: [StatusItemType: NSView] = [:]
    private var netHosting: NSHostingView<AnyView>?
    private var cpuHosting: NSHostingView<AnyView>?
    private var gpuHosting: NSHostingView<AnyView>?
    private var memHosting: NSHostingView<AnyView>?
    private var diskHosting: NSHostingView<AnyView>?
    private var batteryView: ClickableBatteryView?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    private func setupViews() {
        let bView = ClickableBatteryView(frame: NSRect(x: 0, y: 0, width: 23, height: 22))
        batteryView = bView
        subviewsMap[.battery] = bView
        addSubview(bView)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 && AppSettings.shared.enableDoubleClickOpenSettings {
            onDoubleClick?()
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        for (type, view) in subviewsMap where !view.isHidden {
            if view.frame.contains(loc) {
                onItemClick?(type, view)
                return
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for (_, view) in subviewsMap where !view.isHidden {
            if view.frame.contains(loc) {
                onRightClick?(view)
                return
            }
        }
        onRightClick?(self)
    }

    func update(
        cpuUsage: Double,
        gpuUsage: Double,
        memUsage: Double,
        diskUsage: Double,
        net: NetworkSpeedInfo,
        battery: BatteryAdvancedInfo,
        settings: AppSettings
    ) {
        if settings.showNetwork {
            let netView = AnyView(VerticalNetworkSpeedView(net: net).allowsHitTesting(false))
            if let host = netHosting {
                host.rootView = netView
            } else {
                let host = NSHostingView(rootView: netView)
                netHosting = host
                subviewsMap[.network] = host
                addSubview(host)
            }
            netHosting?.isHidden = false
        } else {
            netHosting?.isHidden = true
        }

        updateMetricHost(
            isVisible: settings.showCPU,
            label: "CPU",
            value: cpuUsage,
            style: settings.displayStyle,
            type: .cpu,
            hosting: &cpuHosting
        )

        updateMetricHost(
            isVisible: settings.showGPU,
            label: "GPU",
            value: gpuUsage,
            style: settings.displayStyle,
            type: .gpu,
            hosting: &gpuHosting
        )

        updateMetricHost(
            isVisible: settings.showMemory,
            label: "MEM",
            value: memUsage,
            style: settings.displayStyle,
            type: .memory,
            hosting: &memHosting
        )

        updateMetricHost(
            isVisible: settings.showDisk,
            label: "DSK",
            value: diskUsage,
            style: settings.displayStyle,
            type: .disk,
            hosting: &diskHosting
        )

        if settings.showBattery {
            batteryView?.update(
                percentage: battery.percentage,
                isPluggedIn: battery.isPluggedIn,
                isLowPower: battery.isLowPowerMode
            )
            batteryView?.isHidden = false
        } else {
            batteryView?.isHidden = true
        }

        layoutModules(order: settings.itemOrder, spacing: CGFloat(settings.itemSpacing))
    }

    private func updateMetricHost(
        isVisible: Bool,
        label: String,
        value: Double,
        style: MetricDisplayStyle,
        type: StatusItemType,
        hosting: inout NSHostingView<AnyView>?
    ) {
        if isVisible {
            let view: AnyView = (style == .gauge)
                ? AnyView(HorizontalRingGaugeView(label: label, value: value).allowsHitTesting(false))
                : AnyView(TextMetricView(label: label, value: value).allowsHitTesting(false))
            if let host = hosting {
                host.rootView = view
            } else {
                let host = NSHostingView(rootView: view)
                hosting = host
                subviewsMap[type] = host
                addSubview(host)
            }
            hosting?.isHidden = false
        } else {
            hosting?.isHidden = true
        }
    }

    private func layoutModules(order: [String], spacing: CGFloat) {
        var currentX: CGFloat = 0
        var activeCount = 0

        for key in order {
            guard let type = StatusItemType(rawValue: key),
                  let view = subviewsMap[type],
                  !view.isHidden else { continue }

            let w: CGFloat
            switch type {
            case .battery:
                w = 23.0
            case .network, .cpu, .gpu, .memory, .disk:
                let fitW = view.fittingSize.width
                w = fitW > 0 ? ceil(fitW) : 38.0
            }

            view.frame = NSRect(x: currentX, y: 0, width: w, height: 22)
            currentX += w + spacing
            activeCount += 1
        }

        let totalWidth = activeCount > 0 ? max(0, currentX - spacing) : 18.0
        self.frame = NSRect(x: 0, y: 0, width: totalWidth, height: 22)
    }
}

// MARK: - 网速上下两行组件
struct VerticalNetworkSpeedView: View {
    let net: NetworkSpeedInfo

    var body: some View {
        VStack(alignment: .trailing, spacing: -1.2) {
            HStack(spacing: 1.5) {
                Text(net.uploadFormatted)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 5.5))
            }
            HStack(spacing: 1.5) {
                Text(net.downloadFormatted)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 5.5))
            }
        }
        .foregroundStyle(Color.primary)
        .frame(minWidth: 46, alignment: .trailing)
        .frame(height: 22)
    }
}

// MARK: - 电池真彩色动态视图
class ClickableBatteryView: NSView {
    private var percentage: Int = 100
    private var isPluggedIn: Bool = false
    private var isLowPower: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 23.0, height: 22.0)
    }

    func update(percentage: Int, isPluggedIn: Bool, isLowPower: Bool) {
        guard self.percentage != percentage || self.isPluggedIn != isPluggedIn || self.isLowPower != isLowPower else {
            return
        }
        self.percentage = percentage
        self.isPluggedIn = isPluggedIn
        self.isLowPower = isLowPower
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bodyRect = NSRect(x: 0.5, y: 5.5, width: 21.0, height: 11.0)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2.5, yRadius: 2.5)

        let fillColor: NSColor
        let contentColor: NSColor

        if isLowPower {
            fillColor = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
            contentColor = NSColor.black
        } else if isPluggedIn {
            fillColor = NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
            contentColor = NSColor.black
        } else {
            if percentage > 50 {
                fillColor = NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
                contentColor = NSColor.black
            } else if percentage > 20 {
                fillColor = NSColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0)
                contentColor = NSColor.black
            } else {
                fillColor = NSColor(red: 0.95, green: 0.25, blue: 0.22, alpha: 1.0)
                contentColor = NSColor.white
            }
        }

        fillColor.setFill()
        bodyPath.fill()

        fillColor.setStroke()
        bodyPath.lineWidth = 1.0
        bodyPath.stroke()

        let tipRect = NSRect(x: 21.8, y: 9.1, width: 1.0, height: 3.5)
        let tipPath = NSBezierPath(roundedRect: tipRect, xRadius: 0.5, yRadius: 0.5)
        fillColor.setFill()
        tipPath.fill()

        let textStr = "\(percentage)"
        let fontSize: CGFloat = (percentage == 100) ? 6.2 : 7.0
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: contentColor]
        let textSize = (textStr as NSString).size(withAttributes: attrs)

        if isPluggedIn {
            let boltConfig = NSImage.SymbolConfiguration(pointSize: 6.0, weight: .black)
            if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(boltConfig)?
                .tinted(with: contentColor) {

                let boltW: CGFloat = 4.8
                let spacing: CGFloat = 0.6
                let totalW = boltW + spacing + textSize.width
                let startX = bodyRect.midX - (totalW / 2.0)
                let centerY = bodyRect.midY

                bolt.draw(in: NSRect(x: startX, y: centerY - 3.8, width: boltW, height: 7.6))
                (textStr as NSString).draw(at: NSPoint(x: startX + boltW + spacing, y: centerY - (textSize.height / 2.0) + 0.2), withAttributes: attrs)
            }
        } else {
            let textX = bodyRect.midX - (textSize.width / 2.0)
            let textY = bodyRect.midY - (textSize.height / 2.0) + 0.2
            (textStr as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
        }
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        return NSImage(size: self.size, flipped: false) { rect in
            self.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
