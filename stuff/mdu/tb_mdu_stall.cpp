// Tests mdu.sv with start held high for the entire computation,
// simulating pipeline stall behaviour where is_mdu_op_i stays asserted.

#include "Vmdu.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <climits>

#define MDU_MUL    0
#define MDU_MULH   1
#define MDU_MULHSU 2
#define MDU_MULHU  3
#define MDU_DIV    4
#define MDU_DIVU   5
#define MDU_REM    6
#define MDU_REMU   7

static Vmdu *dut;
static int   pass_count = 0;
static int   fail_count = 0;
static int   last_cycles = 0;

static void tick() {
    dut->clk_i = 0; dut->eval();
    dut->clk_i = 1; dut->eval();
}

static void reset() {
    dut->arst_i           = 1;
    dut->start            = 0;
    dut->op               = 0;
    dut->is_mdu_word_op_i = 0;
    dut->A                = 0;
    dut->B                = 0;
    tick(); tick();
    dut->arst_i = 0;
    tick();
}

// Holds start=1 (and all inputs) for the entire computation — simulates
// the stalled execute stage where is_mdu_op_i stays asserted until done.
static uint64_t run(uint64_t a, uint64_t b, uint8_t op, uint8_t word_op = 0) {
    dut->start            = 1;
    dut->A                = a;
    dut->B                = b;
    dut->op               = op;
    dut->is_mdu_word_op_i = word_op;

    int cycles = 0;
    for (int i = 0; i < 500; i++) {
        tick();
        cycles++;
        if (!dut->busy) break;
    }
    dut->start = 0;  // drop start only after done, before settling tick
    tick();
    last_cycles = cycles;
    return (uint64_t)dut->C;
}

static void check(const char *name, uint64_t got, uint64_t expected) {
    if (got == expected) {
        printf("  PASS  %-56s  cycles=%3d  got=0x%016llx\n",
               name, last_cycles, (unsigned long long)got);
        pass_count++;
    } else {
        printf("  FAIL  %-56s  cycles=%3d  got=0x%016llx  exp=0x%016llx\n",
               name, last_cycles, (unsigned long long)got, (unsigned long long)expected);
        fail_count++;
    }
}

