import SwiftUI
import AppKit
import WidgetKit
import CoreGraphics
import ApplicationServices

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

    var currentShowingType: StatusItemType?

    // 硬件指标缓存
    var currentCores: [Double] = []
    var currentGPU: Double = 0
    var currentNet = NetworkSpeedInfo()
    var currentBattery = BatteryAdvancedInfo()
    var gpuHistory: [Double] = []

    // MARK: - 可靠的全屏检测引擎
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

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            var frontWindow: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &frontWindow) == .success,
               let window = frontWindow {
                var isAXFullScreen: AnyObject?
                if AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &isAXFullScreen) == .success,
                   let isFull = isAXFullScreen as? Bool, isFull {
                    return true
                }
            }
        }

        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        // 1. 初始化单一融合状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        containerView = UnifiedBarContainerView()

        containerView.onItemClick = { [weak self] type, targetView in
            self?.handleClick(type: type, sender: targetView)
        }
        containerView.onDoubleClick = {
            if AppSettings.shared.enableDoubleClickOpenSettings {
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

        SettingsWindowManager.shared.open()

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc func onRebuildNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.open()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func handleClick(type: StatusItemType, sender: NSView) {
        // 如果点击的是当前已经打开的单项，执行关闭并收起
        if let currentPopover = popover, currentPopover.isShown && currentShowingType == type {
            currentPopover.delegate = nil
            currentPopover.animates = false
            currentPopover.close()
            self.popover = nil
            self.currentShowingType = nil
            return
        }

        let isFullScreen = isSystemInFullScreen(for: sender.window?.screen)
        if !AppSettings.shared.allowFullScreenOverlay && isFullScreen {
            currentShowingType = nil
            return
        }

        currentShowingType = type

        switch type {
        case .cpu:
            showPopover(content: CPUDetailView(coreUsages: currentCores), positioningView: sender)
        case .gpu:
            showPopover(
                content: GPUHistoryDotMatrixWindowView(history: gpuHistory, modelName: SystemMonitor.shared.gpuModelName),
                positioningView: sender
            )
        case .network:
            showPopover(content: NetworkDetailView(net: currentNet), positioningView: sender)
        case .battery:
            showPopover(content: BatteryDetailView(battery: currentBattery), positioningView: sender)
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
        // 【关键修复点 1】：若已有旧弹窗，先卸载代理并立刻硬关闭，彻底消除动画重叠
        if let existingPopover = popover {
            existingPopover.delegate = nil
            existingPopover.animates = false
            existingPopover.close()
            self.popover = nil
        }

        let allowOverlay = AppSettings.shared.allowFullScreenOverlay
        let isFullScreen = isSystemInFullScreen(for: positioningView.window?.screen)

        if !allowOverlay && isFullScreen {
            currentShowingType = nil
            return
        }

        if allowOverlay {
            NSApp.activate(ignoringOtherApps: true)
        }

        // 【关键修复点 2】：每次新建 NSPopover，从底层保证没有旧视图的像素图层残留
        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.animates = true
        newPopover.delegate = self
        self.popover = newPopover

        // 【关键修复点 3】：预先强制进行首帧布局与尺寸计算，杜绝加载过程中的内容跳动
        let controller = NSHostingController(rootView: content)
        _ = controller.view
        controller.view.layoutSubtreeIfNeeded()
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

    // MARK: - NSPopoverDelegate 代理同步
    func popoverDidClose(_ notification: Notification) {
        currentShowingType = nil
        popover = nil
    }

    func refresh() {
        currentCores = SystemMonitor.shared.getPerCoreCPUUsage()
        let avgCPU = currentCores.isEmpty ? 0.0 : currentCores.reduce(0, +) / Double(currentCores.count)

        currentGPU = SystemMonitor.shared.getGPUUsage()
        gpuHistory.append(currentGPU)
        if gpuHistory.count > 50 { gpuHistory.removeFirst() }
        SystemMonitor.shared.appendGPUHistory(val: currentGPU)
        WidgetCenter.shared.reloadTimelines(ofKind: "GPUTrendWidget")

        currentNet = SystemMonitor.shared.getNetworkSpeed()
        currentBattery = SystemMonitor.shared.getBatteryDetails()

        containerView.update(
            cpuUsage: avgCPU,
            gpuUsage: currentGPU,
            net: currentNet,
            battery: currentBattery,
            settings: AppSettings.shared
        )

        statusItem.length = containerView.frame.width
    }
}

// MARK: - 统一状态栏无缝容器
class UnifiedBarContainerView: NSView {
    var onItemClick: ((StatusItemType, NSView) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSView) -> Void)?

    private var subviewsMap: [StatusItemType: NSView] = [:]
    private var netHosting: NSHostingView<AnyView>?
    private var cpuHosting: NSHostingView<AnyView>?
    private var gpuHosting: NSHostingView<AnyView>?
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

    func update(cpuUsage: Double, gpuUsage: Double, net: NetworkSpeedInfo, battery: BatteryAdvancedInfo, settings: AppSettings) {
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

        if settings.showCPU {
            let cpuView: AnyView = (settings.displayStyle == .gauge)
                ? AnyView(HorizontalRingGaugeView(label: "CPU", value: cpuUsage).allowsHitTesting(false))
                : AnyView(TextMetricView(label: "CPU", value: cpuUsage).allowsHitTesting(false))

            if let host = cpuHosting {
                host.rootView = cpuView
            } else {
                let host = NSHostingView(rootView: cpuView)
                cpuHosting = host
                subviewsMap[.cpu] = host
                addSubview(host)
            }
            cpuHosting?.isHidden = false
        } else {
            cpuHosting?.isHidden = true
        }

        if settings.showGPU {
            let gpuView: AnyView = (settings.displayStyle == .gauge)
                ? AnyView(HorizontalRingGaugeView(label: "GPU", value: gpuUsage).allowsHitTesting(false))
                : AnyView(TextMetricView(label: "GPU", value: gpuUsage).allowsHitTesting(false))

            if let host = gpuHosting {
                host.rootView = gpuView
            } else {
                let host = NSHostingView(rootView: gpuView)
                gpuHosting = host
                subviewsMap[.gpu] = host
                addSubview(host)
            }
            gpuHosting?.isHidden = false
        } else {
            gpuHosting?.isHidden = true
        }

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
            case .network, .cpu, .gpu:
                let fitW = view.fittingSize.width
                w = fitW > 0 ? ceil(fitW) : 38.0
            }

            view.frame = NSRect(x: currentX, y: 0, width: w, height: 22)
            currentX += w + spacing
            activeCount += 1
        }

        let totalWidth = activeCount > 0 ? max(0, currentX - spacing) : 0
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
        guard let copy = self.copy() as? NSImage else { return self }
        copy.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: copy.size)
        rect.fill(using: .sourceAtop)
        copy.unlockFocus()
        copy.isTemplate = false
        return copy
    }
}
