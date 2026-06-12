#include <stdio.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int log_trace(uint64_t pc,  uint32_t instruction, uint64_t reg_val, uint8_t reg_addr, uint8_t reg_we, uint8_t mem_access,
            uint64_t mem_val, uint64_t mem_addr, uint8_t mem_we, uint8_t csr_we, uint16_t csr_addr, uint64_t csr_data) {
    if (instruction != 0x00000073) {
        printf ("PC: 0x%016llx, INSTR: 0x%08x", (unsigned long long)pc, instruction);
    }

    if (reg_we) {
        printf(", REG x%u: 0x%016llx", (unsigned int)reg_addr, (unsigned long long)reg_val);
        if (mem_access) {
            printf(", MEM 0x%016llx", (unsigned long long)mem_addr);
        }
        else if (csr_we) {
            switch (csr_addr) {
                case 0x305: // mtvec
                    printf(", c%d_mtvec: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                    break;
                case 0x341: // mepc
                    printf(", c%d_mepc: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                    break;
                case 0x342: // mcause
                    printf(", c%d_mcause: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                    break;
                default:
                    printf(", c%d: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                    break;
            }
        }
    }
    else if (mem_we) {
        printf(", MEM 0x%016llx: 0x%016llx", (unsigned long long)mem_addr, (unsigned long long)mem_val);
    }
    else if (mem_access) {
        printf(", MEM 0x%016llx", (unsigned long long)mem_addr);
    }
    else if (csr_we) {
        switch (csr_addr) {
            case 0x305: // mtvec
                printf(", c%d_mtvec: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                break;
            case 0x341: // mepc
                printf(", c%d_mepc: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                break;
            case 0x342: // mcause
                printf(", c%d_mcause: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                break;
            default:
                printf(", c%d: 0x%016llx", csr_addr, (unsigned long long)csr_data);
                break;
        }
    }
    printf("\n");

    return 0;
}

#ifdef __cplusplus
}
#endif

