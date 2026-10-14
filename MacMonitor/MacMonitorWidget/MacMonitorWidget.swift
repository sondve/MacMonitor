import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 自适应色彩引擎
struct AdaptiveWidgetPalette {
    let opacity: Double

    /// < 45% 为透明液态玻璃模式 (透出真实桌面壁纸 + 纯白高亮文字)
    /// >= 45% 为纯白卡片模式 (纯白瓷底板 + 深色炭黑文字)
    var isGlassMode: Bool { opacity < 0.45 }

    var primaryText: Color {
        isGlassMode ? .white : Color(red: 0.10, green: 0.12, blue: 0.16)
    }

    var secondaryText: Color {
        isGlassMode ? .white.opacity(0.85) : Color(red: 0.42, green: 0.46, blue: 0.52)
    }

    var trackFill: Color {
        isGlassMode ? .white.opacity(0.24) : Color.black.opacity(0.07)
    }

    var dividerColor: Color {
        isGlassMode ? .white.opacity(0.22) : Color.black.opacity(0.08)
    }

    var cpuCyan: Color {
        isGlassMode
            ? Color(red: 0.25, green: 0.96, blue: 0.85)
            : Color(red: 0.05, green: 0.70, blue: 0.60)
    }

    var gpuSkyBlue: Color {
        isGlassMode
            ? Color(red: 0.40, green: 0.88, blue: 1.00)
            : Color(red: 0.00, green: 0.52, blue: 0.95)
    }

    var gpuDeepBlue: Color {
        isGlassMode
            ? Color(red: 0.28, green: 0.74, blue: 1.00)
            : Color(red: 0.10, green: 0.42, blue: 0.88)
    }

    var memPurple: Color {
        isGlassMode
            ? Color(red: 0.82, green: 0.62, blue: 1.00)
            : Color(red: 0.54, green: 0.30, blue: 0.90)
    }

    var batteryGreen: Color {
        isGlassMode
            ? Color(red: 0.24, green: 0.95, blue: 0.46)
            : Color(red: 0.14, green: 0.76, blue: 0.34)
    }

    func matrixDotColor(for ratio: Double) -> Color {
        if ratio > 0.65 {
            return cpuCyan
        } else if ratio > 0.30 {
            return gpuSkyBlue
        } else {
            return gpuDeepBlue
        }
    }
}

// MARK: - 全量硬件指标 Entry
struct SystemMonitorEntry: TimelineEntry {
    let date: Date
    let cpuUsage: Double
    let cpuCores: [Double]
    let gpuUsage: Double
    let gpuHistory: [Double]
    let memUsage: Double
    let memUsedStr: String
    let memSwapStr: String
    let diskUsage: Double
    let diskFreeStr: String
    let diskReadStr: String
    let diskWriteStr: String
    let netUpload: Double
    let netDownload: Double
    let netUploadStr: String
    let netDownloadStr: String
    let netLocalIP: String
    let batteryPercentage: Int
    let isPluggedIn: Bool
    let batteryWattage: Double
    let batteryTemp: Double
    let backgroundOpacity: Double
}

