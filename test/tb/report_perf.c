/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

void report_perf(
    uint64_t cycle_count,
    uint64_t instr_count,
    uint64_t stall_cycles,
    uint64_t icache_hits,
    uint64_t icache_misses,
    uint64_t dcache_hits,
    uint64_t dcache_misses,
    uint64_t branch_mispred
) {
    if (instr_count > 0) {

        printf("CPI                 : %.4f\n",
               (double)cycle_count / (double)instr_count);

        if (cycle_count > stall_cycles) {

                printf("PIPELINE CPI        : %.4f\n",
                   (double)(cycle_count - stall_cycles) / (double)instr_count);

        }

    }
    if (icache_hits + icache_misses > 0) {

        printf("I$ HIT RATE         : %.2f%%\n",
               100.0 * (double)icache_hits / (double)(icache_hits + icache_misses));

    }

    if (dcache_hits + dcache_misses > 0) {


        printf("D$ HIT RATE         : %.2f%%\n",
               100.0 * (double)dcache_hits / (double)(dcache_hits + dcache_misses));

    }
}
