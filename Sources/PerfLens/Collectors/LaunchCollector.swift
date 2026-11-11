import QuartzCore
import UIKit

/// 启动采集：进程启动 → 模块构造函数 → didFinishLaunching → 首帧。
@MainActor
final class LaunchCollector {

    private let onFinish: (LaunchMetrics) -> Void
    private let processStart = ProcessClock.processStartUptime()
    private let bootstrap = ProcessClock.bootstrapUptime()

    private var startUptime: TimeInterval = 0
    private var didFinishUptime: TimeInterval?
    private var observedDidFinishLaunching = false
    private var observer: NSObjectProtocol?
    private var fallback: DispatchWorkItem?
    private var finished = false

    init(onFinish: @escaping (LaunchMetrics) -> Void) {
        self.onFinish = onFinish
    }

    func start() {
        startUptime = ProcessClock.uptime()

        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let uptime = ProcessClock.uptime()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observedDidFinishLaunching = true
                self.markDidFinishLaunching(at: uptime)
            }
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.fallback = nil
            if let observer = self.observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            // 没等到 didFinishLaunching，说明 SDK 是在启动完成后才接入的。
            self.scheduleFirstFrame()
        }
        fallback = workItem

        // didFinishLaunching 一定会发生在进程启动后的几秒内；按进程已运行的时长补足窗口，
        // 避免慢设备上冷启动还没发出通知就被误判成热接入。
        let processUptime = max(0, startUptime - (processStart ?? startUptime))
        let delay: TimeInterval = max(0.2, Self.launchWindow - processUptime)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// 从进程启动算起，等待 didFinishLaunching 的窗口。
    private static let launchWindow: TimeInterval = 5.0

    func stop() {
        finished = true
        teardown()
    }

    private func markDidFinishLaunching(at uptime: TimeInterval) {
        guard didFinishUptime == nil else { return }

        didFinishUptime = uptime
        fallback?.cancel()
        fallback = nil

        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }

        scheduleFirstFrame()
    }

    private func scheduleFirstFrame() {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.finish()
        }
        CATransaction.commit()

        // 兜底：事务回调没有触发时也能产出数据。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true

        let metrics = LaunchTimeline.make(
            processStart: processStart,
            bootstrap: bootstrap,
            didFinishLaunching: didFinishUptime,
            firstFrame: ProcessClock.uptime(),
            kind: observedDidFinishLaunching ? .cold : .warm
        )
        onFinish(metrics)
        teardown()
    }

    private func teardown() {
        fallback?.cancel()
        fallback = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
