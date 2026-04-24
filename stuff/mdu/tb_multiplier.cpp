#include "Vmultiplier.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <climits>

static Vmultiplier *dut;
static int pass_count = 0;
static int fail_count = 0;
static int last_cycles = 0;

static void tick() {
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();
}

static void reset() {
    dut->rst          = 1;
    dut->start        = 0;
    dut->op           = 0;
    dut->is_mdu_word_op = 0;
    dut->A            = 0;
    dut->B            = 0;
    tick(); tick();
    dut->rst = 0;
    tick();
}

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
    tick();
    last_cycles = cycles;
    return (uint64_t)dut->C;
}

static void check(const char *name, uint64_t got, uint64_t expected) {
    if (got == expected) {
        printf("  PASS  %-54s  cycles=%3d  got=0x%016llx\n",
               name, last_cycles, (unsigned long long)got);
        pass_count++;
    } else {
        printf("  FAIL  %-54s  cycles=%3d  got=0x%016llx  exp=0x%016llx\n",
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

// Sign-extend 32-bit value to 64-bit
static uint64_t sext(int32_t v) { return (uint64_t)(int64_t)v; }

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vmultiplier;

    reset();

    printf("\n=== MUL (lower 64 bits) ===\n");
    check("5 * 3 = 15",
          run(5, 3, 0), 15ULL);
    check("-2 * 3 = -6",
          run((uint64_t)-2LL, 3, 0), (uint64_t)(-6LL));
    check("-5 * -3 = 15",
          run((uint64_t)-5LL, (uint64_t)-3LL, 0), 15ULL);
    check("0 * 12345 = 0",
          run(0, 12345, 0), 0ULL);
    check("UINT64_MAX * 1 = UINT64_MAX",
          run(UINT64_MAX, 1, 0), UINT64_MAX);
    check("INT64_MIN * -1 wraps to INT64_MIN",
          run((uint64_t)INT64_MIN, (uint64_t)-1LL, 0), (uint64_t)INT64_MIN);

    printf("\n=== MULH (upper 64 bits, signed x signed) ===\n");
    check("5 * 3  -> upper = 0",
          run(5, 3, 1), ref_mulh(5, 3));
    check("-5 * 3 -> upper",
          run((uint64_t)-5LL, 3, 1), ref_mulh((uint64_t)-5LL, 3));
    check("-1 * -1 -> upper = 0",
          run((uint64_t)-1LL, (uint64_t)-1LL, 1), ref_mulh((uint64_t)-1LL, (uint64_t)-1LL));
    check("INT64_MIN * INT64_MIN",
          run((uint64_t)INT64_MIN, (uint64_t)INT64_MIN, 1),
          ref_mulh((uint64_t)INT64_MIN, (uint64_t)INT64_MIN));
    check("INT64_MAX * INT64_MAX",
          run((uint64_t)INT64_MAX, (uint64_t)INT64_MAX, 1),
          ref_mulh((uint64_t)INT64_MAX, (uint64_t)INT64_MAX));

    printf("\n=== MULHSU (upper 64 bits, signed A x unsigned B) ===\n");
    check("5 * 3",
          run(5, 3, 2), ref_mulhsu(5, 3));
    check("-5 * 3 -> upper",
          run((uint64_t)-5LL, 3, 2), ref_mulhsu((uint64_t)-5LL, 3));
    check("INT64_MIN * UINT64_MAX",
          run((uint64_t)INT64_MIN, UINT64_MAX, 2),
          ref_mulhsu((uint64_t)INT64_MIN, UINT64_MAX));
    check("-1 * UINT64_MAX",
          run((uint64_t)-1LL, UINT64_MAX, 2),
          ref_mulhsu((uint64_t)-1LL, UINT64_MAX));

    printf("\n=== MULHU (upper 64 bits, unsigned x unsigned) ===\n");
    check("5 * 3 -> upper = 0",
          run(5, 3, 3), ref_mulhu(5, 3));
    check("2^63 * 2 -> upper = 1",
          run((uint64_t)INT64_MIN, 2, 3), ref_mulhu((uint64_t)INT64_MIN, 2));
    check("UINT64_MAX * UINT64_MAX",
          run(UINT64_MAX, UINT64_MAX, 3), ref_mulhu(UINT64_MAX, UINT64_MAX));

    printf("\n=== MULW (signed 32-bit multiply, W-type) ===\n");
    check("MULW  5 * 3 = 15",
          run(5, 3, 0, 1), sext(5 * 3));
    check("MULW -2 * 3 = -6",
          run(sext(-2), sext(3), 0, 1), sext(-2 * 3));
    check("MULW -5 * -3 = 15",
          run(sext(-5), sext(-3), 0, 1), sext(-5 * -3));
    check("MULW  0 * 99 = 0",
          run(0, 99, 0, 1), 0ULL);
    check("MULW INT32_MAX * 2",
          run(sext(INT32_MAX), 2, 0, 1), sext((int32_t)((int32_t)INT32_MAX * 2)));
    check("MULW INT32_MIN * -1 wraps",
          run(sext(INT32_MIN), sext(-1), 0, 1), sext((int32_t)((int32_t)INT32_MIN * -1)));
    check("MULW INT32_MAX * INT32_MAX",
          run(sext(INT32_MAX), sext(INT32_MAX), 0, 1),
          sext((int32_t)((int32_t)INT32_MAX * (int32_t)INT32_MAX)));
    // Upper 32 bits of register operands must be ignored
    check("MULW upper bits of A ignored",
          run(0xDEADBEEF00000005ULL, 3, 0, 1), sext(5 * 3));
    check("MULW upper bits of B ignored",
          run(5, 0xCAFEBABE00000003ULL, 0, 1), sext(5 * 3));

    printf("\n=== Sequential (no reset between) ===\n");
    check("MUL  6 * 7 = 42",       run(6, 7, 0), 42ULL);
    check("MULHU UINT64_MAX^2",    run(UINT64_MAX, UINT64_MAX, 3), ref_mulhu(UINT64_MAX, UINT64_MAX));
    check("MULW -3 * 4",           run(sext(-3), sext(4), 0, 1), sext(-3 * 4));
    check("MUL after MULW",        run(7, 8, 0), 56ULL);

    printf("\n----------------------------------------\n");
    printf("Results: %d passed, %d failed\n\n", pass_count, fail_count);

    dut->final();
    delete dut;
    return (fail_count == 0) ? 0 : 1;
}
