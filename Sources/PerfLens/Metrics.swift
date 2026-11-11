import Foundation

/// 一次启动的性能数据。时间单位均为秒。
public struct LaunchMetrics: Codable, Equatable, Sendable {

    public enum Kind: String, Codable, Sendable {
        /// 本次进程中观测到了 didFinishLaunching，视为冷启动。
        case cold
        /// SDK 接入时进程已经在运行，视为热启动。
        case warm
    }

    /// 进程启动到模块构造函数的耗时，近似 pre-main。
    public let preMain: TimeInterval?
    /// 构造函数到 didFinishLaunching 的耗时。
    public let initialization: TimeInterval?
    /// didFinishLaunching 到首帧事务完成的耗时。
    public let firstFrameDelay: TimeInterval?
    /// 进程启动到首帧完成的总耗时。
    public let total: TimeInterval?
    public let kind: Kind
    public let capturedAt: Date

    public init(
        preMain: TimeInterval?,
        initialization: TimeInterval?,
        firstFrameDelay: TimeInterval?,
        total: TimeInterval?,
        kind: Kind,
        capturedAt: Date
    ) {
        self.preMain = preMain
        self.initialization = initialization
        self.firstFrameDelay = firstFrameDelay
        self.total = total
        self.kind = kind
        self.capturedAt = capturedAt
    }
}

/// 一次主线程卡顿事件。
public struct HangEvent: Identifiable, Codable, Equatable, Sendable {

    public let id: UUID
    public let timestamp: Date
    /// 从心跳发出到主线程恢复响应的完整间隔，即本次卡顿时长。
    public let duration: TimeInterval
    /// 主线程原始栈地址，需要 dSYM 才能符号化。
    public let stack: [UInt]

    public init(id: UUID = UUID(), timestamp: Date, duration: TimeInterval, stack: [UInt]) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.stack = stack
    }

    public var durationMilliseconds: Double {
        duration * 1000
    }
}

/// 1 秒窗口内的帧率采样。
public struct FrameSample: Identifiable, Codable, Equatable, Sendable {

    public let id: UUID
    public let timestamp: Date
    public let fps: Double
    public let droppedFrames: Int

    public init(id: UUID = UUID(), timestamp: Date, fps: Double, droppedFrames: Int) {
        self.id = id
        self.timestamp = timestamp
        self.fps = fps
        self.droppedFrames = droppedFrames
    }
}
