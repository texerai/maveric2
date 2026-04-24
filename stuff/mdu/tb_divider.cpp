#include "Vdivider.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <climits>

static Vdivider *dut;
static uint64_t sim_time = 0;
static int pass_count = 0;
static int fail_count = 0;
static int last_cycles = 0;

// Clock edge
static void tick() {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
    sim_time++;
}

// Reset
static void reset() {
    dut->rst            = 1;
    dut->start          = 0;
    dut->op             = 0;
    dut->is_mdu_word_op = 0;
    dut->A              = 0;
    dut->B              = 0;
    tick();
    tick();
    dut->rst = 0;
    tick();
}

// Run division and return result; waits for done
static uint64_t run(uint64_t a, uint64_t b, uint8_t op, uint8_t word_op = 0) {
    dut->start          = 1;
    dut->A              = a;
    dut->B              = b;
    dut->op             = op;
    dut->is_mdu_word_op = word_op;
    tick();
    dut->start = 0;

    int cycles = 1;
    for (int i = 0; i < 200; i++) {
        if (dut->done) break;
        tick();
        cycles++;
    }
    tick(); // one extra so output settles
    last_cycles = cycles;
    return (uint64_t)dut->C;
}

static void check(const char *name, uint64_t got, uint64_t expected) {
    if (got == expected) {
        printf("  PASS  %-50s  cycles=%3d  got=0x%016llx\n",
               name, last_cycles, (unsigned long long)got);
        pass_count++;
    } else {
        printf("  FAIL  %-50s  cycles=%3d  got=0x%016llx  expected=0x%016llx\n",
               name, last_cycles, (unsigned long long)got, (unsigned long long)expected);
        fail_count++;
    }
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vdivider;

    reset();

    printf("\n=== DIVU (unsigned division) ===\n");
    check("16 / 3",        run(16, 3,  1), 5);
    check("100 / 7",       run(100, 7, 1), 14);
    check("0 / 5",         run(0,  5,  1), 0);
    check("1 / 1",         run(1,  1,  1), 1);
    check("7 / 7",         run(7,  7,  1), 1);
    check("UINT64_MAX/1",  run(UINT64_MAX, 1, 1), UINT64_MAX);
    check("UINT64_MAX/2",  run(UINT64_MAX, 2, 1), UINT64_MAX / 2);

    printf("\n=== REMU (unsigned remainder) ===\n");
    check("16 %% 3",        run(16, 3,  3), 16 % 3);
    check("100 %% 7",       run(100, 7, 3), 100 % 7);
    check("0 %% 5",         run(0,  5,  3), 0);
    check("7 %% 7",         run(7,  7,  3), 0);
    check("UINT64_MAX%%2",  run(UINT64_MAX, 2, 3), UINT64_MAX % 2);

    printf("\n=== DIV (signed division) ===\n");
    check("7 / 3",          run(7,   3,  0), 2);
    check("-7 / 3",         run((uint64_t)-7LL, 3, 0), (uint64_t)(-7LL / 3LL));
    check("7 / -3",         run(7,  (uint64_t)-3LL, 0), (uint64_t)(7LL / -3LL));
    check("-7 / -3",        run((uint64_t)-7LL, (uint64_t)-3LL, 0), (uint64_t)((-7LL) / (-3LL)));
    check("-1 / 1",         run((uint64_t)-1LL, 1, 0), (uint64_t)-1LL);
    check("INT64_MIN / -1 (overflow)",
          run((uint64_t)INT64_MIN, (uint64_t)-1LL, 0), (uint64_t)INT64_MIN);

    printf("\n=== REM (signed remainder) ===\n");
    check("7 %% 3",          run(7,   3,  2), 1);
    check("-7 %% 3",         run((uint64_t)-7LL, 3, 2), (uint64_t)(-7LL % 3LL));
    check("7 %% -3",         run(7,  (uint64_t)-3LL, 2), (uint64_t)(7LL % -3LL));
    check("-7 %% -3",        run((uint64_t)-7LL, (uint64_t)-3LL, 2), (uint64_t)((-7LL) % (-3LL)));

    printf("\n=== Divide by zero ===\n");
    check("DIV  5 / 0",   run(5, 0, 0), UINT64_MAX);
    check("DIVU 5 / 0",   run(5, 0, 1), UINT64_MAX);
    check("REM  5 / 0",   run(5, 0, 2), 5);
    check("REMU 5 / 0",   run(5, 0, 3), 5);

    printf("\n=== Large values ===\n");
    check("2^63 / 2",   run((uint64_t)INT64_MIN, 2, 1), (uint64_t)INT64_MIN / 2);
    check("2^62 / 3",   run((uint64_t)1ULL<<62, 3, 1), ((uint64_t)1ULL<<62) / 3);

    printf("\n=== Sequential divisions (no reset between) ===\n");
    check("seq 99/9",   run(99, 9,  1), 11);
    check("seq 64/8",   run(64, 8,  1), 8);
    check("seq 17/5",   run(17, 5,  1), 3);

    // W-type tests: A and B hold raw 64-bit register values;
    // only the lower 32 bits are used.  Expected results are
    // sign-extended 32-bit results (matching RISC-V W-type semantics).
    printf("\n=== DIVW (signed 32-bit division, W-type) ===\n");
    {
        // Helper: sign-extend a 32-bit int to 64-bit uint (what a register holds)
        auto sext = [](int32_t v) -> uint64_t { return (uint64_t)(int64_t)v; };

        check("DIVW  7 / 3",    run(7, 3, 0, 1), sext(7 / 3));
        check("DIVW -7 / 3",    run(sext(-7), sext(3),  0, 1), sext(-7 / 3));
        check("DIVW  7 / -3",   run(sext(7),  sext(-3), 0, 1), sext(7 / -3));
        check("DIVW -7 / -3",   run(sext(-7), sext(-3), 0, 1), sext(-7 / -3));
        check("DIVW INT32_MIN/-1 (overflow)",
              run(sext(INT32_MIN), sext(-1), 0, 1), sext(INT32_MIN));
        check("DIVW  5 / 0",    run(sext(5),  0, 0, 1), UINT64_MAX); // -1 sext
    }

    printf("\n=== DIVUW (unsigned 32-bit division, W-type) ===\n");
    {
        auto sext = [](int32_t v) -> uint64_t { return (uint64_t)(int64_t)v; };
        auto zext = [](uint32_t v) -> uint64_t { return (uint64_t)v; };

        // Result is zero-extended 32-bit quotient, then sign-extended to 64
        check("DIVUW 16 / 3",       run(16, 3, 1, 1), sext((int32_t)(16u / 3u)));
        check("DIVUW 0xFFFFFFFF/1", run(zext(0xFFFFFFFFu), 1, 1, 1),
              sext((int32_t)(0xFFFFFFFFu / 1u)));
        check("DIVUW 5 / 0",        run(5, 0, 1, 1), UINT64_MAX); // -1 sext
    }

    printf("\n=== REMW (signed 32-bit remainder, W-type) ===\n");
    {
        auto sext = [](int32_t v) -> uint64_t { return (uint64_t)(int64_t)v; };

        check("REMW  7 %% 3",   run(7, 3, 2, 1), sext(7 % 3));
        check("REMW -7 %% 3",   run(sext(-7), sext(3),  2, 1), sext(-7 % 3));
        check("REMW  7 %% -3",  run(sext(7),  sext(-3), 2, 1), sext(7 % -3));
        check("REMW -7 %% -3",  run(sext(-7), sext(-3), 2, 1), sext(-7 % -3));
        check("REMW INT32_MIN %% -1", run(sext(INT32_MIN), sext(-1), 2, 1), 0);
        check("REMW  5 %% 0",   run(sext(5), 0, 2, 1), sext(5)); // dividend
    }

    printf("\n=== REMUW (unsigned 32-bit remainder, W-type) ===\n");
    {
        auto sext = [](int32_t v) -> uint64_t { return (uint64_t)(int64_t)v; };
        auto zext = [](uint32_t v) -> uint64_t { return (uint64_t)v; };

        check("REMUW 16 %% 3",       run(16, 3, 3, 1), sext((int32_t)(16u % 3u)));
        check("REMUW 0xFFFFFFFF%%2", run(zext(0xFFFFFFFFu), 2, 3, 1),
              sext((int32_t)(0xFFFFFFFFu % 2u)));
        check("REMUW 5 %% 0",        run(zext(5), 0, 3, 1), sext(5)); // dividend
    }

    printf("\n----------------------------------------\n");
    printf("Results: %d passed, %d failed\n\n", pass_count, fail_count);

    dut->final();
    delete dut;
    return (fail_count == 0) ? 0 : 1;
}
