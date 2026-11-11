import XCTest
@testable import PerfLens

final class MetricMathTests: XCTestCase {

    func testLaunchTimelineSplitsPhases() {
        let metrics = LaunchTimeline.make(
            processStart: 100.0,
            bootstrap: 100.2,
            didFinishLaunching: 100.5,
            firstFrame: 100.7,
            kind: .cold
        )

        XCTAssertEqual(metrics.preMain ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.initialization ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(metrics.firstFrameDelay ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.total ?? -1, 0.7, accuracy: 0.0001)
        XCTAssertEqual(metrics.kind, .cold)
    }

    func testLaunchTimelineToleratesMissingProcessStart() {
        let metrics = LaunchTimeline.make(
            processStart: nil,
            bootstrap: 100.2,
            didFinishLaunching: 100.5,
            firstFrame: 100.7,
            kind: .warm
        )

        XCTAssertNil(metrics.preMain)
        XCTAssertNil(metrics.total)
        XCTAssertEqual(metrics.initialization ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(metrics.firstFrameDelay ?? -1, 0.2, accuracy: 0.0001)
    }

    func testLaunchTimelineOmitsPhasesWithoutDidFinishLaunching() {
        let metrics = LaunchTimeline.make(
            processStart: 100.0,
            bootstrap: 100.2,
            didFinishLaunching: nil,
            firstFrame: 101.0,
            kind: .warm
        )

        XCTAssertNil(metrics.initialization)
        XCTAssertNil(metrics.firstFrameDelay)
        XCTAssertEqual(metrics.total ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.preMain ?? -1, 0.2, accuracy: 0.0001)
    }

    func testDroppedFramesIgnoresNormalFrame() {
        XCTAssertEqual(
            FrameDropCounter.droppedFrames(frameDuration: 0.016, expectedDuration: 0.016),
            0
        )
    }

    func testDroppedFramesCountsLateFrames() {
        XCTAssertEqual(
            FrameDropCounter.droppedFrames(frameDuration: 0.050, expectedDuration: 0.016),
            2
        )
    }
}
