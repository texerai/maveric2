/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------
// Dromajo co-simulation interface for Maveric Core 2.0.
//
// This file provides three functions:
//
//   dromajo_init(elf_path)   -- called from tb_test_env.cpp before the clock
//                               starts; initialises the Dromajo golden model
//                               with the same ELF the DUT is running.
//
//   dromajo_step(...)        -- DPI-C function imported by write_back_stage.sv
//                               and called once per retired instruction; steps
//                               the golden model one instruction and compares
//                               its result against the DUT values.
//
//   dromajo_fini()           -- called from tb_test_env.cpp after simulation
//                               ends; releases Dromajo resources.
//
//   dromajo_has_error()      -- returns 1 if any mismatch has been detected.
// ---------------------------------------------------------------------------

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdint.h>

#include "dromajo_cosim.h"

static dromajo_cosim_state_t *cosim_state = nullptr;
static bool                   cosim_error = false;
static bool                   cosim_done  = false;  // Dromajo signalled clean termination (HTIF exit 0)


// ---------------------------------------------------------------------------
// dromajo_init -- initialise the golden model.
//
// Dromajo's init function takes an argv-style array, just like main().
// --reset_vector 0x80000000 tells Dromajo to start executing from the ELF
// entry point directly, matching the DUT which has no boot ROM.
// ---------------------------------------------------------------------------
extern "C" void dromajo_init(const char *elf_path) {
    char  progname[]      = "dromajo";
    char  reset_flag[]    = "--reset_vector";
    char  reset_addr[]    = "0x80000000";

    char *argv[] = {
        progname,
        reset_flag,
        reset_addr,
        const_cast<char *>(elf_path),
        nullptr
    };
    int argc = 4;

    cosim_state = dromajo_cosim_init(argc, argv);
    if (!cosim_state) {
        fprintf(stderr, "[cosim] ERROR: dromajo_cosim_init failed for %s\n", elf_path);
        exit(EXIT_FAILURE);
    }
}


// ---------------------------------------------------------------------------
// dromajo_fini -- release Dromajo resources.
// ---------------------------------------------------------------------------
extern "C" void dromajo_fini() {
    if (cosim_state) {
        dromajo_cosim_fini(cosim_state);
        cosim_state = nullptr;
    }
}


// ---------------------------------------------------------------------------
// dromajo_step -- DPI-C: called by write_back_stage.sv at every retirement.
//
// Parameters mirror what the RTL already passes to log_trace:
//   pc     : program counter of the retiring instruction
//   insn   : 32-bit instruction word
//   wdata  : value written to the destination register (0 if no reg write)
//   reg_we : 1 if the instruction writes an integer register, else 0
//
// ECALL (0x00000073) is skipped: the DUT suppresses it in log_trace and
// the check() DPI call handles program termination separately.
// ---------------------------------------------------------------------------
extern "C" void dromajo_step(
    uint64_t pc,
    uint32_t insn,
    uint64_t wdata,
    uint8_t  reg_we)
{
    if (!cosim_state || cosim_error || cosim_done) return;

    // Skip ECALL/EBREAK — both are handled by check() + $finish in the DUT.
    // Passing either to dromajo_cosim_step causes an infinite exception loop
    // inside Dromajo (no M-mode trap handler configured).
    if (insn == 0x00000073 || insn == 0x00100073) return;

    // When the instruction does not write a register, pass 0 so Dromajo
    // does not attempt to match a stale wdata value.
    uint64_t check_wdata = reg_we ? wdata : 0;

    int ret = dromajo_cosim_step(
        cosim_state,
        0,            // hartid: single-core design
        pc,
        insn,
        check_wdata,
        0,            // mstatus: no CSR support yet, pass 0
        true          // check: enable comparison
    );

    if (ret != 0) {
        if (ret == 0x1FFF) {
            // PC / insn / wdata comparison failed.
            fprintf(stderr, "[cosim] MISMATCH at PC=0x%016lx  insn=0x%08x\n",
                    (unsigned long)pc, insn);
            cosim_error = true;
        } else {
            // ret == 1: Dromajo signalled clean termination (HTIF tohost written).
            // The DUT will now spin waiting to be killed; exit immediately so the
            // simulation does not run to MAX_SIM_TIME.
            dromajo_cosim_fini(cosim_state);
            cosim_state = nullptr;
            cosim_done  = true;
            exit(EXIT_SUCCESS);
        }
    }
}


// ---------------------------------------------------------------------------
// dromajo_has_error -- returns 1 if any mismatch was detected.
// ---------------------------------------------------------------------------
extern "C" int dromajo_has_error() {
    return cosim_error ? 1 : 0;
}