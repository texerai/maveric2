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

#ifdef MAVERIC_CONTINUE_AFTER_TRAP
    if ((trap_cause == 11) || (trap_cause == 8) || (trap_cause == 9) || (trap_cause == 3) || (trap_cause & 0x20)) {
        return 0;
    }
#endif

    if ((trap_cause == 11) || (trap_cause == 3) || (trap_cause == 8) || (trap_cause == 9)) {
        return print_a0_status(a0);
    }
    if (trap_cause == 2) {
        printf("ILLEGAL INSTRUCTION\n");
    }
    else if (trap_cause == 0) {
        printf("INSTRUCTION ADDR MISALIGNED\n");
    }
    else if (trap_cause == 4) {
        printf("LOAD ADDR MISALIGNED\n");
    }
    else if (trap_cause == 6) {
        printf("STORE ADDR MISALIGNED\n");
    }
    else {
        printf("UNDEFINED ERROR trap_cause value: %d\n", (uint32_t)(trap_cause));
    }

    return 1;
}

int check_final(uint16_t branch_total, uint16_t branch_mispred) {
    (void)branch_total;
    (void)branch_mispred;
    return print_a0_status(latest_a0);
}

#ifdef __cplusplus
}
#endif
