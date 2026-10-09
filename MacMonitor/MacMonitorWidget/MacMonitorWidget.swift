import WidgetKit
import SwiftUI

// MARK: - App Group 共享数据读取工具
struct WidgetDataProvider {
    static let suiteName = "group.com.local.macmonitor"
    static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    static func getSystemData() -> SystemSnapshot {
        let def = defaults
        let cpu = def?.double(forKey: "cpu_usage") ?? 0.0
        let cores = def?.array(forKey: "cpu_cores") as? [Double] ?? []
        let gpuHistory = def?.array(forKey: "gpu_history") as? [Double] ?? []
        let gpu = gpuHistory.last ?? def?.double(forKey: "gpu_usage") ?? 0.0
        let up = def?.double(forKey: "net_upload") ?? 0.0
        let down = def?.double(forKey: "net_download") ?? 0.0
        let battery = def?.integer(forKey: "battery_percent") ?? 100
        let plugged = def?.bool(forKey: "battery_plugged") ?? false
        let wattage = def?.double(forKey: "battery_wattage") ?? 0.0

        return SystemSnapshot(
            cpuUsage: cpu,
            cpuCores: cores,
            gpuUsage: gpu,
            gpuHistory: gpuHistory,
            uploadSpeed: up,
            downloadSpeed: down,
            batteryPercent: battery,
            isPluggedIn: plugged,
            wattage: wattage
        )
    }

    static func formatSpeedUnit(_ bytes: Double) -> (value: String, unit: String) {
        if bytes >= 1024 * 1024 {
            return (String(format: "%.1f", bytes / (1024 * 1024)), "MB/s")
        } else {
            return (String(format: "%.0f", max(0, bytes / 1024)), "KB/s")
        }
    }
}

struct SystemSnapshot {
    let cpuUsage: Double
    let cpuCores: [Double]
    let gpuUsage: Double
    let gpuHistory: [Double]
    let uploadSpeed: Double
    let downloadSpeed: Double
    let batteryPercent: Int
    let isPluggedIn: Bool
    let wattage: Double
}

struct SystemEntry: TimelineEntry {
    let date: Date
    let data: SystemSnapshot
}

