#ifndef PERF_LENS_BOOTSTRAP_H
#define PERF_LENS_BOOTSTRAP_H

#include <stdint.h>
#include <mach/mach.h>

/// 模块加载时记录的时间戳（mach_absolute_time），用于近似 pre-main 起点。
uint64_t perf_lens_bootstrap_time(void);

/// 读取已挂起线程的调用栈，返回写入的帧数。
/// 采样前调用方需要先 thread_suspend，采样结束后 thread_resume。
int perf_lens_sample_thread(mach_port_t thread,
                            uintptr_t stack_low,
                            uintptr_t stack_high,
                            uintptr_t *frames,
                            int max_frames);

#endif /* PERF_LENS_BOOTSTRAP_H */
