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
    printf("\n========== Performance Counters ==========\n");
    printf("Cycles              : %" PRIu64 "\n", cycle_count);
    printf("Instructions retired: %" PRIu64 "\n", instr_count);
    printf("Stall cycles        : %" PRIu64 "\n", stall_cycles);
    printf("I$ hits             : %" PRIu64 "\n", icache_hits);
    printf("I$ misses           : %" PRIu64 "\n", icache_misses);
    printf("D$ hits             : %" PRIu64 "\n", dcache_hits);
    printf("D$ misses           : %" PRIu64 "\n", dcache_misses);
    printf("Branch mispredicts  : %" PRIu64 "\n", branch_mispred);
    printf("------------------------------------------\n");

    if (instr_count > 0) {

        printf("CPI                 : %.4f\n",
               (double)cycle_count / (double)instr_count);

        if (cycle_count > stall_cycles) {

                printf("Pipeline CPI        : %.4f\n",
                   (double)(cycle_count - stall_cycles) / (double)instr_count);

        }

    }
    if (icache_hits + icache_misses > 0) {

        printf("I$ hit rate         : %.2f%%\n",
               100.0 * (double)icache_hits / (double)(icache_hits + icache_misses));

    }

    if (dcache_hits + dcache_misses > 0) {

        
        printf("D$ hit rate         : %.2f%%\n",
               100.0 * (double)dcache_hits / (double)(dcache_hits + dcache_misses));

    }

    printf("==========================================\n\n");
}
