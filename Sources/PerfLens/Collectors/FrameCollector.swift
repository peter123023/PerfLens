import QuartzCore
import UIKit

/// 帧率采集：按 1 秒窗口统计回调帧数，并记录窗口内的掉帧数。
final class FrameCollector {

    private let onSample: (FrameSample) -> Void
    private var link: CADisplayLink?
    private var windowStart: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0
    private var droppedFrames = 0

    init(onSample: @escaping (FrameSample) -> Void) {
        self.onSample = onSample
    }

    func start() {
        guard link == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link

        windowStart = 0
        lastTimestamp = 0
        frameCount = 0
        droppedFrames = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc
    private func step(_ link: CADisplayLink) {
        let now = link.timestamp

        guard windowStart > 0 else {
            windowStart = now
            lastTimestamp = now
            return
        }

        let frameDuration = now - lastTimestamp
        let expectedDuration = max(link.targetTimestamp - link.timestamp, 1.0 / 120.0)
        droppedFrames += FrameDropCounter.droppedFrames(
            frameDuration: frameDuration,
            expectedDuration: expectedDuration
        )
        frameCount += 1
        lastTimestamp = now

        let window = now - windowStart
        guard window >= 1.0 else { return }

        let sample = FrameSample(
            timestamp: Date(),
            fps: Double(frameCount) / window,
            droppedFrames: droppedFrames
        )

        windowStart = now
        frameCount = 0
        droppedFrames = 0
        onSample(sample)
    }
}
