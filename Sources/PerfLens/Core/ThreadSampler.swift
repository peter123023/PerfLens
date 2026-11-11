import Darwin
import PerfLensBootstrap

enum ThreadSampler {

    /// 采样目标线程的调用栈。调用方负责保证线程处于挂起状态之外的生命周期安全。
    static func capture(
        thread: mach_port_t,
        stackLow: UInt,
        stackHigh: UInt,
        limit: Int
    ) -> [UInt] {
        guard thread != 0, stackHigh > stackLow, limit > 0 else { return [] }

        var frames = [UInt](repeating: 0, count: limit)
        let suspended = thread_suspend(thread) == KERN_SUCCESS

        let count = frames.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return perf_lens_sample_thread(thread, stackLow, stackHigh, base, Int32(limit))
        }

        if suspended {
            thread_resume(thread)
        }

        return Array(frames.prefix(Int(max(0, count))))
    }
}