// MARK: - Timeline Provider
struct SystemMonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> SystemMonitorEntry {
        SystemMonitorEntry(
            date: Date(),
            cpuUsage: 0.15,
            cpuCores: [22, 18, 35, 14, 65, 52, 40, 28, 19, 45, 60, 30, 25, 15],
            gpuUsage: 0.24,
            gpuHistory: [12, 15, 28, 45, 38, 22, 18, 55, 62, 48, 30, 25, 42, 58, 36, 20, 15, 32, 48, 32],
            memUsage: 0.23,
            memUsedStr: "11.1 / 48 GB",
            memSwapStr: "0 MB",
            diskUsage: 0.85,
            diskFreeStr: "61 GB",
            diskReadStr: "12.4 MB/s",
            diskWriteStr: "4.2 MB/s",
            netUpload: 12 * 1024,
            netDownload: 1.2 * 1024 * 1024,
            netUploadStr: "12 KB/s",
            netDownloadStr: "1.2 MB/s",
            netLocalIP: "172.20.10.2",
            batteryPercentage: 100,
            isPluggedIn: true,
            batteryWattage: 24.5,
            batteryTemp: 30.3,
            backgroundOpacity: WidgetConfig.defaultOpacity
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemMonitorEntry) -> Void) {
        completion(fetchCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemMonitorEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 60, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> SystemMonitorEntry {
        let p = WidgetConfig.loadPayload()
        let cores = p.cpuCores.isEmpty ? [p.cpuUsage, p.cpuUsage, p.cpuUsage, p.cpuUsage] : p.cpuCores
        let gpuHist = p.gpuHistory.isEmpty ? [p.gpuUsage] : p.gpuHistory

        return SystemMonitorEntry(
            date: Date(),
            cpuUsage: min(1.0, max(0.0, p.cpuUsage / 100.0)),
            cpuCores: cores,
            gpuUsage: min(1.0, max(0.0, p.gpuUsage / 100.0)),
            gpuHistory: gpuHist,
            memUsage: min(1.0, max(0.0, p.memUsage / 100.0)),
            memUsedStr: p.memUsedStr,
            memSwapStr: p.memSwapStr,
            diskUsage: min(1.0, max(0.0, p.diskUsage / 100.0)),
            diskFreeStr: p.diskFreeStr,
            diskReadStr: p.diskReadStr,
            diskWriteStr: p.diskWriteStr,
            netUpload: p.netUpload,
            netDownload: p.netDownload,
            netUploadStr: p.netUploadStr,
            netDownloadStr: p.netDownloadStr,
            netLocalIP: p.netLocalIP,
            batteryPercentage: p.batteryPercent,
            isPluggedIn: p.batteryPlugged,
            batteryWattage: p.batteryWattage,
            batteryTemp: p.batteryTemp > 0 ? p.batteryTemp : 29.0,
            backgroundOpacity: min(1.0, max(0.0, p.opacity))
        )
    }
}

// MARK: - 极速单节点 Canvas 组件 1：GPU 点阵瀑布流
struct WidgetGPUDotMatrix: View {
    let history: [Double]
    let columns: Int
    let rows: Int
    let palette: AdaptiveWidgetPalette

    var body: some View {
        Canvas { context, size in
            let padded: [Double]
            if history.count >= columns {
                padded = Array(history.suffix(columns))
            } else {
                padded = Array(repeating: 0.0, count: columns - history.count) + history
            }

            let hSpacing: CGFloat = 2.4
            let vSpacing: CGFloat = 1.8
            let cellW = max(1.5, (size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns))
            let cellH = max(1.5, (size.height - CGFloat(rows - 1) * vSpacing) / CGFloat(rows))

            for colIdx in 0..<columns {
                let usage = padded[colIdx]
                let x = CGFloat(colIdx) * (cellW + hSpacing)

                for rowIdx in 0..<rows {
                    let ratio = Double(rowIdx) / Double(rows)
                    let threshold = ratio * 100.0
                    let isLit = usage > 0.5 && usage >= threshold

                    let invertedRow = rows - 1 - rowIdx
                    let y = CGFloat(invertedRow) * (cellH + vSpacing)
                    let rect = CGRect(x: x, y: y, width: cellW, height: cellH)
                    let path = Path(roundedRect: rect, cornerRadius: 0.9)

                    let color = isLit ? palette.matrixDotColor(for: ratio) : palette.trackFill
                    context.fill(path, with: .color(color))
                }
            }
        }
    }
}

// MARK: - 极速单节点 Canvas 组件 2：CPU 多核分段柱
struct WidgetCPUSegmentedBars: View {
    let cores: [Double]
    let maxBars: Int
    let segments: Int
    let palette: AdaptiveWidgetPalette

    var body: some View {
        Canvas { context, size in
            let displayCores = Array(cores.prefix(maxBars))
            let count = max(1, displayCores.count)
            let hSpacing: CGFloat = 3.5
            let vSpacing: CGFloat = 1.5
            let barW = max(2.0, (size.width - CGFloat(count - 1) * hSpacing) / CGFloat(count))
            let segH = max(1.5, (size.height - CGFloat(segments - 1) * vSpacing) / CGFloat(segments))
            let eCoreLimit = max(2, count / 3)

            for idx in 0..<count {
                let usage = displayCores[idx]
                let isECore = idx < eCoreLimit
                let activeColor = isECore ? palette.cpuCyan : palette.gpuSkyBlue
                let x = CGFloat(idx) * (barW + hSpacing)

                for segIdx in 0..<segments {
                    let threshold = (Double(segIdx) / Double(segments)) * 100.0
                    let isLit = usage > 0.5 && usage >= threshold
                    let invertedSeg = segments - 1 - segIdx
                    let y = CGFloat(invertedSeg) * (segH + vSpacing)
                    let rect = CGRect(x: x, y: y, width: barW, height: segH)
                    let path = Path(roundedRect: rect, cornerRadius: 0.8)

                    context.fill(path, with: .color(isLit ? activeColor : palette.trackFill))
                }
            }
        }
    }
}

// MARK: - 组件 3：圆环仪表
struct WidgetNativeRingGauge: View {
    let title: String
    let icon: String
    let value: Double
    let ringColor: Color
    let valueText: String
    let palette: AdaptiveWidgetPalette

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(palette.trackFill, lineWidth: 6.0)
                    .frame(width: 54, height: 54)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.03, value))))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 6.0, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ringColor)
            }

            VStack(spacing: 1.5) {
                Text(valueText)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 1. 专项小组件：GPU 点阵瀑布流 (Small & Medium)
struct GPUDedicatedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var envFamily
    var entry: SystemMonitorEntry

    private var palette: AdaptiveWidgetPalette {
        AdaptiveWidgetPalette(opacity: entry.backgroundOpacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Image(systemName: "display")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.gpuSkyBlue)

                    Text("GPU")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer(minLength: 4)

                Text("\(Int(entry.gpuUsage * 100))%")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.gpuSkyBlue)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            WidgetGPUDotMatrix(
                history: entry.gpuHistory,
                columns: envFamily == .systemSmall ? 18 : 38,
                rows: 15,
                palette: palette
            )
        }
        .padding(14)
        .liquidGlassSurface(opacity: entry.backgroundOpacity)
        .containerBackground(for: .widget) {
            AdaptiveGlassBackground(opacityFactor: entry.backgroundOpacity)
        }
    }
}

