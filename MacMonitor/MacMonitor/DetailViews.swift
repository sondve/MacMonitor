import SwiftUI
import Charts
import AppKit

// MARK: - 字母在左 + 极致紧凑圆环组件 (如: CPU ⭕)
struct HorizontalRingGaugeView: View {
    let label: String
    let value: Double

    private var progressColor: Color {
        if value >= 80 {
            return Color(red: 0.95, green: 0.25, blue: 0.25)
        } else if value >= 50 {
            return Color(red: 0.98, green: 0.65, blue: 0.15)
        } else {
            return Color(red: 0.28, green: 0.85, blue: 0.35)
        }
    }

    var body: some View {
        HStack(spacing: 2.0) {
            Text(label)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.85))

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 2.2)
                    .frame(width: 17.5, height: 17.5)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.01, value / 100.0))))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 17.5, height: 17.5)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 6.8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
            .frame(width: 17.5, height: 17.5)
        }
        .frame(height: 22)
    }
}

// MARK: - 纯文字显示模式组件 (CPU: 24%)
struct TextMetricView: View {
    let label: String
    let value: Double

    var body: some View {
        Text(String(format: "\(label): %.0f%%", value))
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.primary)
            .frame(height: 22)
    }
}

// MARK: - CPU 多核心 LED 监视卡片
struct CPUDetailView: View {
    let coreUsages: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("CPU 多核活跃度 (\(coreUsages.count) 核心)", "CPU Activity (\(coreUsages.count) Cores)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", coreUsages.isEmpty ? 0 : coreUsages.reduce(0, +) / Double(coreUsages.count)))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 4.5) {
                ForEach(Array(coreUsages.enumerated()), id: \.offset) { _, usage in
                    SegmentedLedBar(usage: usage)
                }
            }
            .frame(height: 86)
        }
        .padding(12)
        .background(Color(red: 0.14, green: 0.20, blue: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: max(280, CGFloat(coreUsages.count) * 20 + 30))
    }
}

// MARK: - GPU 历史记录点阵瀑布流窗口
struct GPUHistoryDotMatrixWindowView: View {
    let history: [Double]
    let modelName: String

