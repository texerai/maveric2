#include <stdio.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

static int print_a0_status(uint8_t a0) {
    if (a0 == 0) {
        printf("PASS\n");
        return 1;
    }
    if (a0 == 1) {
        printf("FAIL\n");
        return 1;
    }

    printf("UNDEFINED value stored in a0 register\n");
    return 1;
}

static uint8_t latest_a0 = 1;

void check_update(uint8_t a0) {
    latest_a0 = a0;
}

int check(uint8_t a0, uint8_t trap_cause, uint16_t branch_total, uint16_t branch_mispred, uint64_t pc) {
    (void)branch_total;
    (void)branch_mispred;


    // Only ebreak (3) and ecall from U/S/M mode (8/9/11) terminate a run. Every
    // other trap -- illegal instruction, address-misaligned, access fault,
    // interrupt (cause bit 5 set), ... -- is serviced by the program's own trap
    // handler, so the simulation must keep running regardless of the -C flag.
    int is_ebreak_or_ecall =
        (trap_cause == 3) || (trap_cause == 8) || (trap_cause == 9) || (trap_cause == 11);
    if (!is_ebreak_or_ecall) {
        switch (trap_cause) {
            case 0:  printf("Instruction address misaligned at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 1:  printf("Instruction access fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 2:  printf("Illegal instruction at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 3:  printf("Breakpoint (EBREAK) at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 4:  printf("Load address misaligned at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 5:  printf("Load access fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 6:  printf("Store/AMO address misaligned at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 7:  printf("Store/AMO access fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 8:  printf("Environment call from U-mode at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 9:  printf("Environment call from S-mode at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 11: printf("Environment call from M-mode at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 12: printf("Instruction page fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 13: printf("Load page fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 14: printf("Reserved exception cause at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 15: printf("Store/AMO page fault at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 16: printf("Double trap at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 17: printf("Reserved exception cause at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 18: printf("Software-check exception at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 19: printf("Hardware-error exception at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 33: printf("SSI at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 35: printf("MSI at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 37: printf("STI at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 39: printf("MTI at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 41: printf("SEI at PC 0x%016llx\n", (unsigned long long)pc); break;
            case 43: printf("MEI at PC 0x%016llx\n", (unsigned long long)pc); break;

            default:
                if (trap_cause >= 24 && trap_cause <= 31)
                    printf("Reserved exception cause%d at PC 0x%016llx\n", (unsigned long long)pc, trap_cause);
                else if (trap_cause >= 32 && trap_cause <= 47)
                    printf("Custom exception cause %d at PC 0x%016llx\n", (unsigned long long)pc, trap_cause);
                else if (trap_cause >= 48 && trap_cause <= 63)
                    printf("Reserved exception cause at PC 0x%016llx\n", (unsigned long long)pc);
                else if (trap_cause >= 64)
                    printf("Custom exception cause %d at PC 0x%016llx\n", (unsigned long long)pc, trap_cause);
                else
                    printf("Unknown exception cause%d at PC 0x%016llx\n", (unsigned long long)pc, trap_cause);
                break;
        }
        return 0;
    }
    else {
        check_update(a0);
    }

#ifdef MAVERIC_CONTINUE_AFTER_TRAP
    // -C: run past the terminating trap too; the program resumes it via mret.
    return 0;
#else
    return print_a0_status(a0);
#endif
}

int check_final(uint16_t branch_total, uint16_t branch_mispred) {
    (void)branch_total;
    (void)branch_mispred;
    return print_a0_status(latest_a0);
}

#ifdef __cplusplus
}
#endif