// MARK: - 2. 专项小组件：CPU 多核频谱视图 (Small & Medium)
struct CPUDedicatedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var envFamily
    var entry: SystemMonitorEntry

    private var palette: AdaptiveWidgetPalette {
        AdaptiveWidgetPalette(opacity: entry.backgroundOpacity)
    }

    var body: some View {
        Group {
            if envFamily == .systemSmall {
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(palette.cpuCyan)
                            Text("CPU")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .stroke(palette.trackFill, lineWidth: 7)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.03, entry.cpuUsage)))
                            .stroke(
                                LinearGradient(colors: [palette.cpuCyan, palette.gpuSkyBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 72, height: 72)

                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(Int(entry.cpuUsage * 100))")
                                .font(.system(size: 21, weight: .heavy, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()
                            Text("%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.cpuCyan)
                        }
                    }

                    Spacer(minLength: 0)

                    Text("\(entry.cpuCores.count) 核心集群")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(palette.trackFill, lineWidth: 6.5)
                                .frame(width: 68, height: 68)
                            Circle()
                                .trim(from: 0, to: CGFloat(max(0.03, entry.cpuUsage)))
                                .stroke(
                                    LinearGradient(colors: [palette.cpuCyan, palette.gpuSkyBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 68, height: 68)

                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(Int(entry.cpuUsage * 100))")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(palette.primaryText)
                                    .monospacedDigit()
                                Text("%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(palette.cpuCyan)
                            }
                        }

                        Text("CPU 综合")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(width: 74)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(entry.cpuCores.count) 核心架构 (E/P 核)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)
                            Spacer()
                        }

                        WidgetCPUSegmentedBars(
                            cores: entry.cpuCores,
                            maxBars: 14,
                            segments: 13,
                            palette: palette
                        )
                    }
                }
            }
        }
        .padding(14)
        .liquidGlassSurface(opacity: entry.backgroundOpacity)
        .containerBackground(for: .widget) {
            AdaptiveGlassBackground(opacityFactor: entry.backgroundOpacity)
        }
    }
}

// MARK: - 3. 独立网络速率小组件 (Small)
struct NetworkDedicatedWidgetEntryView: View {
    var entry: SystemMonitorEntry

    private var palette: AdaptiveWidgetPalette {
        AdaptiveWidgetPalette(opacity: entry.backgroundOpacity)
    }

