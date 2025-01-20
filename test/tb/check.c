 #include <stdio.h>
 #include <stdint.h>


int check(int8_t a0, int8_t mcause, uint16_t branch_total, uint16_t branch_mispred) {
    double accuracy = 100 - 100 * (double) branch_mispred / branch_total;

    if ((mcause == 11) || (mcause == 3) ) {
        if ( a0 == 0 ) printf ("PASS | TOTAL BRANCH INSTRUCTIONS: %4d | TOTAL MISPREDICTED BRANCHES: %4d | ACCURACY: %.2f%%\n", branch_total, branch_mispred, accuracy);
        else if ( a0 == 1 ) printf ("FAIL\n");
        else printf ("UNDEFINED value stored in a0 register\n");
    }
    else if ( mcause == 2 ) printf("ILLEGAL INSTRUCTION\n");
    else if ( mcause == 0 ) printf("INSTRUCTION ADDR MISALIGNED\n");
    else if ( mcause == 4 ) printf("LOAD ADDR MISALIGNED\n");
    else if ( mcause == 6 ) printf("STORE ADDR MISALIGNED\n");
    else printf ("UNDEFINED ERROR\n");

    return 0;

}
