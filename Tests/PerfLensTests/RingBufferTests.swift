import XCTest
@testable import PerfLens

final class RingBufferTests: XCTestCase {

    func testKeepsElementsInOrderBeforeWrapping() {
        var buffer = RingBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)

        XCTAssertEqual(buffer.elements, [1, 2])
        XCTAssertEqual(buffer.count, 2)
    }

    func testOverwritesOldestElementWhenFull() {
        var buffer = RingBuffer<Int>(capacity: 3)

        [1, 2, 3, 4, 5].forEach { buffer.append($0) }

        XCTAssertEqual(buffer.elements, [3, 4, 5])
        XCTAssertEqual(buffer.count, 3)
    }

    func testRemoveAllResetsOrder() {
        var buffer = RingBuffer<Int>(capacity: 2)
        buffer.append(1)
        buffer.append(2)
        buffer.removeAll()

        buffer.append(9)

        XCTAssertEqual(buffer.elements, [9])
        XCTAssertEqual(buffer.count, 1)
    }

    func testCapacityIsAtLeastOne() {
        var buffer = RingBuffer<Int>(capacity: 0)
        buffer.append(1)
        buffer.append(2)

        XCTAssertEqual(buffer.capacity, 1)
        XCTAssertEqual(buffer.elements, [2])
    }
}
