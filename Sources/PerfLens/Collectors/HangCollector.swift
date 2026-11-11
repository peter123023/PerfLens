import Darwin
import Foundation

/// 卡顿采集：后台心跳 ping 主线程，超时后挂起主线程并读取调用栈。
final class HangCollector {

    private let config: PerfLensConfig
    private let onHang: (HangEvent) -> Void
    private let queue = DispatchQueue(label: "dev.perflens.hang", qos: .utility)
    private let lock = NSLock()

    private var timer: DispatchSourceTimer?
    private var awaitingResponse = false
    private var sentAt: TimeInterval = 0
    private var reportedInEpisode = false
    private var pendingEvent: HangEvent?
    private var mainThreadPort: mach_port_t = 0
    private var stackLow: UInt = 0
    private var stackHigh: UInt = 0
    private var isRunning = false
    private var startedAt: TimeInterval = 0

    init(config: PerfLensConfig, onHang: @escaping (HangEvent) -> Void) {
        self.config = config
        self.onHang = onHang
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startedAt = ProcessClock.uptime()

        if Thread.isMainThread {
            captureMainThreadInfo()
        } else {
            DispatchQueue.main.sync { [weak self] in
                self?.captureMainThreadInfo()
            }
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + config.hangPollInterval,
            repeating: config.hangPollInterval,
            leeway: .milliseconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        lock.lock()
        pendingEvent = nil
        lock.unlock()
    }

    private func captureMainThreadInfo() {
        let thread = pthread_self()
        mainThreadPort = pthread_mach_thread_np(thread)

        let top = UInt(bitPattern: pthread_get_stackaddr_np(thread))
        let size = UInt(pthread_get_stacksize_np(thread))
        stackHigh = top
        stackLow = top > size ? top - size : 0
    }

    private func tick() {
        let now = ProcessClock.uptime()
        // 启动阶段主线程本来就在忙于首帧渲染，交给启动指标衡量。
        guard now - startedAt >= config.hangGracePeriod else { return }

        lock.lock()
        // 上一次 ping 还没有被主线程回执，说明主线程被阻塞了；
        // 此时不能刷新 sentAt，否则阻塞时长永远只等于一个轮询间隔。
        let blockedFor = awaitingResponse ? now - sentAt : 0
        var shouldCapture = false
        if !awaitingResponse {
            // 同一时刻只允许一个未回执的 ping：主线程被阻塞时不会向主队列堆积回执。
            awaitingResponse = true
            sentAt = now
            DispatchQueue.main.async { [weak self] in
                self?.handlePingReply()
            }
        } else if blockedFor >= config.hangThreshold, !reportedInEpisode {
            reportedInEpisode = true
            shouldCapture = true
        }
        lock.unlock()

        guard shouldCapture else { return }

        // 栈必须在卡顿当下抓取；时长要等主线程回执后才能结算，这里先记下事件。
        let frames = ThreadSampler.capture(
            thread: mainThreadPort,
            stackLow: stackLow,
            stackHigh: stackHigh,
            limit: config.stackFrameLimit
        )
        lock.lock()
        pendingEvent = HangEvent(timestamp: Date(), duration: blockedFor, stack: frames)
        lock.unlock()
    }

    /// 主线程恢复响应后的结算：用「ping 发出 → 回执执行」的完整间隔作为卡顿时长。
    private func handlePingReply() {
        lock.lock()
        let pending = pendingEvent
        let elapsed = ProcessClock.uptime() - sentAt
        pendingEvent = nil
        awaitingResponse = false
        reportedInEpisode = false
        lock.unlock()

        guard let pending else { return }
        onHang(
            HangEvent(
                id: pending.id,
                timestamp: pending.timestamp,
                duration: max(pending.duration, elapsed),
                stack: pending.stack
            )
        )
    }
}
