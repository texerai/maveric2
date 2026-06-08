#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <memory>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <verilated_cov.h>
#include "Vtest_env.h"

#define MAX_SIM_TIME 10000000
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

// Dromajo co-simulation interface (defined in dromajo_cosim.cpp).
extern "C" void dromajo_init(const char *elf_path);
extern "C" void dromajo_fini();
extern "C" int  dromajo_has_error();


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
    const char *elf_path = argv[1];
    dromajo_init(elf_path);

    Vtest_env *dut = new Vtest_env;
//  Verilated::traceEverOn(true);
//  VerilatedVcdC* sim_trace = new VerilatedVcdC;
//  dut->trace(sim_trace, 10);
//  sim_trace->open("./waveform/waveform.vcd");
    while (sim_time < MAX_SIM_TIME & (!Verilated::gotFinish())) {
        dut_reset(dut, sim_time);
        dut->clk_i ^= 1;
        dut->eval();

        if (dut->clk_i == 1){
            posedge_cnt++;
        }

//      sim_trace->dump(sim_time);
        sim_time++;
    }

//  sim_trace->close();
//  delete sim_trace;
//  VerilatedCov::write("coverage.dat");

    int cosim_failed = dromajo_has_error();
    dromajo_fini();

    dut->final();
    delete dut;
    exit(cosim_failed ? EXIT_FAILURE : EXIT_SUCCESS);
}

