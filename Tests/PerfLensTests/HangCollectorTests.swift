import XCTest
@testable import PerfLens

final class HangCollectorTests: XCTestCase {

    func testDetectsBlockedMainThreadAndCapturesStack() {
        let detected = expectation(description: "hang detected")
        var captured: HangEvent?

        let collector = HangCollector(
            config: PerfLensConfig(hangThreshold: 0.05, hangPollInterval: 0.02, hangGracePeriod: 0)
        ) { event in
            captured = event
            detected.fulfill()
        }

        collector.start()
        Thread.sleep(forTimeInterval: 0.3)
        wait(for: [detected], timeout: 2)
        collector.stop()

        XCTAssertNotNil(captured)
        // 结算后的时长覆盖整段阻塞（0.3s），而不是判定阈值附近的轮询间隔。
        XCTAssertGreaterThanOrEqual(captured?.duration ?? 0, 0.25)
        XCTAssertFalse(captured?.stack.isEmpty ?? true)
    }

    func testDoesNotReportWhenMainThreadIsIdle() {
        let falsePositive = expectation(description: "no hang while idle")
        falsePositive.isInverted = true

        let collector = HangCollector(
            config: PerfLensConfig(hangThreshold: 0.2, hangPollInterval: 0.02, hangGracePeriod: 0)
        ) { _ in
            falsePositive.fulfill()
        }

        collector.start()
        wait(for: [falsePositive], timeout: 0.8)
        collector.stop()
    }

    func testSkipsBlockWithinGracePeriod() {
        let detectedDuringGrace = expectation(description: "no hang inside grace period")
        detectedDuringGrace.isInverted = true

        let collector = HangCollector(
            config: PerfLensConfig(hangThreshold: 0.05, hangPollInterval: 0.02, hangGracePeriod: 1.0)
        ) { _ in
            detectedDuringGrace.fulfill()
        }

        collector.start()
        Thread.sleep(forTimeInterval: 0.4)
        wait(for: [detectedDuringGrace], timeout: 0.3)
        collector.stop()
    }
}
