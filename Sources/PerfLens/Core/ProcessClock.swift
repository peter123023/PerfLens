import Darwin
import Foundation
import PerfLensBootstrap

/// 统一时钟：所有采集器都基于 systemUptime 与 mach_absolute_time，避免墙钟跳变影响。
enum ProcessClock {

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func uptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    static func seconds(fromMachTicks ticks: UInt64) -> TimeInterval {
        guard timebase.denom != 0 else { return 0 }
        let nanoseconds = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
        return nanoseconds / 1_000_000_000
    }

    /// 模块构造函数执行时刻对应的 systemUptime。
    static func bootstrapUptime() -> TimeInterval? {
        let bootstrapTicks = perf_lens_bootstrap_time()
        guard bootstrapTicks > 0 else { return nil }

        let nowTicks = mach_absolute_time()
        guard nowTicks >= bootstrapTicks else { return nil }

        return uptime() - seconds(fromMachTicks: nowTicks - bootstrapTicks)
    }

    /// 内核记录的进程启动时刻对应的 systemUptime。
    static func processStartUptime() -> TimeInterval? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride

        let result = mib.withUnsafeMutableBufferPointer { buffer in
            sysctl(buffer.baseAddress, UInt32(buffer.count), &info, &size, nil, 0)
        }
        guard result == 0 else { return nil }

        let start = info.kp_proc.p_starttime
        let startWall = TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000
        let elapsed = Date().timeIntervalSince1970 - startWall
        guard elapsed >= 0 else { return nil }

        return uptime() - elapsed
    }
}
