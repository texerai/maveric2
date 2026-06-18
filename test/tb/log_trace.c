#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define RTL_TRACE_FILE_ENV "MAVERIC_RTL_TRACE_FILE"
#define ECALL_INSTRUCTION 0x00000073u
#define EBREAK_INSTRUCTION 0x00100073u
#define MRET_INSTRUCTION 0x30200073u
#define SELF_LOOP_INSTRUCTION 0x0000006fu

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

static void write_csr_trace(FILE *out, uint16_t csr_addr, uint64_t csr_data) {
    switch (csr_addr) {
        case 0x300: // mstatus
            fprintf(
                out,
                ", c%u_mstatus: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0x304: // mie
            fprintf(
                out,
                ", c%u_mie: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0x305: // mtvec
            fprintf(
                out,
                ", c%u_mtvec: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0x341: // mepc
            fprintf(
                out,
                ", c%u_mepc: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0x342: // mcause
            fprintf(
                out,
                ", c%u_mcause: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0x344: // mip
            fprintf(
                out,
                ", c%u_mip: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        case 0xc01: // time
            fprintf(
                out,
                ", c%u_time: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
        default:
            fprintf(
                out,
                ", c%u: 0x%016llx",
                csr_addr,
                (unsigned long long)csr_data
            );
            break;
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

#ifndef MAVERIC_CONTINUE_AFTER_TRAP
    if (instruction == ECALL_INSTRUCTION || instruction == EBREAK_INSTRUCTION) {
        trace_complete = 1;
        return;
    }
#else
    if (instruction == ECALL_INSTRUCTION || instruction == EBREAK_INSTRUCTION) {
        return;
    }
    if (instruction == SELF_LOOP_INSTRUCTION) {
        return;
    }
    if (instruction == MRET_INSTRUCTION) {
        trace_csr_we = 0;
    }
#endif

    out = get_trace_file();
    if (out == NULL) {
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
        if (mem_access) {
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
}

#ifdef __cplusplus
}
#endif
