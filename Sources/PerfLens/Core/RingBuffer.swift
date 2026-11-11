import Foundation

/// 定长环形缓冲，写满后覆盖最旧的数据。
struct RingBuffer<Element> {

    let capacity: Int
    private var storage: [Element?]
    private var writeIndex = 0
    private(set) var count = 0

    init(capacity: Int) {
        let safeCapacity = max(1, capacity)
        self.capacity = safeCapacity
        self.storage = Array(repeating: nil, count: safeCapacity)
    }

    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }

    /// 按从旧到新的顺序返回当前快照。
    var elements: [Element] {
        guard count > 0 else { return [] }

        if count < capacity {
            return storage.prefix(count).compactMap { $0 }
        }

        var result: [Element] = []
        result.reserveCapacity(capacity)
        for offset in 0..<capacity {
            let index = (writeIndex + offset) % capacity
            if let element = storage[index] {
                result.append(element)
            }
        }
        return result
    }
}
