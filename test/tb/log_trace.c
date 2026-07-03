#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define RTL_TRACE_FILE_ENV "MAVERIC_RTL_TRACE_FILE"
#define ECALL_INSTRUCTION 0x00000073u
#define EBREAK_INSTRUCTION 0x00100073u
#define SELF_LOOP_INSTRUCTION 0x0000006fu
// riscv-tests signal completion by writing the pass/fail code to tohost and
// then spinning in write_tohost forever. Spike terminates the run the moment
// tohost is written, so the RTL trace must stop right after committing that
// store to stay aligned with Spike.
#define TOHOST_ADDRESS 0x0000000080001000ull

static FILE *trace_file = NULL;
static int trace_file_failed = 0;
static int trace_complete = 0;

static void close_trace_file(void) {
    if (trace_file != NULL) {
        fclose(trace_file);
        trace_file = NULL;
    }
}

static FILE *get_trace_file(void) {
    const char *trace_file_path;

    if (trace_file != NULL || trace_file_failed) {
        return trace_file;
    }

    trace_file_path = getenv(RTL_TRACE_FILE_ENV);
    if (trace_file_path == NULL || trace_file_path[0] == '\0') {
        fprintf(
            stderr,
            "%s is not set; RTL trace logging is disabled.\n",
            RTL_TRACE_FILE_ENV
        );
        trace_file_failed = 1;
        return NULL;
    }

    trace_file = fopen(trace_file_path, "a");
    if (trace_file == NULL) {
        perror(trace_file_path);
        trace_file_failed = 1;
        return NULL;
    }

    atexit(close_trace_file);
    return trace_file;
}

static const char *csr_name(uint16_t csr_addr) {
    switch (csr_addr) {
        // M-mode CSRs.
        case 0x300: return "mstatus";
        case 0x301: return "misa";
        case 0x302: return "medeleg";
        case 0x303: return "mideleg";
        case 0x304: return "mie";
        case 0x305: return "mtvec";
        case 0x340: return "mscratch";
        case 0x341: return "mepc";
        case 0x342: return "mcause";
        case 0x343: return "mtval";
        case 0x344: return "mip";
        case 0xf11: return "mvendorid";
        case 0xf12: return "marchid";
        case 0xf13: return "mimpid";
        case 0xf14: return "mhartid";
        // S-mode CSRs.
        case 0x100: return "sstatus";
        case 0x104: return "sie";
        case 0x105: return "stvec";
        case 0x140: return "sscratch";
        case 0x141: return "sepc";
        case 0x142: return "scause";
        case 0x143: return "stval";
        case 0x144: return "sip";
        case 0x14d: return "stimecmp";
        case 0xc01: return "time";
        default: return NULL;
    }
}

static void write_csr_trace(FILE *out, uint16_t csr_addr, uint64_t csr_data) {
    const char *name = csr_name(csr_addr);

    if (name != NULL) {
        fprintf(
            out,
            ", c%u_%s: 0x%016llx",
            csr_addr,
            name,
            (unsigned long long)csr_data
        );
    }
    else {
        fprintf(
            out,
            ", c%u: 0x%016llx",
            csr_addr,
            (unsigned long long)csr_data
        );
    }
}

#ifdef __cplusplus
extern "C" {
#endif

void log_trace(
    uint64_t pc,
    uint32_t instruction,
    uint64_t reg_val,
    uint8_t reg_addr,
    uint8_t reg_we,
    uint8_t mem_access,
    uint64_t mem_val,
    uint64_t mem_addr,
    uint8_t mem_we,
    uint8_t csr_we,
    uint16_t csr_addr,
    uint64_t csr_data
) {
    FILE *out;
    uint8_t trace_csr_we = csr_we;

    if (trace_complete) {
        return;
    }

#ifdef MAVERIC_CONTINUE_AFTER_TRAP
    if (instruction == SELF_LOOP_INSTRUCTION) {
        trace_complete = 1;
        return;
    }
#endif

    out = get_trace_file();
    if (out == NULL) {
        return;
    }

    if (instruction == ECALL_INSTRUCTION || instruction == EBREAK_INSTRUCTION) {
        fprintf(
            out,
            "PC: 0x%016llx, INSTR: 0x%08x, %s\n",
            (unsigned long long)pc,
            instruction,
            (instruction == ECALL_INSTRUCTION) ? "ecall" : "ebreak"
        );
        fflush(out);
#ifndef MAVERIC_CONTINUE_AFTER_TRAP
        trace_complete = 1;
#endif
        return;
    }

    fprintf(
        out,
        "PC: 0x%016llx, INSTR: 0x%08x",
        (unsigned long long)pc,
        instruction
    );

    if (reg_we) {
        fprintf(
            out,
            ", REG x%u: 0x%016llx",
            (unsigned int)reg_addr,
            (unsigned long long)reg_val
        );
        if (mem_we) {
            // Atomic memory op (AMO): writes a register *and* memory, so log
            // both the register result and the value written to memory.
            fprintf(
                out,
                ", MEM 0x%016llx: 0x%016llx",
                (unsigned long long)mem_addr,
                (unsigned long long)mem_val
            );
        }
        else if (mem_access) {
            // Load / LR: register written, memory only read.
            fprintf(out, ", MEM 0x%016llx", (unsigned long long)mem_addr);
        }
        else if (trace_csr_we) {
            write_csr_trace(out, csr_addr, csr_data);
        }
    }
    else if (mem_we) {
        fprintf(
            out,
            ", MEM 0x%016llx: 0x%016llx",
            (unsigned long long)mem_addr,
            (unsigned long long)mem_val
        );
    }
    else if (mem_access) {
        fprintf(out, ", MEM 0x%016llx", (unsigned long long)mem_addr);
    }
    else if (trace_csr_we) {
        write_csr_trace(out, csr_addr, csr_data);
    }
    fprintf(out, "\n");
    fflush(out);

#ifdef MAVERIC_CONTINUE_AFTER_TRAP
    // The write to tohost is the terminating event for riscv-tests: commit it
    // (done above), then end the trace so the ensuing write_tohost spin loop is
    // not logged. Without -C the run stops at the trap and never reaches here.
    if (mem_we && mem_addr == TOHOST_ADDRESS) {
        trace_complete = 1;
    }
#endif
}

#ifdef __cplusplus
}
#endif
