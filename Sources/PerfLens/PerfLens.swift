import Combine
import Foundation

/// 对外唯一入口。默认在 App init 中调用 start，即可完成三个采集器的装配。
@MainActor
public final class PerfLens: ObservableObject {

    public static let shared = PerfLens()

    @Published public private(set) var launch: LaunchMetrics?
    @Published public private(set) var hangs: [HangEvent] = []
    @Published public private(set) var frames: [FrameSample] = []

    public private(set) var config = PerfLensConfig()

    private var launchCollector: LaunchCollector?
    private var hangCollector: HangCollector?
    private var frameCollector: FrameCollector?
    private var hangBuffer = RingBuffer<HangEvent>(capacity: 1)
    private var frameBuffer = RingBuffer<FrameSample>(capacity: 1)
    private var isRunning = false

    private init() {}

    public static func start(config: PerfLensConfig = .init()) {
        shared.start(config: config)
    }

    public func start(config: PerfLensConfig = .init()) {
        guard !isRunning else { return }
        isRunning = true
        self.config = config
        hangBuffer = RingBuffer(capacity: config.maxHangEvents)
        frameBuffer = RingBuffer(capacity: config.maxFrameSamples)
        hangs = []
        frames = []

        let launchCollector = LaunchCollector { [weak self] metrics in
            self?.launch = metrics
        }
        launchCollector.start()
        self.launchCollector = launchCollector

        let hangCollector = HangCollector(config: config) { [weak self] event in
            guard let self else { return }
            self.hangBuffer.append(event)
            self.hangs = self.hangBuffer.elements
        }
        hangCollector.start()
        self.hangCollector = hangCollector

        let frameCollector = FrameCollector { [weak self] sample in
            guard let self else { return }
            self.frameBuffer.append(sample)
            self.frames = self.frameBuffer.elements
        }
        frameCollector.start()
        self.frameCollector = frameCollector
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        hangCollector?.stop()
        hangCollector = nil
        frameCollector?.stop()
        frameCollector = nil
        launchCollector?.stop()
        launchCollector = nil
    }

    public func reset() {
        launch = nil
        hangBuffer.removeAll()
        frameBuffer.removeAll()
        hangs = []
        frames = []
    }
}
