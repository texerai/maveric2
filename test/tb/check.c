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

int check(uint8_t a0, uint8_t trap_cause, uint16_t branch_total, uint16_t branch_mispred) {
    (void)branch_total;
    (void)branch_mispred;

    check_update(a0);

    // Only ebreak (3) and ecall from U/S/M mode (8/9/11) terminate a run. Every
    // other trap -- illegal instruction, address-misaligned, access fault,
    // interrupt (cause bit 5 set), ... -- is serviced by the program's own trap
    // handler, so the simulation must keep running regardless of the -C flag.
    int is_ebreak_or_ecall =
        (trap_cause == 3) || (trap_cause == 8) || (trap_cause == 9) || (trap_cause == 11);
    if (!is_ebreak_or_ecall) {
        return 0;
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