static uint64_t ref_mulh(uint64_t a, uint64_t b) {
    __int128 r = (__int128)(int64_t)a * (__int128)(int64_t)b;
    return (uint64_t)(r >> 64);
}
static uint64_t ref_mulhsu(uint64_t a, uint64_t b) {
    __int128 r = (__int128)(int64_t)a * (__int128)(uint64_t)b;
    return (uint64_t)(r >> 64);
}
static uint64_t ref_mulhu(uint64_t a, uint64_t b) {
    unsigned __int128 r = (unsigned __int128)a * (unsigned __int128)b;
    return (uint64_t)(r >> 64);
}
static uint64_t sext(int32_t v) { return (uint64_t)(int64_t)v; }

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vmdu;

    reset();

    printf("(start held high throughout each operation — simulating pipeline stall)\n");

    printf("\n=== MUL ===\n");
    check("5 * 3 = 15",
          run(5, 3, MDU_MUL), 15ULL);
    check("-2 * 3 = -6",
          run((uint64_t)-2LL, 3, MDU_MUL), (uint64_t)(-6LL));
    check("INT64_MIN * -1 wraps",
          run((uint64_t)INT64_MIN, (uint64_t)-1LL, MDU_MUL), (uint64_t)INT64_MIN);
    check("UINT64_MAX * 0 = 0",
          run(UINT64_MAX, 0, MDU_MUL), 0ULL);
    check("INT64_MAX * 2 wraps",
          run((uint64_t)INT64_MAX, 2, MDU_MUL), (uint64_t)((uint64_t)INT64_MAX * 2ULL));

    printf("\n=== MULH ===\n");
    check("INT64_MIN * INT64_MIN",
          run((uint64_t)INT64_MIN, (uint64_t)INT64_MIN, MDU_MULH),
          ref_mulh((uint64_t)INT64_MIN, (uint64_t)INT64_MIN));
    check("INT64_MAX * INT64_MAX",
          run((uint64_t)INT64_MAX, (uint64_t)INT64_MAX, MDU_MULH),
          ref_mulh((uint64_t)INT64_MAX, (uint64_t)INT64_MAX));
    check("-5 * 3",
          run((uint64_t)-5LL, 3, MDU_MULH), ref_mulh((uint64_t)-5LL, 3));

    printf("\n=== MULHSU ===\n");
    check("INT64_MIN * UINT64_MAX",
          run((uint64_t)INT64_MIN, UINT64_MAX, MDU_MULHSU),
          ref_mulhsu((uint64_t)INT64_MIN, UINT64_MAX));
    check("-1 * UINT64_MAX",
          run((uint64_t)-1LL, UINT64_MAX, MDU_MULHSU),
          ref_mulhsu((uint64_t)-1LL, UINT64_MAX));

    printf("\n=== MULHU ===\n");
    check("UINT64_MAX * UINT64_MAX",
          run(UINT64_MAX, UINT64_MAX, MDU_MULHU), ref_mulhu(UINT64_MAX, UINT64_MAX));
    check("2^63 * 2 -> upper = 1",
          run((uint64_t)INT64_MIN, 2, MDU_MULHU), ref_mulhu((uint64_t)INT64_MIN, 2));

    printf("\n=== MULW ===\n");
    check("MULW -5 * -3 = 15",
          run(sext(-5), sext(-3), MDU_MUL, 1), sext(-5 * -3));
    check("MULW INT32_MIN * -1 wraps",
          run(sext(INT32_MIN), sext(-1), MDU_MUL, 1),
          sext((int32_t)((uint32_t)INT32_MIN * (uint32_t)-1)));
    check("MULW upper bits of A/B ignored",
          run(0xDEADBEEF00000005ULL, 0xCAFEBABE00000003ULL, MDU_MUL, 1), sext(5 * 3));

    printf("\n=== DIVU ===\n");
    check("UINT64_MAX / 1",
          run(UINT64_MAX, 1, MDU_DIVU), UINT64_MAX);
    check("100 / 7 = 14",
          run(100, 7, MDU_DIVU), 14ULL);
    check("1 / 1 = 1  (A==B fast path)",
          run(1, 1, MDU_DIVU), 1ULL);

    printf("\n=== REMU ===\n");
    check("UINT64_MAX %% 2 = 1",
          run(UINT64_MAX, 2, MDU_REMU), 1ULL);
    check("7 %% 7 = 0  (A==B fast path)",
          run(7, 7, MDU_REMU), 0ULL);

    printf("\n=== DIV ===\n");
    check("-7 / 3",
          run((uint64_t)-7LL, 3, MDU_DIV), (uint64_t)(-7LL / 3LL));
    check("7 / -3",
          run(7, (uint64_t)-3LL, MDU_DIV), (uint64_t)(7LL / -3LL));
    check("INT64_MIN / -1 (overflow, fast path)",
          run((uint64_t)INT64_MIN, (uint64_t)-1LL, MDU_DIV), (uint64_t)INT64_MIN);

    printf("\n=== REM ===\n");
    check("-7 %% 3",
          run((uint64_t)-7LL, 3, MDU_REM), (uint64_t)(-7LL % 3LL));
    check("INT64_MIN %% -1 = 0 (overflow)",
          run((uint64_t)INT64_MIN, (uint64_t)-1LL, MDU_REM), 0ULL);

    printf("\n=== Divide by zero (1-cycle fast path) ===\n");
    check("DIV  5 / 0 = -1",
          run(5, 0, MDU_DIV),  UINT64_MAX);
    check("DIVU 5 / 0 = UINT64_MAX",
          run(5, 0, MDU_DIVU), UINT64_MAX);
    check("REM  5 / 0 = 5",
          run(5, 0, MDU_REM),  5ULL);
    check("REMU 5 / 0 = 5",
          run(5, 0, MDU_REMU), 5ULL);

    printf("\n=== DIVW ===\n");
    check("DIVW -7 / 3",
          run(sext(-7), sext(3), MDU_DIV, 1), sext(-7 / 3));
    check("DIVW INT32_MIN / -1 (overflow)",
          run(sext(INT32_MIN), sext(-1), MDU_DIV, 1), sext(INT32_MIN));
    check("DIVW 5 / 0 = -1 sext",
          run(sext(5), 0, MDU_DIV, 1), UINT64_MAX);

    printf("\n=== DIVUW ===\n");
    check("DIVUW 0xFFFFFFFF / 1",
          run((uint64_t)0xFFFFFFFFu, 1, MDU_DIVU, 1),
          sext((int32_t)(0xFFFFFFFFu / 1u)));
    check("DIVUW 5 / 0",
          run(5, 0, MDU_DIVU, 1), UINT64_MAX);

    printf("\n=== REMW ===\n");
    check("REMW -7 %% 3",
          run(sext(-7), sext(3), MDU_REM, 1), sext(-7 % 3));
    check("REMW INT32_MIN %% -1 = 0",
          run(sext(INT32_MIN), sext(-1), MDU_REM, 1), 0ULL);
    check("REMW 5 %% 0 = 5",
          run(sext(5), 0, MDU_REM, 1), sext(5));

    printf("\n=== REMUW ===\n");
    check("REMUW 0xFFFFFFFF %% 2",
          run((uint64_t)0xFFFFFFFFu, 2, MDU_REMU, 1),
          sext((int32_t)(0xFFFFFFFFu % 2u)));
    check("REMUW 5 %% 0 = 5",
          run(5, 0, MDU_REMU, 1), sext(5));

    printf("\n=== Sequential with held start ===\n");
    check("MUL   6 * 7 = 42",          run(6, 7, MDU_MUL), 42ULL);
    check("DIVU  42 / 6 = 7",          run(42, 6, MDU_DIVU), 7ULL);
    check("MULHU UINT64_MAX^2",        run(UINT64_MAX, UINT64_MAX, MDU_MULHU),
          ref_mulhu(UINT64_MAX, UINT64_MAX));
    check("DIVW  -9 / 3",              run(sext(-9), sext(3), MDU_DIV, 1), sext(-9 / 3));
    check("MUL   after W-type ops",    run(7, 8, MDU_MUL), 56ULL);

    printf("\n----------------------------------------\n");
    printf("Results: %d passed, %d failed\n\n", pass_count, fail_count);

    dut->final();
    delete dut;
    return (fail_count == 0) ? 0 : 1;
}