    private let totalColumns = 42
    private let totalRows = 45

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t("GPU 历史记录", "GPU History"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", history.last ?? 0))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.0, green: 0.48, blue: 1.0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            ZStack(alignment: .topLeading) {
                Color.black

                HStack(alignment: .bottom, spacing: 2.2) {
                    let paddedHistory = padHistory(history, to: totalColumns)
                    ForEach(0..<totalColumns, id: \.self) { colIdx in
                        let usage = paddedHistory[colIdx]
                        VStack(spacing: 1.6) {
                            ForEach((0..<totalRows).reversed(), id: \.self) { rowIdx in
                                let threshold = (Double(rowIdx) / Double(totalRows)) * 100.0
                                let isLit = usage >= threshold
                                Rectangle()
                                    .fill(isLit ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.clear)
                                    .frame(width: 4.8, height: 3.2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                Text(modelName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                    .padding(.leading, 12)
            }
            .frame(height: 250)
        }
        .frame(width: 320)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }

    private func padHistory(_ list: [Double], to count: Int) -> [Double] {
        if list.count >= count {
            return Array(list.suffix(count))
        } else {
            let padding = Array(repeating: 0.0, count: count - list.count)
            return padding + list
        }
    }
}

// MARK: - 垂直分段 LED 柱状组件
struct SegmentedLedBar: View {
    let usage: Double
    let totalSegments: Int = 22

    var body: some View {
        VStack(spacing: 1.2) {
            ForEach((0..<totalSegments).reversed(), id: \.self) { index in
                let threshold = (Double(index) / Double(totalSegments)) * 100.0
                let isLit = usage >= threshold

                RoundedRectangle(cornerRadius: 0.6)
                    .fill(isLit ? Color(red: 0.35, green: 0.78, blue: 0.98) : Color(red: 0.12, green: 0.18, blue: 0.24))
                    .frame(height: 2.4)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 3.5).fill(Color(red: 0.08, green: 0.12, blue: 0.16)))
    }
}

// MARK: - 电池详情卡片
struct BatteryDetailView: View {
    let battery: BatteryAdvancedInfo

    private var powerTitle: String {
        if battery.isPluggedIn {
            if battery.isCharging {
                return L10n.t("实时充电功率", "Charging Power")
            } else if battery.isFullyCharged {
                return L10n.t("已充满供电中", "Bypass Power")
            } else {
                return L10n.t("外接电源供电", "AC Power")
            }
        } else {
            return L10n.t("实时放电功率", "Discharge Power")
        }
    }

    private var voltageTitle: String {
        battery.isPluggedIn && battery.isCharging
            ? L10n.t("实时充电电压", "Charging Voltage")
            : L10n.t("实时工作电压", "Operating Voltage")
    }

    private var currentTitle: String {
        if battery.isPluggedIn {
            return battery.isCharging
                ? L10n.t("实时充电电流", "Charging Current")
                : L10n.t("输入电流状态", "Current State")
        } else {
            return L10n.t("实时放电电流", "Discharge Current")
        }
    }

    private var statusDescription: String {
        if battery.isPluggedIn {
            if battery.isCharging {
                return L10n.t("正在充电", "Charging")
            } else if battery.isFullyCharged {
                return L10n.t("已充满 (闲置)", "Fully Charged")
            } else {
                return L10n.t("未在充电", "Not Charging")
            }
        } else {
            return L10n.t("电池供电中", "On Battery Power")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Image(systemName: battery.isPluggedIn ? (battery.isCharging ? "bolt.fill" : "powerplug.fill") : "battery.100")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(battery.isPluggedIn ? (battery.isCharging ? .green : .blue) : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(battery.percentage)%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(statusDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", battery.wattage))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(battery.isCharging ? .green : (battery.isPluggedIn ? .blue : .primary))
                            .monospacedDigit()
                        Text("W")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(powerTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                InfoTile(
                    title: L10n.t("最大健康度", "Max Capacity"),
                    value: "\(battery.healthPercent)%"
                )
                InfoTile(
                    title: L10n.t("循环计数", "Cycle Count"),
                    value: L10n.t("\(battery.cycleCount) 次", "\(battery.cycleCount) Cycles")
                )
                InfoTile(
                    title: L10n.t("电池温度", "Temperature"),
                    value: String(format: "%.1f°C", battery.temperature)
                )
                InfoTile(
                    title: L10n.t("充放状态", "Power Status"),
                    value: battery.isPluggedIn
                        ? (battery.isCharging ? L10n.t("充电中", "Charging") : L10n.t("未充电", "Idle"))
                        : L10n.t("放电中", "Discharging")
                )
                InfoTile(
                    title: voltageTitle,
                    value: String(format: "%.2f V", battery.voltage)
                )
                InfoTile(
                    title: currentTitle,
                    value: battery.amperage == 0.0
                        ? "0 mA"
                        : (battery.amperage >= 1000
                            ? String(format: "%.2f A", battery.amperage / 1000.0)
                            : String(format: "%.0f mA", battery.amperage))
                )
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(width: 255)
    }
}

// MARK: - 网速详情卡片
struct NetworkDetailView: View {
    let net: NetworkSpeedInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.t("网络实时吞吐", "Network Throughput"), systemImage: "network")
                .font(.headline)
            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("上行速率", "Upload Speed")).font(.caption2).foregroundStyle(.secondary)
                    Text(net.uploadFormatted).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("下行速率", "Download Speed")).font(.caption2).foregroundStyle(.secondary)
                    Text(net.downloadFormatted).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.blue)
                }
            }
        }
        .padding(14)
        .frame(width: 230)
    }
}

// MARK: - 主 App 控制面板
struct SettingsDashboardView: View {
    @ObservedObject var settings = AppSettings.shared