    private func splitSpeed(_ bytes: Double) -> (value: String, unit: String) {
        if bytes >= 1024 * 1024 {
            return (String(format: "%.1f", bytes / (1024 * 1024)), "MB/s")
        } else {
            return (String(format: "%.0f", max(0, bytes / 1024)), "KB/s")
        }
    }

    var body: some View {
        let down = splitSpeed(entry.netDownload)
        let up = splitSpeed(entry.netUpload)

        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.gpuSkyBlue)
                    Text("网络")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.gpuSkyBlue)
                    Text(down.value)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .monospacedDigit()
                    Text(down.unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                }
                Text("实时下载")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            Divider().overlay(palette.dividerColor)

            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.cpuCyan)
                Text("上传")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(up.value) \(up.unit)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
            }
        }
        .padding(14)
        .liquidGlassSurface(opacity: entry.backgroundOpacity)
        .containerBackground(for: .widget) {
            AdaptiveGlassBackground(opacityFactor: entry.backgroundOpacity)
        }
    }
}

// MARK: - 4. 全景综合小组件视图 (Small / Medium / Large)
struct MacMonitorWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: SystemMonitorEntry

    private var palette: AdaptiveWidgetPalette {
        AdaptiveWidgetPalette(opacity: entry.backgroundOpacity)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallUnifiedWidgetView(entry: entry, palette: palette)
            case .systemLarge:
                LargeUnifiedWidgetView(entry: entry, palette: palette)
            default:
                MediumUnifiedWidgetView(entry: entry, palette: palette)
            }
        }
        .padding(14)
        .liquidGlassSurface(opacity: entry.backgroundOpacity)
        .containerBackground(for: .widget) {
            AdaptiveGlassBackground(opacityFactor: entry.backgroundOpacity)
        }
    }
}

// 小尺寸综合
struct SmallUnifiedWidgetView: View {
    var entry: SystemMonitorEntry
    let palette: AdaptiveWidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.gpuSkyBlue)
                Text("MacMonitor")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Spacer()
            }

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                SegmentedMetricBarRow(title: "CPU", value: entry.cpuUsage, color: palette.cpuCyan, palette: palette)
                SegmentedMetricBarRow(title: "GPU", value: entry.gpuUsage, color: palette.gpuSkyBlue, palette: palette)
                SegmentedMetricBarRow(title: "MEM", value: entry.memUsage, color: palette.memPurple, palette: palette)
            }

            Spacer(minLength: 0)

            HStack {
                Image(systemName: entry.isPluggedIn ? "bolt.fill" : "battery.100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(entry.isPluggedIn ? palette.batteryGreen : palette.gpuSkyBlue)
                Text("\(entry.batteryPercentage)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text(String(format: "%.1fW", entry.batteryWattage))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

// 中尺寸综合
struct MediumUnifiedWidgetView: View {
    var entry: SystemMonitorEntry
    let palette: AdaptiveWidgetPalette

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(palette.gpuSkyBlue)
                    Text("MacMonitor 全景矩阵")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text("↑\(entry.netUploadStr) · ↓\(entry.netDownloadStr)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                WidgetNativeRingGauge(
                    title: "CPU",
                    icon: "cpu",
                    value: entry.cpuUsage,
                    ringColor: palette.cpuCyan,
                    valueText: "\(Int(entry.cpuUsage * 100))%",
                    palette: palette
                )

                WidgetNativeRingGauge(
                    title: "GPU",
                    icon: "display",
                    value: entry.gpuUsage,
                    ringColor: palette.gpuSkyBlue,
                    valueText: "\(Int(entry.gpuUsage * 100))%",
                    palette: palette
                )

                WidgetNativeRingGauge(
                    title: "内存",
                    icon: "memorychip",
                    value: entry.memUsage,
                    ringColor: palette.memPurple,
                    valueText: "\(Int(entry.memUsage * 100))%",
                    palette: palette
                )

                WidgetNativeRingGauge(
                    title: "电池",
                    icon: entry.isPluggedIn ? "bolt.fill" : "battery.100",
                    value: Double(entry.batteryPercentage) / 100.0,
                    ringColor: palette.batteryGreen,
                    valueText: "\(entry.batteryPercentage)%",
                    palette: palette
                )
            }

            Spacer(minLength: 0)
        }
    }
}

