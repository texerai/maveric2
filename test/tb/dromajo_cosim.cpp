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
//                               and called once per *retired* instruction; steps
//                               the golden model one instruction and compares
//                               its result against the DUT values. The RTL does
//                               not call this for a slot that raises a trap,
//                               since such a slot is squashed and never retires.
//
//   dromajo_raise_trap(...)  -- DPI-C function imported by write_back_stage.sv
//                               and called when the DUT takes a trap. Only an
//                               asynchronous interrupt needs action here: it is
//                               registered as pending so Dromajo takes it before
//                               the next retired instruction is compared.
//                               Synchronous exceptions (ECALL/EBREAK/illegal/
//                               misaligned) need nothing here -- Dromajo raises
//                               them itself when it executes the faulting
//                               instruction on the next dromajo_step().
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
#include "riscv_machine.h"

static dromajo_cosim_state_t *cosim_state = nullptr;
static bool                   cosim_error = false;
static bool                   cosim_done  = false;  // Dromajo signalled clean termination (HTIF exit 0)
static bool                   trap_pending = false;

static const uint32_t CSR_OPCODE = 0x73;
static const uint32_t MSTATUS_CSR_ADDR = 0x300;
static const uint32_t TIME_CSR_ADDR = 0xc01;

static RISCVCPUState *dromajo_hart0() {
    RISCVMachine *machine = reinterpret_cast<RISCVMachine *>(cosim_state);
    if (machine != nullptr && machine->ncpus > 0) {
        return machine->cpu_state[0];
    }
    return nullptr;
}

static uint32_t csr_addr(uint32_t insn) {
    return (insn >> 20) & 0xfff;
}

static bool is_csr_instruction(uint32_t insn, uint32_t expected_csr_addr) {
    uint32_t opcode = insn & 0x7f;
    uint32_t funct3 = (insn >> 12) & 0x7;
    return opcode == CSR_OPCODE && funct3 != 0 && csr_addr(insn) == expected_csr_addr;
}

static bool model_matches_retirement(RISCVCPUState *hart, uint64_t pc, uint32_t insn) {
    uint64_t emu_pc = riscv_get_pc(hart);
    uint32_t emu_insn = 0;
    riscv_read_insn(hart, &emu_insn, emu_pc);
    if ((emu_insn & 3) != 3) {
        emu_insn &= 0xffff;
    }

    if (emu_pc == pc && (emu_insn == insn || (emu_insn & 3) != 3)) {
        return true;
    }

    fprintf(stderr, "[cosim] MISMATCH at PC=0x%016lx  insn=0x%08x\n",
            (unsigned long)pc, insn);
    fprintf(stderr, "[error] EMU PC %016lx, DUT PC %016lx\n",
            (unsigned long)emu_pc, (unsigned long)pc);
    fprintf(stderr, "[error] EMU INSN %08x, DUT INSN %08x\n", emu_insn, insn);
    cosim_error = true;
    return false;
}

static uint64_t normalize_wdata_for_dromajo(uint32_t insn, uint64_t wdata) {
    if (is_csr_instruction(insn, MSTATUS_CSR_ADDR)) {
        RISCVCPUState *hart = dromajo_hart0();
        if (hart != nullptr) {
            return riscv_cpu_get_mstatus(hart);
        }
    }
    return wdata;
}

