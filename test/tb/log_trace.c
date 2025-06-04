#include <stdio.h>
#include <stdint.h>


int log_trace(uint64_t pc,  uint32_t instruction, uint64_t reg_val, uint8_t reg_addr, uint8_t reg_we, uint8_t mem_access,
            uint64_t mem_val, uint64_t mem_addr, uint8_t mem_we) {
    if (instruction != 0x00000073) {
        printf ("PC: 0x%016llx, INSTR: 0x%08x", (unsigned long long)pc, instruction);
    }

    if (reg_we) {
		    printf(", REG x%u: 0x%016llx", (unsigned int)reg_addr, (unsigned long long)reg_val);
				if (mem_access) {
            printf(", MEM 0x%016llx", (unsigned long long)mem_addr); 
        }
    }
    else if (mem_we) {
        printf(", MEM 0x%016llx: 0x%016llx", (unsigned long long)mem_addr, (unsigned long long)mem_val);
    }
    printf("\n");

    return 0;
}

