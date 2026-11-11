import Foundation

/// 配置项保持最小集合，默认值对应 README 中的口径说明。
public struct PerfLensConfig: Sendable {

    /// 主线程阻塞超过该时长记为一次卡顿。
    public var hangThreshold: TimeInterval
    /// 心跳轮询间隔，越小越灵敏，开销越高。
    public var hangPollInterval: TimeInterval
    /// 启动后跳过卡顿检测的时长，避免把首帧渲染占用误判成卡顿。
    public var hangGracePeriod: TimeInterval
    /// 内存中保留的卡顿事件上限。
    public var maxHangEvents: Int
    /// 内存中保留的帧率采样上限。
    public var maxFrameSamples: Int
    /// 单次栈采样的最大帧数。
    public var stackFrameLimit: Int

    public init(
        hangThreshold: TimeInterval = 0.08,
        hangPollInterval: TimeInterval = 0.05,
        hangGracePeriod: TimeInterval = 1.0,
        maxHangEvents: Int = 50,
        maxFrameSamples: Int = 120,
        stackFrameLimit: Int = 64
    ) {
        self.hangThreshold = hangThreshold
        self.hangPollInterval = hangPollInterval
        self.hangGracePeriod = hangGracePeriod
        self.maxHangEvents = maxHangEvents
        self.maxFrameSamples = maxFrameSamples
        self.stackFrameLimit = stackFrameLimit
    }
}
