import SwiftUI
import Charts
import AppKit
import WidgetKit
import UniformTypeIdentifiers

// MARK: - 字母在左 + 极致紧凑圆环组件 (加入隔色底环，防止副屏半透明串色变青)
struct HorizontalRingGaugeView: View {
    let label: String
    let value: Double

    private var progressColor: Color {
        if value >= 80 {
            return Color(red: 0.95, green: 0.25, blue: 0.25)
        } else if value >= 50 {
            return Color(red: 0.98, green: 0.65, blue: 0.15)
        } else {
            return Color(red: 0.24, green: 0.82, blue: 0.32)
        }
    }

    var body: some View {
        HStack(spacing: 2.0) {
            Text(label)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.90))

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.22), lineWidth: 2.2)
                    .frame(width: 17.5, height: 17.5)

                // 底层隔色环，防止副屏半透明时蓝色桌面壁纸穿透把绿色变成青色
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.01, value / 100.0))))
                    .stroke(Color.black.opacity(0.65), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(90))
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
    let topProcesses: [ProcessMetricItem]

    private var eCores: Int { SystemMonitor.shared.eCoreCount }
    private var pCores: Int { SystemMonitor.shared.pCoreCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("CPU 多核活跃度 (\(coreUsages.count) 核)", "CPU Activity (\(coreUsages.count) Cores)"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    if pCores > 0 || eCores > 0 {
                        Text(L10n.t("\(eCores) 能效核 (E) · \(pCores) 性能核 (P)", "\(eCores) E-Cores · \(pCores) P-Cores"))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer()
                Text(String(format: "%.0f%%", coreUsages.isEmpty ? 0 : coreUsages.reduce(0, +) / Double(coreUsages.count)))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 4.5) {
                ForEach(Array(coreUsages.enumerated()), id: \.offset) { idx, usage in
                    let isECore = idx < eCores
                    SegmentedLedBar(
                        usage: usage,
                        activeColor: isECore ? Color(red: 0.25, green: 0.88, blue: 0.75) : Color(red: 0.35, green: 0.78, blue: 0.98)
                    )
                }
            }
            .frame(height: 82)

            if !topProcesses.isEmpty {
                Divider().overlay(Color.white.opacity(0.15))
                Text(L10n.t("活跃进程资源排行 (Top 5)", "Top Active Processes"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                VStack(spacing: 5) {
                    ForEach(topProcesses) { proc in
                        HStack(spacing: 6) {
                            if let icon = proc.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(proc.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer()
                            Text(proc.formattedValue)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.17, blue: 0.24))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: max(285, CGFloat(coreUsages.count) * 19 + 30))
    }
}

// MARK: - 内存与 Swap 详情卡片
struct MemoryDetailView: View {
    let mem: MemoryDetailInfo
    let topProcesses: [ProcessMetricItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("物理内存与交换空间", "Memory & Swap"), systemImage: "memorychip")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", mem.usagePercent))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(mem.pressureLevel == 2 ? .red : (mem.pressureLevel == 1 ? .orange : .purple))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let total = max(1.0, mem.totalGB)
                let wApp = CGFloat(mem.appGB / total) * geo.size.width
                let wWired = CGFloat(mem.wiredGB / total) * geo.size.width
                let wComp = CGFloat(mem.compressedGB / total) * geo.size.width

                HStack(spacing: 1) {
                    Rectangle().fill(Color.purple).frame(width: max(2, wApp))
                    Rectangle().fill(Color.orange).frame(width: max(2, wWired))
                    Rectangle().fill(Color.cyan).frame(width: max(2, wComp))
                    Spacer(minLength: 0)
                }
                .background(Color.primary.opacity(0.1))
                .clipShape(Capsule())
            }
            .frame(height: 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoTile(title: L10n.t("App 内存", "App Memory"), value: String(format: "%.1f GB", mem.appGB))
                InfoTile(title: L10n.t("联动内存 (Wired)", "Wired Memory"), value: String(format: "%.1f GB", mem.wiredGB))
                InfoTile(title: L10n.t("已压缩 (Compressed)", "Compressed"), value: String(format: "%.1f GB", mem.compressedGB))
                InfoTile(title: L10n.t("Swap 交换空间", "Swap Used"), value: mem.swapFormatted)
            }

            if !topProcesses.isEmpty {
                Divider()
                Text(L10n.t("内存占用排行 (Top 5)", "Top Memory Consumers"))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                VStack(spacing: 5) {
                    ForEach(topProcesses) { proc in
                        HStack(spacing: 6) {
                            if let icon = proc.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(proc.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Text(proc.formattedValue)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 270)
    }
}

// MARK: - 磁盘空间与读写 I/O 卡片
struct DiskDetailView: View {
    let disk: DiskDetailInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("系统磁盘与实时 I/O", "Disk & Real-Time I/O"), systemImage: "internaldrive")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", disk.usagePercent))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(1.0, max(0.0, disk.usagePercent / 100.0)))
                    .tint(.indigo)
                HStack {
                    Text(L10n.t(String(format: "已用 %.0f GB", disk.usedGB), String(format: "Used %.0f GB", disk.usedGB)))
                    Spacer()
                    Text(L10n.t(String(format: "可用 %.0f GB", disk.freeGB), String(format: "Free %.0f GB", disk.freeGB)))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("SSD 读取速率", "Read Speed"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(disk.readFormatted)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.t("SSD 写入速率", "Write Speed"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(disk.writeFormatted)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .frame(width: 250)
    }
}

// MARK: - GPU 历史记录点阵瀑布流窗口
struct GPUHistoryDotMatrixWindowView: View {
    let history: [Double]
    let modelName: String

    private let totalColumns = 42
    private let totalRows = 36

    private let cardBgColor = Color(red: 0.12, green: 0.17, blue: 0.24)
    private let screenBgColor = Color(red: 0.07, green: 0.10, blue: 0.15)
    private let unlitLedColor = Color(red: 0.11, green: 0.16, blue: 0.22)
    private let pCoreSkyBlue = Color(red: 0.35, green: 0.78, blue: 0.98)
    private let eCoreMintCyan = Color(red: 0.25, green: 0.88, blue: 0.78)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("GPU 历史负载瀑布流", "GPU Load History"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(modelName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Text(String(format: "%.0f%%", history.last ?? 0))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(pCoreSkyBlue)
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(screenBgColor)

                HStack(alignment: .bottom, spacing: 2.2) {
                    let paddedHistory = padHistory(history, to: totalColumns)
                    ForEach(0..<totalColumns, id: \.self) { colIdx in
                        let usage = paddedHistory[colIdx]
                        VStack(spacing: 1.5) {
                            ForEach((0..<totalRows).reversed(), id: \.self) { rowIdx in
                                let ratio = Double(rowIdx) / Double(totalRows)
                                let threshold = ratio * 100.0
                                let isLit = usage > 0.5 && usage >= threshold

                                RoundedRectangle(cornerRadius: 0.8)
                                    .fill(isLit ? ledColor(for: ratio) : unlitLedColor)
                                    .frame(width: 4.8, height: 3.2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(height: 185)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(12)
        .background(cardBgColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 326)
    }

    private func ledColor(for ratio: Double) -> Color {
        if ratio > 0.65 {
            return eCoreMintCyan
        } else if ratio > 0.30 {
            return pCoreSkyBlue
        } else {
            return Color(red: 0.22, green: 0.62, blue: 0.92)
        }
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
    var activeColor: Color = Color(red: 0.35, green: 0.78, blue: 0.98)
    let totalSegments: Int = 22

    var body: some View {
        VStack(spacing: 1.2) {
            ForEach((0..<totalSegments).reversed(), id: \.self) { index in
                let threshold = (Double(index) / Double(totalSegments)) * 100.0
                let isLit = usage >= threshold

                RoundedRectangle(cornerRadius: 0.6)
                    .fill(isLit ? activeColor : Color(red: 0.12, green: 0.18, blue: 0.24))
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
        if !battery.hasBattery {
            return L10n.t("台式机交流电源供电", "Desktop AC Power")
        }
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

    private var formattedAmperage: String {
        let absAmp = abs(battery.amperage)
        if absAmp == 0.0 {
            return "0 mA"
        } else if absAmp >= 1000.0 {
            return String(format: "%.2f A", absAmp / 1000.0)
        } else {
            return String(format: "%.0f mA", absAmp)
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
                    title: L10n.t("硬件温度", "Temperature"),
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
                    value: formattedAmperage
                )
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(width: 260)
    }
}

// MARK: - 网速与连接详情卡片
struct NetworkDetailView: View {
    let net: NetworkSpeedInfo
    @State private var copiedIP = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L10n.t("网络吞吐与连接", "Network & Link"), systemImage: "network")
                    .font(.headline)
                Spacer()
                Text(net.activeInterface.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("实时上行", "Upload")).font(.caption2).foregroundStyle(.secondary)
                    Text(net.uploadFormatted).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.green)
                    Text(L10n.t("累计: \(net.totalUploadedFormatted)", "Total: \(net.totalUploadedFormatted)"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.t("实时下行", "Download")).font(.caption2).foregroundStyle(.secondary)
                    Text(net.downloadFormatted).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.blue)
                    Text(L10n.t("累计: \(net.totalDownloadedFormatted)", "Total: \(net.totalDownloadedFormatted)"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text(L10n.t("局域网 IP", "Local IP"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(net.localIP, forType: .string)
                    copiedIP = true
                } label: {
                    HStack(spacing: 4) {
                        Text(copiedIP ? L10n.t("已复制", "Copied") : net.localIP)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Image(systemName: copiedIP ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }

            if net.wifiTxRate > 0 || !net.wifiSSID.isEmpty {
                HStack {
                    Text(net.wifiSSID.isEmpty ? "Wi-Fi" : net.wifiSSID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(net.wifiTxRate)) Mbps · \(net.wifiRSSI) dBm")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 255)
    }
}

// MARK: - 内嵌于控制面板的小组件实时光学预览组件
struct InlineWidgetLivePreview: View {
    let opacity: Double

    private var isGlass: Bool { opacity < 0.45 }
    private var primaryText: Color { isGlass ? .white : Color(red: 0.10, green: 0.12, blue: 0.16) }
    private var secondaryText: Color { isGlass ? .white.opacity(0.82) : Color(red: 0.42, green: 0.46, blue: 0.52) }
    private var trackFill: Color { isGlass ? .white.opacity(0.22) : Color.black.opacity(0.07) }
    private var cpuCyan: Color { isGlass ? Color(red: 0.25, green: 0.95, blue: 0.84) : Color(red: 0.05, green: 0.70, blue: 0.60) }
    private var gpuBlue: Color { isGlass ? Color(red: 0.38, green: 0.86, blue: 1.00) : Color(red: 0.00, green: 0.52, blue: 0.95) }

    private let sampleHistory: [Double] = [15, 22, 38, 55, 42, 28, 64, 78, 52, 30, 24, 48, 70, 58, 36, 25, 42, 60, 48, 32]

    var body: some View {
        ZStack {
            // 模拟太浩湖碧水蓝天壁纸底色
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.52, blue: 0.82),
                    Color(red: 0.24, green: 0.64, blue: 0.84),
                    Color(red: 0.12, green: 0.46, blue: 0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                if opacity < 0.45 {
                    let tintStrength = 0.02 + (opacity / 0.45) * 0.26
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.45, blue: 0.72).opacity(tintStrength),
                            Color(red: 0.04, green: 0.22, blue: 0.42).opacity(tintStrength * 1.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.02), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.65), Color.white.opacity(0.18), Color.white.opacity(0.40)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                } else {
                    let whiteProgress = (opacity - 0.45) / 0.55
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.78 + 0.22 * whiteProgress))
                }

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().stroke(trackFill, lineWidth: 5).frame(width: 44, height: 44)
                            Circle().trim(from: 0, to: 0.24)
                                .stroke(cpuCyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                            Text("24%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryText)
                        }
                        Text("CPU")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(secondaryText)
                    }
                    .frame(width: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("GPU")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("36%")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(gpuBlue)
                        }

                        Canvas { context, size in
                            let cols = 22
                            let rows = 8
                            let hSpace: CGFloat = 2.2
                            let vSpace: CGFloat = 1.6
                            let cw = max(1.5, (size.width - CGFloat(cols - 1) * hSpace) / CGFloat(cols))
                            let ch = max(1.5, (size.height - CGFloat(rows - 1) * vSpace) / CGFloat(rows))

                            for c in 0..<cols {
                                let val = sampleHistory[c % sampleHistory.count]
                                let x = CGFloat(c) * (cw + hSpace)
                                for r in 0..<rows {
                                    let ratio = Double(r) / Double(rows)
                                    let lit = val >= ratio * 100.0
                                    let y = CGFloat(rows - 1 - r) * (ch + vSpace)
                                    let path = Path(roundedRect: CGRect(x: x, y: y, width: cw, height: ch), cornerRadius: 0.8)
                                    context.fill(path, with: .color(lit ? (ratio > 0.6 ? cpuCyan : gpuBlue) : trackFill))
                                }
                            }
                        }
                        .frame(height: 38)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 状态栏指标样式可视化选择卡片
struct MetricStyleOptionCard<PreviewContent: View>: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let preview: PreviewContent

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        preview
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color(NSColor.textBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.65) : Color.primary.opacity(0.07), lineWidth: isSelected ? 1.5 : 1.0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 主 App 控制面板
struct SettingsDashboardView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var draggingItemKey: String?

    private var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"
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
                    Text(L10n.t("全功能 Apple Silicon 硬件状态栏与桌面监控工具箱", "Full-Featured Apple Silicon Hardware Monitor"))
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
                    // 卡片一：桌面小组件外观与透明度
                    SettingsCard(
                        title: L10n.t("桌面小组件外观与透明度", "Widget Appearance & Opacity"),
                        subtitle: L10n.t("自定义桌面小组件背景材质，支持从全透明毛玻璃平滑过渡至纯白底板", "Customize widget background from clear glass to solid white")
                    ) {
                        VStack(spacing: 10) {
                            InlineWidgetLivePreview(opacity: settings.widgetOpacity)

                            HStack {
                                Image(systemName: "drop.halffull")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text(L10n.t("背景不透明度", "Background Opacity"))
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("\(Int(settings.widgetOpacity * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 12) {
                                Button(L10n.t("全透明 (0%)", "Clear (0%)")) {
                                    settings.widgetOpacity = 0.0
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Slider(value: $settings.widgetOpacity, in: 0.0...1.0, step: 0.05)

                                Button(L10n.t("不透明 (100%)", "Solid (100%)")) {
                                    settings.widgetOpacity = 1.0
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 卡片二：状态栏监控项 (拖拽实时排序)
                    SettingsCard(
                        title: L10n.t("状态栏监控项", "Menu Bar Items"),
                        subtitle: L10n.t("按住左侧手柄上下拖拽调整顺序，开关控制是否在菜单栏显示", "Drag the handle to reorder items; toggle switches to show or hide in the menu bar")
                    ) {
                        VStack(spacing: 8) {
                            ForEach(settings.itemOrder, id: \.self) { key in
                                if let type = StatusItemType(rawValue: key) {
                                    ModuleOrderRow(
                                        type: type,
                                        isDragging: draggingItemKey == key,
                                        isVisible: Binding(
                                            get: { settings.isItemVisible(type: type) },
                                            set: { settings.setItemVisible(type: type, isVisible: $0) }
                                        )
                                    )
                                    .onDrag {
                                        self.draggingItemKey = key
                                        return NSItemProvider(object: key as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: ModuleReorderDropDelegate(
                                            targetKey: key,
                                            settings: settings,
                                            draggingItemKey: $draggingItemKey
                                        )
                                    )
                                }
                            }
                        }
                    }

                    // 卡片三：状态栏指标样式
                    SettingsCard(
                        title: L10n.t("状态栏指标样式", "Menu Bar Metric Style"),
                        subtitle: L10n.t("选择顶部菜单栏中 CPU、GPU、内存与磁盘的显示形态", "Choose how CPU, GPU, Memory, and Disk appear in the menu bar")
                    ) {
                        HStack(spacing: 12) {
                            MetricStyleOptionCard(
                                title: L10n.t("动态圆环仪表 (推荐)", "Ring Gauge"),
                                subtitle: L10n.t("紧凑标识搭配三色负载圆环", "Compact label with color ring"),
                                isSelected: settings.displayStyle == .gauge,
                                action: { settings.displayStyle = .gauge }
                            ) {
                                HorizontalRingGaugeView(label: "CPU", value: 24)
                                HorizontalRingGaugeView(label: "GPU", value: 58)
                            }

                            MetricStyleOptionCard(
                                title: L10n.t("等宽纯享数字", "Monospaced Text"),
                                subtitle: L10n.t("极简纯文本百分比读数", "Minimalist percentage readout"),
                                isSelected: settings.displayStyle == .text,
                                action: { settings.displayStyle = .text }
                            ) {
                                TextMetricView(label: "CPU", value: 24)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // 卡片四：图标水平间距调节滑块
                    SettingsCard(
                        title: L10n.t("状态栏布局与间距", "Layout & Item Spacing"),
                        subtitle: L10n.t("调整状态栏各监控模块之间的水平间距", "Adjust horizontal spacing between menu bar items")
                    ) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(L10n.t("间距大小", "Spacing Size"))
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(settings.itemSpacing == 0 ? L10n.t("0 pt (紧凑)", "0 pt (Compact)") : "\(Int(settings.itemSpacing)) pt")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 12) {
                                Text(L10n.t("紧凑 (0)", "Compact (0)"))
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

                    // 卡片五：采样刷新率与智能告警
                    SettingsCard(
                        title: L10n.t("采样性能与智能阈值告警", "Sampling & Smart Alerts"),
                        subtitle: L10n.t("定制硬件采样间隔、电池省电降频与系统异常通知", "Configure sampling rate, battery throttling, and notifications")
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text(L10n.t("硬件采样间隔", "Sampling Interval"))
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(String(format: "%.1f s", settings.refreshInterval))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 12) {
                                Text(L10n.t("极速 (0.5s)", "Fast (0.5s)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Slider(value: $settings.refreshInterval, in: 0.5...5.0, step: 0.5)
                                Text(L10n.t("省电 (5.0s)", "Eco (5.0s)"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            ToggleRow(
                                title: L10n.t("电池供电或低电量模式时自动降频", "Auto-Throttle on Battery / Low Power"),
                                subtitle: L10n.t("未接电源时自动将采样周期放宽至 3.0 秒以降低后台能耗", "Automatically relax interval to 3.0s on battery power"),
                                isOn: $settings.autoLowPowerThrottle
                            )

                            Divider()

                            ToggleRow(
                                title: L10n.t("启用硬件过载与电池健康提醒", "Enable Hardware & Battery Alerts"),
                                subtitle: L10n.t("CPU 持续满载、内存告急、充电达 80% 或电量低于 15% 时发送系统通知", "Notify on sustained high CPU/RAM or battery 80% / 15%"),
                                isOn: $settings.enableHardwareAlerts
                            )
                        }
                    }

                    // 卡片六：控制面板呼出方式
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
                        }
                    }

                    // 卡片七：系统集成与多屏常驻行为 (新增仅主屏幕显示开关)
                    SettingsCard(
                        title: L10n.t("系统集成与多屏行为", "System & Multi-Display Integration"),
                        subtitle: L10n.t("管理系统启动项、多显示器菜单栏与跨窗口空间交互", "Manage login startup, multi-display visibility, and fullscreen behaviors")
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleRow(
                                title: L10n.t("开机时自动启动", "Launch at Login"),
                                subtitle: L10n.t("系统登录时自动在后台启动 MacMonitor", "Automatically start MacMonitor in the background on login"),
                                isOn: $settings.launchAtLogin
                            )

                            Divider()

                            ToggleRow(
                                title: L10n.t("仅在主显示器菜单栏显示", "Show on Main Display Only"),
                                subtitle: L10n.t("开启后当鼠标焦点切换到外接副屏时自动隐藏状态栏项；关闭则在所有屏幕常驻显示", "Hide menu bar items when focusing on secondary displays"),
                                isOn: $settings.showOnMainScreenOnly
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
                    Text(L10n.t("点击状态栏图标查看实时详情，双击或右键打开设置", "Click menu bar items for details, double/right-click for settings"))
                        .font(.system(size: 11))
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
        .frame(width: 500, height: 760)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - 辅助子组件：支持拖拽手柄的模块行
struct ModuleOrderRow: View {
    let type: StatusItemType
    let isDragging: Bool
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 24)
                .contentShape(Rectangle())

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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDragging ? Color.blue.opacity(0.10) : Color(NSColor.textBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDragging ? Color.blue.opacity(0.5) : Color.primary.opacity(0.04), lineWidth: 1)
        )
        .opacity(isDragging ? 0.85 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 拖拽排序代理
struct ModuleReorderDropDelegate: DropDelegate {
    let targetKey: String
    let settings: AppSettings
    @Binding var draggingItemKey: String?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItemKey = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingKey = draggingItemKey,
              draggingKey != targetKey,
              let fromIndex = settings.itemOrder.firstIndex(of: draggingKey),
              let toIndex = settings.itemOrder.firstIndex(of: targetKey) else {
            return
        }

        var updatedOrder = settings.itemOrder
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            updatedOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            settings.updateItemOrder(updatedOrder)
        }
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

    private init() {
        NotificationCenter.default.addObserver(
            forName: .rebuildStatusItems,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWindowAppearance()
        }
    }

    func syncWindowAppearance() {
        guard let window = window else { return }
        if AppSettings.shared.allowFullScreenOverlay {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = []
        }
        window.title = L10n.t("MacMonitor 控制面板", "MacMonitor Settings")
    }

    func open() {
        if let window = window {
            syncWindowAppearance()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(rootView: SettingsDashboardView())
        self.window = newWindow
        syncWindowAppearance()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}
