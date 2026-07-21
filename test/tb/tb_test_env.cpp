#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <cstdint>
#include <memory>
#include <verilated.h>
#include <verilated_fst_c.h>
#include <verilated_cov.h>
#include "Vtest_env.h"

// Backstop only: runs normally end at a retired ebreak/ecall (check.c) or
// self-loop (check_self_loop). run_tests.py lowers the budget for tests that
// use the self-loop as an interrupt wait and must run out the clock instead.
#define DEFAULT_MAX_SIM_TIME 20000000000ULL
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

#ifdef DROMAJO_COSIM
// Dromajo co-simulation interface (defined in dromajo_cosim.cpp).
extern "C" void dromajo_init(const char *elf_path);
extern "C" void dromajo_fini();
extern "C" int  dromajo_has_error();
#endif

extern "C" int check_final(uint16_t branch_total, uint16_t branch_mispred);

static const char *env_or(const char *name, const char *fallback) {
    const char *value = getenv(name);
    return (value != NULL && value[0] != '\0') ? value : fallback;
}

static vluint64_t max_sim_time_from_env(void) {
    const char *value = getenv("MAVERIC_MAX_SIM_TIME");
    if (value == NULL || value[0] == '\0') {
        return DEFAULT_MAX_SIM_TIME;
    }
    return strtoull(value, NULL, 10);
}

void dut_reset (Vtest_env *dut, vluint64_t &sim_time){
    if( sim_time < 100 ){
        dut->arst_i = 1;
    }
    else {
        dut->arst_i = 0;
    }
}

// ELF path is passed as the first command-line argument after Verilator args.
// Usage: Vtest_env <elf_path>
int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <elf_path>\n", argv[0]);
        exit(EXIT_FAILURE);
    }
#ifdef DROMAJO_COSIM
    const char *elf_path = argv[1];
    dromajo_init(elf_path);
#endif

    const vluint64_t max_sim_time = max_sim_time_from_env();

    Vtest_env *dut = new Vtest_env;
#if VM_TRACE
    Verilated::traceEverOn(true);
    VerilatedFstC* sim_trace = new VerilatedFstC;
    dut->trace(sim_trace, 10);
    sim_trace->open(env_or("MAVERIC_WAVEFORM_FILE", "waveform.fst"));
#endif
    while (sim_time < max_sim_time && (!Verilated::gotFinish())) {
        dut_reset(dut, sim_time);
        dut->clk_i ^= 1;
        dut->eval();

        if (dut->clk_i == 1){
            posedge_cnt++;
        }
#if VM_TRACE
        sim_trace->dump(sim_time);
#endif
        sim_time++;
    }
#if VM_TRACE
    sim_trace->close();
    delete sim_trace;
#endif
#if VM_COVERAGE
    VerilatedCov::write(env_or("MAVERIC_COVERAGE_FILE", "coverage.dat"));
#endif
    if (!Verilated::gotFinish()) {
        check_final(0, 0);
    }

    int cosim_failed = 0;
#ifdef DROMAJO_COSIM
    cosim_failed = dromajo_has_error();
    dromajo_fini();
#endif

    dut->final();
    delete dut;
    exit(cosim_failed ? EXIT_FAILURE : EXIT_SUCCESS);
}