static bool retire_time_csr_read(uint64_t pc, uint32_t insn, uint64_t wdata, uint8_t reg_we) {
    if (!is_csr_instruction(insn, TIME_CSR_ADDR)) {
        return false;
    }

    RISCVCPUState *hart = dromajo_hart0();
    if (hart == nullptr) {
        return false;
    }

    if (!model_matches_retirement(hart, pc, insn)) {
        return true;
    }

    if (reg_we) {
        uint8_t rd = (insn >> 7) & 0x1f;
        if (rd > 0) {
            riscv_set_reg(hart, rd, wdata);
        }
    }
    riscv_set_pc(hart, pc + 4);
    riscv_cpu_sync_regs(hart);
    return true;
}

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
// dromajo_raise_trap -- DPI-C: called by write_back_stage.sv when the DUT takes
// a trap.
//
// Only asynchronous interrupts are registered here. The squashed instruction is
// not stepped in the golden model (see write_back_stage.sv), so Dromajo is left
// sitting on the instruction the DUT recorded in mepc. Registering the interrupt
// as pending makes Dromajo take it on the next dromajo_step(), reproducing the
// DUT's mepc/mcause exactly.
//
// Synchronous exceptions (ECALL/EBREAK/illegal/misaligned) are deliberately
// ignored: Dromajo raises them itself when it executes the faulting instruction
// during the next dromajo_step(), which lands it on the handler entry that the
// DUT reports next.
//
// Maveric carries mcause as {interrupt, cause[4:0]}. Dromajo expects a signed
// int64_t where a negative value marks an interrupt and the low bits carry the
// cause code.
// ---------------------------------------------------------------------------
extern "C" void dromajo_raise_trap(uint8_t cause) {
    if (!cosim_state || cosim_error || cosim_done || trap_pending) return;

    uint8_t cause_code = cause & 0x1f;
    if (cause & 0x20) {
        dromajo_cosim_raise_trap(cosim_state, 0, INT64_MIN | cause_code);
        trap_pending = true;
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
// The RTL only calls this for instructions that actually retire; trap-raising
// slots are filtered out there. In non-continuation runs ECALL/EBREAK are used
// as simulator exits, so they are skipped here too as a defensive measure.
// ---------------------------------------------------------------------------
extern "C" void dromajo_step(
    uint64_t pc,
    uint32_t insn,
    uint64_t wdata,
    uint8_t  reg_we,
    uint64_t mstatus)
{
    if (!cosim_state || cosim_error || cosim_done) return;

#ifndef MAVERIC_CONTINUE_AFTER_TRAP
    // Non-continuation tests use ECALL/EBREAK as simulator exits, not as
    // architectural trap-handler checks.
    if (insn == 0x00000073 || insn == 0x00100073) return;
#endif

    // When the instruction does not write a register, pass 0 so Dromajo
    // does not attempt to match a stale wdata value.
    uint64_t check_wdata = reg_we ? normalize_wdata_for_dromajo(insn, wdata) : 0;

    if (retire_time_csr_read(pc, insn, wdata, reg_we)) return;

    int ret = dromajo_cosim_step(
        cosim_state,
        0,            // hartid: single-core design
        pc,
        insn,
        check_wdata,
        mstatus,      // DUT post-commit mstatus (also printed by Dromajo on a mismatch)
        true          // check: enable comparison
    );
    trap_pending = false;

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
        return;
    }

    // PC/insn/wdata matched and the golden model has retired this instruction, so
    // Dromajo now holds the post-commit mstatus. Compare it against the DUT.
    //
    // Maveric is M-mode only and hardwires mstatus.MPP = 0b11, whereas Dromajo
    // models M/S/U and clears MPP on mret (handle_mret). That field therefore
    // diverges by design, so it is masked out of the comparison. Everything else
    // (MIE/MPIE, the trap-enable bits, SXL/UXL, ...) is checked exactly.
    RISCVCPUState *hart = dromajo_hart0();
    if (hart != nullptr) {
        const uint64_t MSTATUS_MPP_MASK = (uint64_t)0x3 << 11;
        uint64_t emu_mstatus = riscv_cpu_get_mstatus(hart);
        if (((emu_mstatus ^ mstatus) & ~MSTATUS_MPP_MASK) != 0) {
            fprintf(stderr, "[cosim] MSTATUS MISMATCH at PC=0x%016lx  insn=0x%08x\n",
                    (unsigned long)pc, insn);
            fprintf(stderr, "[error] EMU MSTATUS %016lx, DUT MSTATUS %016lx (MPP[12:11] masked)\n",
                    (unsigned long)emu_mstatus, (unsigned long)mstatus);
            cosim_error = true;
        }
    }
}


// ---------------------------------------------------------------------------
// dromajo_has_error -- returns 1 if any mismatch was detected.
// ---------------------------------------------------------------------------
extern "C" int dromajo_has_error() {
    return cosim_error ? 1 : 0;
}
