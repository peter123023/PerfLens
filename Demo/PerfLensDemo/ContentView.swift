import PerfLens
import SwiftUI

struct ContentView: View {

    // 便于截图和自动化验证时直接进入看板。
    @State private var selection = ProcessInfo.processInfo.arguments.contains("-perflens-dashboard") ? 1 : 0

    var body: some View {
        TabView(selection: $selection) {
            DemoHomeView()
                .tag(0)
                .tabItem {
                    Label("演示", systemImage: "play.circle")
                }

            NavigationStack {
                PerfDashboardView()
                    .navigationTitle("性能看板")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(1)
            .tabItem {
                Label("看板", systemImage: "chart.xyaxis.line")
            }
        }
    }
}

@MainActor
struct DemoHomeView: View {

    @ObservedObject private var lens = PerfLens.shared

    var body: some View {
        NavigationStack {
            List {
                Section("卡顿模拟") {
                    Button("阻塞主线程 300ms") {
                        Thread.sleep(forTimeInterval: 0.3)
                    }
                    Button("阻塞主线程 1s") {
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                }

                Section("重负载列表") {
                    Text("滚动下面的长列表，回到看板观察帧率与掉帧。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("长列表") {
                    ForEach(0..<200, id: \.self) { index in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text("\(index)")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Item \(index)")
                                    .font(.subheadline.weight(.medium))
                                Text("用于观察滚动帧率")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("当前状态") {
                    LabeledContent("卡顿事件", value: "\(lens.hangs.count)")
                    LabeledContent("帧率采样", value: "\(lens.frames.count)")
                }
            }
            .navigationTitle("PerfLens Demo")
        }
    }
}