// 大尺寸全景工作台
struct LargeUnifiedWidgetView: View {
    var entry: SystemMonitorEntry
    let palette: AdaptiveWidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.gpuSkyBlue)
                    Text("MacMonitor 硬件工作台")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text(entry.netLocalIP)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }

            Divider().overlay(palette.dividerColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CPU 多核活跃度 (\(entry.cpuCores.count) 核心)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                    Spacer()
                    Text("\(Int(entry.cpuUsage * 100))%")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(palette.cpuCyan)
                }

                WidgetCPUSegmentedBars(
                    cores: entry.cpuCores,
                    maxBars: 14,
                    segments: 11,
                    palette: palette
                )
                .frame(height: 52)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("GPU 历史负载瀑布流")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                    Spacer()
                    Text("\(Int(entry.gpuUsage * 100))%")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(palette.gpuSkyBlue)
                }

                WidgetGPUDotMatrix(
                    history: entry.gpuHistory,
                    columns: 36,
                    rows: 12,
                    palette: palette
                )
                .frame(height: 72)
            }

            HStack(spacing: 14) {
                SegmentedMetricBarRow(
                    title: "MEM (\(entry.memUsedStr))",
                    value: entry.memUsage,
                    color: palette.memPurple,
                    palette: palette
                )
                SegmentedMetricBarRow(
                    title: "DSK (余 \(entry.diskFreeStr))",
                    value: entry.diskUsage,
                    color: palette.gpuSkyBlue,
                    palette: palette
                )
            }

            Divider().overlay(palette.dividerColor)

            HStack {
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(palette.cpuCyan)
                        Text(entry.netUploadStr)
                            .foregroundStyle(palette.primaryText)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(palette.gpuSkyBlue)
                        Text(entry.netDownloadStr)
                            .foregroundStyle(palette.primaryText)
                    }
                }
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: entry.isPluggedIn ? "bolt.fill" : "battery.100")
                        .font(.system(size: 10.5))
                        .foregroundStyle(entry.isPluggedIn ? palette.batteryGreen : .orange)
                    Text("\(entry.batteryPercentage)% · \(String(format: "%.1fW", entry.batteryWattage)) · \(String(format: "%.1f°C", entry.batteryTemp))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.primaryText)
                }
            }
        }
    }
}

// MARK: - 极速单节点 Canvas 分段进度条
struct SegmentedMetricBarRow: View {
    let title: String
    let value: Double
    let color: Color
    let palette: AdaptiveWidgetPalette
    private let totalSegments = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
            }

            Canvas { context, size in
                let spacing: CGFloat = 2.0
                let segW = max(1.5, (size.width - CGFloat(totalSegments - 1) * spacing) / CGFloat(totalSegments))
                for idx in 0..<totalSegments {
                    let threshold = Double(idx) / Double(totalSegments)
                    let isLit = value > 0.01 && value >= threshold
                    let x = CGFloat(idx) * (segW + spacing)
                    let rect = CGRect(x: x, y: 0, width: segW, height: size.height)
                    let path = Path(roundedRect: rect, cornerRadius: 1.2)
                    context.fill(path, with: .color(isLit ? color : palette.trackFill))
                }
            }
            .frame(height: 5.5)
        }
    }
}

// MARK: - WidgetBundle 注册入口
struct MacMonitorUnifiedPaddingWrapper: Widget {
    let kind: String = "MacMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorProvider()) { entry in
            MacMonitorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MacMonitor 全景监控")
        .description("实时监控 Apple Silicon CPU、GPU、内存、磁盘、网络与电池状态。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

struct MacMonitorGPUWidget: Widget {
    let kind: String = "MacMonitorGPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorProvider()) { entry in
            GPUDedicatedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GPU 点阵瀑布流")
        .description("极速 Canvas 渲染的 Metal GPU 历史负载点阵矩阵。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

struct MacMonitorCPUWidget: Widget {
    let kind: String = "MacMonitorCPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorProvider()) { entry in
            CPUDedicatedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CPU 多核均衡器")
        .description("综合负荷圆环仪表与 P/E 多核分段 LED 频谱。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

struct MacMonitorNetworkWidget: Widget {
    let kind: String = "NetworkMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorProvider()) { entry in
            NetworkDedicatedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("网络实时速率")
        .description("实时显示上行与下行吞吐流速。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

@main
struct MacMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacMonitorUnifiedPaddingWrapper()
        MacMonitorGPUWidget()
        MacMonitorCPUWidget()
        MacMonitorNetworkWidget()
    }
}