    private var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v \(ver)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部 Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L10n.t("MacMonitor 控制面板", "MacMonitor Settings"))
                            .font(.system(size: 15, weight: .bold))
                        
                        Text(appVersion)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                    Text(L10n.t("轻量级 Apple Silicon 硬件状态栏监控工具箱", "Lightweight Apple Silicon Hardware Monitor"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            // 2. 主体分组卡片内容
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    // 卡片一：模块排序与启用开关
                    SettingsCard(
                        title: L10n.t("状态栏模块与排序", "Modules & Ordering"),
                        subtitle: L10n.t("上下移动调整状态栏呈现顺序，勾选决定是否启用", "Reorder status bar items and toggle their visibility")
                    ) {
                        VStack(spacing: 8) {
                            ForEach(Array(settings.itemOrder.enumerated()), id: \.element) { index, key in
                                if let type = StatusItemType(rawValue: key) {
                                    ModuleOrderRow(
                                        type: type,
                                        index: index,
                                        totalCount: settings.itemOrder.count,
                                        isVisible: Binding(
                                            get: { settings.isItemVisible(type: type) },
                                            set: { settings.setItemVisible(type: type, isVisible: $0) }
                                        ),
                                        onMoveUp: { settings.moveItem(from: index, up: true) },
                                        onMoveDown: { settings.moveItem(from: index, up: false) }
                                    )
                                }
                            }
                        }
                    }

                    // 卡片二：图标水平间距调节滑块
                    SettingsCard(
                        title: L10n.t("状态栏布局与间距", "Layout & Item Spacing"),
                        subtitle: L10n.t("0 pt 为无缝完全紧挨着，向右滑动平滑增加间距", "0 pt means touching edge-to-edge; slide right to expand")
                    ) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(L10n.t("间距大小", "Spacing Size"))
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(settings.itemSpacing == 0 ? L10n.t("0 pt (紧挨着)", "0 pt (Touching)") : "\(Int(settings.itemSpacing)) pt")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 12) {
                                Text(L10n.t("紧挨 (0)", "Touch (0)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)

                                Slider(value: $settings.itemSpacing, in: 0...20, step: 1)

                                Text(L10n.t("宽松 (20)", "Wide (20)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 卡片三：小组件视觉效果与透明度滑块
                    SettingsCard(
                        title: L10n.t("小组件液态玻璃与透明度", "Widget Liquid Glass & Opacity"),
                        subtitle: L10n.t("滑动控制桌面小组件的透明度，0% 为全透明悬浮，100% 为不透明", "Slide to control widget glass opacity: 0% is clear, 100% is solid")
                    ) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "drop.halffull")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text(L10n.t("组件不透明度", "Widget Opacity"))
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(settings.widgetOpacity == 0 ? L10n.t("完全透明 (0%)", "Clear (0%)") : "\(Int(settings.widgetOpacity * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 12) {
                                Text(L10n.t("全透明 (0%)", "Clear (0%)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)

                                Slider(value: $settings.widgetOpacity, in: 0.0...1.0, step: 0.05)

                                Text(L10n.t("不透明 (100%)", "Solid (100%)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 卡片四：CPU / GPU 显示样式
                    SettingsCard(
                        title: L10n.t("仪表盘与视觉风格", "Gauge & Visual Style"),
                        subtitle: L10n.t("定制状态栏中 CPU 与 GPU 核心的呈现形式", "Customize CPU & GPU presentation styles in menu bar")
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("", selection: $settings.displayStyle) {
                                Text(L10n.t("⭕ 字母左侧 + 放大圆环仪表盘 (推荐)", "⭕ Ring Gauge with Label (Recommended)")).tag(MetricDisplayStyle.gauge)
                                Text(L10n.t("🔢 纯字母 + 百分比数字 (CPU: 24%)", "🔢 Text & Percentage (CPU: 24%)")).tag(MetricDisplayStyle.text)
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()

                            Text(L10n.t("💡 提示：在状态栏中点击 CPU 或 GPU 可随时查看点阵历史瀑布流与多核均衡器。", "💡 Tip: Click CPU or GPU in the menu bar to view detailed matrix/history."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // 卡片五：控制面板呼出方式
                    SettingsCard(
                        title: L10n.t("控制面板呼出方式", "Open Settings Panel"),
                        subtitle: L10n.t("设置从状态栏打开此控制面板的触发手势", "Choose how to open this settings panel from the menu bar")
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleRow(
                                title: L10n.t("双击图标打开控制面板", "Double-Click to Open Settings"),
                                subtitle: L10n.t("双击状态栏任意图标直接呼出本面板", "Double-click any menu bar item to open settings"),
                                isOn: $settings.enableDoubleClickOpenSettings
                            )
                            .disabled(settings.enableDoubleClickOpenSettings && !settings.enableRightClickOpenSettings)

                            Divider()

                            ToggleRow(
                                title: L10n.t("右键菜单打开控制面板", "Right-Click Menu to Open Settings"),
                                subtitle: L10n.t("右键点击状态栏图标时在菜单中提供「打开控制面板...」", "Show 'Open Settings...' in right-click context menu"),
                                isOn: $settings.enableRightClickOpenSettings
                            )
                            .disabled(settings.enableRightClickOpenSettings && !settings.enableDoubleClickOpenSettings)

                            if (settings.enableDoubleClickOpenSettings && !settings.enableRightClickOpenSettings) ||
                               (settings.enableRightClickOpenSettings && !settings.enableDoubleClickOpenSettings) {
                                Text(L10n.t("💡 为防止无法再次打开控制面板，系统会自动锁定并保留最后一种打开方式。", "💡 At least one method must be kept to ensure the panel can be reopened."))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    // 卡片六：系统集成与常驻
                    SettingsCard(
                        title: L10n.t("系统集成与常驻行为", "System Integration"),
                        subtitle: L10n.t("管理系统启动项与跨窗口空间交互", "Manage login startup and desktop space behaviors")
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleRow(
                                title: L10n.t("开机时自动启动", "Launch at Login"),
                                subtitle: L10n.t("系统登录时自动在后台启动 MacMonitor", "Automatically start MacMonitor in the background on login"),
                                isOn: $settings.launchAtLogin
                            )

                            Divider()

                            ToggleRow(
                                title: L10n.t("在程序坞 (Dock) 中显示图标", "Show Icon in Dock"),
                                subtitle: L10n.t("开启后常驻 Dock 栏与 ⌘+Tab；关闭后纯后台无干扰常驻", "Display app in Dock and ⌘+Tab; hide for background only"),
                                isOn: $settings.showDockIcon
                            )

                            Divider()

                            ToggleRow(
                                title: L10n.t("全屏模式下置顶显示详情", "Show Details over Fullscreen Apps"),
                                subtitle: L10n.t("其他应用处于全屏模式时，移至顶部点击依然能正常弹出卡片", "Allow detail popovers to show when menu bar reveals in full screen"),
                                isOn: $settings.allowFullScreenOverlay
                            )
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // 3. 底部完成栏
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10))
                    if settings.enableDoubleClickOpenSettings && settings.enableRightClickOpenSettings {
                        Text(L10n.t("双击图标或右键菜单均可快速呼出本面板", "Double-click or right-click any icon to open this panel"))
                            .font(.system(size: 11))
                    } else if settings.enableDoubleClickOpenSettings {
                        Text(L10n.t("双击状态栏任意图标可快速呼出本面板", "Double-click any menu bar item to open this panel"))
                            .font(.system(size: 11))
                    } else {
                        Text(L10n.t("右键状态栏图标并选择「打开控制面板」可呼出本面板", "Right-click any menu bar item to open this panel"))
                            .font(.system(size: 11))
                    }
                }
                .foregroundStyle(.tertiary)

                Spacer()

                Button(L10n.t("完成", "Done")) {
                    SettingsWindowManager.shared.close()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 720)
    }
}

// MARK: - 辅助子组件：分组卡片容器
struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack {
                content
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - 辅助子组件：模块行
struct ModuleOrderRow: View {
    let type: StatusItemType
    let index: Int
    let totalCount: Int
    @Binding var isVisible: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.themeColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(type.themeColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(type.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 20)
                .background(Color.primary.opacity(index == 0 ? 0.03 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(index == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 20)
                .background(Color.primary.opacity(index == totalCount - 1 ? 0.03 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(index == totalCount - 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.4))
        )
    }
}

// MARK: - 辅助子组件：开关行
struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

// MARK: - 辅助子组件：单项数据格
struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    func open() {
        if let window = window {
            if AppSettings.shared.allowFullScreenOverlay {
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            } else {
                window.collectionBehavior = []
            }
            window.title = L10n.t("MacMonitor 控制面板", "MacMonitor Settings")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = L10n.t("MacMonitor 控制面板", "MacMonitor Settings")
        newWindow.center()
        if AppSettings.shared.allowFullScreenOverlay {
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(rootView: SettingsDashboardView())
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}