// MARK: - 时间线 Provider
struct SystemTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SystemEntry {
        let mockCores = [20.0, 45.0, 15.0, 70.0, 30.0, 60.0, 25.0, 50.0, 35.0, 80.0, 40.0, 65.0]
        let mockHistory = (0..<24).map { _ in Double.random(in: 20...85) }
        return SystemEntry(
            date: Date(),
            data: SystemSnapshot(
                cpuUsage: 11.0, cpuCores: mockCores, gpuUsage: 95.0,
                gpuHistory: mockHistory, uploadSpeed: 1024 * 150,
                downloadSpeed: 1024 * 1024 * 4.2, batteryPercent: 90,
                isPluggedIn: true, wattage: 28.0
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
        completion(SystemEntry(date: Date(), data: WidgetDataProvider.getSystemData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
        let entry = SystemEntry(date: Date(), data: WidgetDataProvider.getSystemData())
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// ==========================================
// MARK: - 1. 四合一原生圆环矩阵 (完全还原系统电池小组件风格)
// ==========================================
struct SystemOverviewWidget: Widget {
    let kind: String = "SystemOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemTimelineProvider()) { entry in
            SystemOverviewView(entry: entry)
        }
        .configurationDisplayName("全景状态矩阵")
        .description("采用 Apple 原生电池组件设计语言，聚合展示四大核心指标。")
        .supportedFamilies([.systemMedium])
    }
}

struct SystemOverviewView: View {
    var entry: SystemEntry

    var body: some View {
        HStack(spacing: 0) {
            // 1. CPU
            AppleBatteryRingCell(
                title: "CPU",
                value: "\(Int(entry.data.cpuUsage))%",
                icon: "cpu.fill",
                percent: entry.data.cpuUsage / 100.0,
                color: .orange
            )

            // 2. GPU
            AppleBatteryRingCell(
                title: "GPU",
                value: "\(Int(entry.data.gpuUsage))%",
                icon: "square.stack.3d.up.fill",
                percent: entry.data.gpuUsage / 100.0,
                color: .purple
            )

            // 3. 网络 (清楚标示 K/s 或 M/s，杜绝 0K 看成 OK)
            let down = WidgetDataProvider.formatSpeedUnit(entry.data.downloadSpeed)
            AppleBatteryRingCell(
                title: "网络",
                value: "\(down.value) \(down.unit == "MB/s" ? "M" : "K")",
                icon: "arrow.up.arrow.down",
                percent: min(1.0, entry.data.downloadSpeed / (1024 * 1024 * 8)),
                color: .blue
            )

            // 4. 电池
            AppleBatteryRingCell(
                title: "电池",
                value: "\(entry.data.batteryPercent)%",
                icon: entry.data.isPluggedIn ? "bolt.fill" : "battery.100",
                percent: Double(entry.data.batteryPercent) / 100.0,
                color: entry.data.batteryPercent > 20 ? .green : .red
            )
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            Color(NSColor.windowBackgroundColor)
        }
    }
}

// 还原原生系统电池圆环结构
struct AppleBatteryRingCell: View {
    let title: String
    let value: String
    let icon: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // 轨道底色
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 5.5)

                // 进度条
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, percent))))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // 内部中心图标
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 52, height: 52)

            // 下方文字：第一行大粗体数值，第二行灰色标题
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// ==========================================
// MARK: - 2. CPU 状态 (原生圆环 + 精致声谱条)
// ==========================================
struct CPUMonitorWidget: Widget {
    let kind: String = "CPUMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemTimelineProvider()) { entry in
            CPUWidgetView(entry: entry)
        }
        .configurationDisplayName("CPU 监控")
        .description("综合负荷仪表与多核活动频谱。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CPUWidgetView: View {
    var entry: SystemEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemSmall {
            // 小组件：大环原生仪表
            VStack(spacing: 4) {
                HStack {
                    Label("CPU", systemImage: "cpu.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(entry.data.cpuUsage > 70 ? "高负荷" : "正常")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(entry.data.cpuUsage > 70 ? .red : .secondary)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.18), lineWidth: 8)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, entry.data.cpuUsage / 100.0))))
                        .stroke(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: -2) {
                        Text("\(Int(entry.data.cpuUsage))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 74, height: 74)

                Spacer(minLength: 0)

                Text(entry.data.cpuCores.isEmpty ? "芯片运行中" : "\(entry.data.cpuCores.count) 核心集群")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .containerBackground(for: .widget) { Color(NSColor.windowBackgroundColor) }
        } else {
            // 中组件：左圆环 + 右多核平衡柱
            HStack(spacing: 20) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(Color.orange.opacity(0.18), lineWidth: 8)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, entry.data.cpuUsage / 100.0))))
                            .stroke(
                                Color.orange,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: -2) {
                            Text("\(Int(entry.data.cpuUsage))")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                            Text("%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 76, height: 76)

                    Text("CPU 综合")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(entry.data.cpuCores.count) 核心架构")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text(entry.data.cpuUsage > 70 ? "重载" : "稳定")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        let cores = entry.data.cpuCores.isEmpty ? [entry.data.cpuUsage] : entry.data.cpuCores
                        let count = CGFloat(cores.count)
                        let barWidth = max(4.0, (geo.size.width - (count - 1) * 3) / count)

                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(cores.enumerated()), id: \.offset) { _, usage in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.primary.opacity(0.06))
                                        .frame(width: barWidth, height: geo.size.height)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(usage > 75 ? Color.red : (usage > 40 ? Color.orange : Color.green))
                                        .frame(width: barWidth, height: max(3.0, geo.size.height * CGFloat(usage / 100.0)))
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .containerBackground(for: .widget) { Color(NSColor.windowBackgroundColor) }
        }
    }
}

// ==========================================
// MARK: - 3. GPU 监控 (平滑曲线图，杜绝断崖断裂)
// ==========================================
struct GPUTrendWidget: Widget {
    let kind: String = "GPUTrendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemTimelineProvider()) { entry in
            GPUTrendView(entry: entry)
        }
        .configurationDisplayName("GPU 状态")
        .description("Metal 图形核心实时负载与平滑波动曲线。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GPUTrendView: View {
    var entry: SystemEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.purple)
                    Text("GPU")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                Spacer()
                Text("\(Int(entry.data.gpuUsage))%")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.purple)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let history = cleanHistory(entry.data.gpuHistory, current: entry.data.gpuUsage, count: family == .systemSmall ? 18 : 32)
                let maxIndex = CGFloat(max(1, history.count - 1))
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (i, val) in history.enumerated() {
                            let x = (CGFloat(i) / maxIndex) * w
                            let y = h - (CGFloat(val / 100.0) * h)
                            if i == 0 { path.addLine(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.25), Color.purple.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        for (i, val) in history.enumerated() {
                            let x = (CGFloat(i) / maxIndex) * w
                            let y = h - (CGFloat(val / 100.0) * h)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        Color.purple,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .padding(13)
        .containerBackground(for: .widget) { Color(NSColor.windowBackgroundColor) }
    }

    // 平滑曲线填充：如果数据点少，使用首个有效数值填充，避免产生 0 到 97% 的生硬直角折断
    private func cleanHistory(_ list: [Double], current: Double, count: Int) -> [Double] {
        if list.isEmpty { return Array(repeating: current, count: count) }
        if list.count >= count { return Array(list.suffix(count)) }
        let fallback = list.first ?? current
        return Array(repeating: fallback, count: count - list.count) + list
    }
}

// ==========================================
// MARK: - 4. 实时网络吞吐 (测速卡片)
// ==========================================
struct NetworkMonitorWidget: Widget {
    let kind: String = "NetworkMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemTimelineProvider()) { entry in
            NetworkWidgetView(entry: entry)
        }
        .configurationDisplayName("网络速率")
        .description("实时显示吞吐流速。")
        .supportedFamilies([.systemSmall])
    }
}

struct NetworkWidgetView: View {
    var entry: SystemEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("网络", systemImage: "network")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
            }

            Spacer(minLength: 0)

            let down = WidgetDataProvider.formatSpeedUnit(entry.data.downloadSpeed)
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(down.value)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(down.unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Text("实时下载")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.4)

            let up = WidgetDataProvider.formatSpeedUnit(entry.data.uploadSpeed)
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                Text("上传")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(up.value) \(up.unit)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .padding(13)
        .containerBackground(for: .widget) { Color(NSColor.windowBackgroundColor) }
    }
}

// ==========================================
// MARK: - Widget Bundle 入口
// ==========================================
@main
struct MacMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        SystemOverviewWidget()
        CPUMonitorWidget()
        GPUTrendWidget()
        NetworkMonitorWidget()
    }
}
