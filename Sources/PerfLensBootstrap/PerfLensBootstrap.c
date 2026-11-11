#include "PerfLensBootstrap.h"

#include <mach/mach_time.h>
#include <stddef.h>

#if defined(__arm64__)
#include <mach/arm/thread_status.h>
#elif defined(__x86_64__)
#include <mach/i386/thread_status.h>
#endif

static uint64_t g_perf_lens_bootstrap_time = 0;

__attribute__((constructor))
static void perf_lens_record_bootstrap(void) {
    g_perf_lens_bootstrap_time = mach_absolute_time();
}

uint64_t perf_lens_bootstrap_time(void) {
    return g_perf_lens_bootstrap_time;
}

int perf_lens_sample_thread(mach_port_t thread,
                            uintptr_t stack_low,
                            uintptr_t stack_high,
                            uintptr_t *frames,
                            int max_frames) {
    if (frames == NULL || max_frames <= 0) {
        return 0;
    }

    int count = 0;

#if defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t state_count = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(thread, ARM_THREAD_STATE64,
                         (thread_state_t)&state, &state_count) != KERN_SUCCESS) {
        return 0;
    }

    frames[count++] = (uintptr_t)state.__pc;

    uintptr_t fp = (uintptr_t)state.__fp;
    uintptr_t lr = (uintptr_t)state.__lr;
    if (lr != 0 && count < max_frames) {
        frames[count++] = lr;
    }

    while (fp != 0 && count < max_frames) {
        if (fp < stack_low || fp + 2 * sizeof(uintptr_t) > stack_high) {
            break;
        }
        uintptr_t next_fp = *(uintptr_t *)fp;
        uintptr_t return_address = *(uintptr_t *)(fp + sizeof(uintptr_t));
        if (return_address == 0) {
            break;
        }
        frames[count++] = return_address;
        if (next_fp <= fp) {
            break;
        }
        fp = next_fp;
    }
#elif defined(__x86_64__)
    x86_thread_state64_t state;
    mach_msg_type_number_t state_count = x86_THREAD_STATE64_COUNT;
    if (thread_get_state(thread, x86_THREAD_STATE64,
                         (thread_state_t)&state, &state_count) != KERN_SUCCESS) {
        return 0;
    }

    frames[count++] = (uintptr_t)state.__rip;

    uintptr_t fp = (uintptr_t)state.__rbp;
    while (fp != 0 && count < max_frames) {
        if (fp < stack_low || fp + 2 * sizeof(uintptr_t) > stack_high) {
            break;
        }
        uintptr_t next_fp = *(uintptr_t *)fp;
        uintptr_t return_address = *(uintptr_t *)(fp + sizeof(uintptr_t));
        if (return_address == 0) {
            break;
        }
        frames[count++] = return_address;
        if (next_fp <= fp) {
            break;
        }
        fp = next_fp;
    }
#else
    (void)thread;
    (void)stack_low;
    (void)stack_high;
#endif

    return count;
}
