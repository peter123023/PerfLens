import Charts
import SwiftUI

/// 开箱即用的性能看板，可以直接嵌进调试页。
public struct PerfDashboardView: View {

    @ObservedObject private var lens: PerfLens

    @MainActor
    public init() {
        _lens = ObservedObject(wrappedValue: PerfLens.shared)
    }

    @MainActor
    public init(lens: PerfLens) {
        _lens = ObservedObject(wrappedValue: lens)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LaunchCard(metrics: lens.launch)
                FrameCard(samples: lens.frames)
                HangCard(events: lens.hangs, threshold: lens.config.hangThreshold)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 卡片容器

private struct DashboardCard<Content: View>: View {

    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 启动

private struct LaunchCard: View {

    let metrics: LaunchMetrics?

    var body: some View {
        DashboardCard(title: "启动耗时", subtitle: "进程启动 → 首帧完成") {
            if let metrics {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(milliseconds(metrics.total))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("ms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(metrics.kind == .cold ? "冷启动" : "热启动")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 10) {
                    phaseRow("pre-main", metrics.preMain, total: metrics.total)
                    phaseRow("初始化", metrics.initialization, total: metrics.total)
                    phaseRow("首帧", metrics.firstFrameDelay, total: metrics.total)
                }
            } else {
                Text("等待首帧完成…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func phaseRow(_ title: String, _ duration: TimeInterval?, total: TimeInterval?) -> some View {
        let scale = max(total ?? 0, duration ?? 0, 0.001)
        let ratio = min(max((duration ?? 0) / scale, 0), 1)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(milliseconds(duration))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(3, proxy.size.width * ratio))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 帧率

private struct FrameCard: View {

    let samples: [FrameSample]

    var body: some View {
        DashboardCard(title: "帧率", subtitle: "1 秒窗口采样，共 \(samples.count) 个点") {
            if let latest = samples.last {
                HStack(spacing: 16) {
                    metric(value: String(format: "%.0f", latest.fps), unit: "FPS", label: "当前")
                    metric(value: "\(latest.droppedFrames)", unit: "帧", label: "窗口掉帧")
                }
                .padding(.bottom, 4)

                Chart(samples) { sample in
                    LineMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("FPS", sample.fps)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)

                    RuleMark(y: .value("60 FPS", 60.0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .chartYScale(domain: 0.0...max(120.0, samples.map(\.fps).max() ?? 120.0))
                .frame(height: 160)
            } else {
                Text("采样中，约 1 秒后出现第一个数据点…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 卡顿

private struct HangCard: View {

    let events: [HangEvent]
    let threshold: TimeInterval

    var body: some View {
        DashboardCard(
            title: "主线程卡顿",
            subtitle: "超过 \(Int(threshold * 1000)) ms 记为一次，最多展示最近 5 条"
        ) {
            if events.isEmpty {
                Text("暂未发现卡顿")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.suffix(5).reversed())) { event in
                        row(for: event)
                        if event.id != events.suffix(5).first?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(for event: HangEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%.0f ms", event.durationMilliseconds))
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.red)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("栈帧 \(event.stack.count) 层 · 需 dSYM 符号化")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let first = event.stack.first {
                    Text("0x" + String(first, radix: 16))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 工具

private func milliseconds(_ value: TimeInterval?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f", value * 1000)
}
