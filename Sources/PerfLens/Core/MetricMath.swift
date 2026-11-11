import Foundation

/// 把各阶段时间点换算成对外指标，独立成纯函数便于测试。
enum LaunchTimeline {

    static func make(
        processStart: TimeInterval?,
        bootstrap: TimeInterval?,
        didFinishLaunching: TimeInterval?,
        firstFrame: TimeInterval,
        kind: LaunchMetrics.Kind,
        capturedAt: Date = Date()
    ) -> LaunchMetrics {
        var preMain: TimeInterval?
        if let processStart, let bootstrap, bootstrap >= processStart {
            preMain = bootstrap - processStart
        }

        var initialization: TimeInterval?
        var firstFrameDelay: TimeInterval?
        if let didFinishLaunching {
            initialization = bootstrap.map { max(0, didFinishLaunching - $0) }
            firstFrameDelay = max(0, firstFrame - didFinishLaunching)
        }

        let total = processStart.map { max(0, firstFrame - $0) }

        return LaunchMetrics(
            preMain: preMain,
            initialization: initialization,
            firstFrameDelay: firstFrameDelay,
            total: total,
            kind: kind,
            capturedAt: capturedAt
        )
    }
}

/// 掉帧计算保持纯函数，避免显示口径分散在采集器里。
enum FrameDropCounter {

    static func droppedFrames(frameDuration: TimeInterval, expectedDuration: TimeInterval) -> Int {
        guard expectedDuration > 0, frameDuration > expectedDuration * 1.5 else {
            return 0
        }
        return max(1, Int((frameDuration / expectedDuration).rounded()) - 1)
    }
}
