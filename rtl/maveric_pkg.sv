/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 03/07/2026
// Last Revision: 16/07/2026
//------------------------------

// -------------------------------------------------------------------------
// Central configuration package for the Maveric RV64 core.
//
// - maveric_pkg : parameterized widths (XLEN and friends) + AXI widths.
// - csr_pkg     : CSR address, privilege-level and trap-cause encodings.
// -------------------------------------------------------------------------

`ifndef MAVERIC_PKG_SV
`define MAVERIC_PKG_SV

package maveric_pkg;

    /* verilator lint_off UNUSEDPARAM */
    localparam int unsigned XLEN        = 64;

    // Other core widths.
    localparam int unsigned WORD_WIDTH  = 32; // RV64 *W word operations.
    localparam int unsigned INSTR_WIDTH = 32;
    localparam int unsigned REG_ADDR_W  = 5;
    localparam int unsigned CSR_ADDR_W  = 12;
    localparam int unsigned CAUSE_W     = 6;
    localparam int unsigned PRIV_W      = 2;
    localparam int unsigned PMP_ADDR_W  = 54;
    localparam int unsigned PMP_N       = 16;
    localparam int unsigned PA_W        = 56;

    // AXI4-Lite interface widths.
    localparam int unsigned AXI_ADDR_WIDTH = 64;
    localparam int unsigned AXI_DATA_WIDTH = 32;

    /* verilator lint_on UNUSEDPARAM */

endpackage



/* verilator lint_off DECLFILENAME */
package csr_pkg;

    //----------------------------
    // Privilege-level encodings.
    //----------------------------
    typedef enum logic [maveric_pkg::PRIV_W - 1:0] {
        PRIV_U = 2'b00,
        PRIV_S = 2'b01,
        PRIV_M = 2'b11
    } priv_lvl_t;

    //-------------------------------------------------
    // CSR addresses. Edit one line to relocate a CSR.
    //-------------------------------------------------
    typedef enum logic [maveric_pkg::CSR_ADDR_W - 1:0] {
        // Machine level CSRs.
        CSR_MSTATUS       = 12'h300,
        CSR_MISA          = 12'h301,
        CSR_MEDELEG       = 12'h302,
        CSR_MIDELEG       = 12'h303,
        CSR_MIE           = 12'h304,
        CSR_MTVEC         = 12'h305,
        CSR_MCOUNTEREN    = 12'h306,
        CSR_MCOUNTINHIBIT = 12'h320,
        CSR_MSCRATCH      = 12'h340,
        CSR_MEPC          = 12'h341,
        CSR_MCAUSE        = 12'h342,
        CSR_MTVAL         = 12'h343,
        CSR_MIP           = 12'h344,
        CSR_MENVCFG       = 12'h30A,
        CSR_PMPCFG0       = 12'h3A0,
        CSR_PMPCFG1       = 12'h3A2,
        CSR_PMPADDR0      = 12'h3B0,
        CSR_PMPADDR1      = 12'h3B1,
        CSR_PMPADDR2      = 12'h3B2,
        CSR_PMPADDR3      = 12'h3B3,
        CSR_PMPADDR4      = 12'h3B4,
        CSR_PMPADDR5      = 12'h3B5,
        CSR_PMPADDR6      = 12'h3B6,
        CSR_PMPADDR7      = 12'h3B7,
        CSR_PMPADDR8      = 12'h3B8,
        CSR_PMPADDR9      = 12'h3B9,
        CSR_PMPADDR10     = 12'h3BA,
        CSR_PMPADDR11     = 12'h3BB,
        CSR_PMPADDR12     = 12'h3BC,
        CSR_PMPADDR13     = 12'h3BD,
        CSR_PMPADDR14     = 12'h3BE,
        CSR_PMPADDR15     = 12'h3BF,
        CSR_MCYCLE        = 12'hB00,
        CSR_MINSTRET      = 12'hB02,
        CSR_MVENDORID     = 12'hF11,
        CSR_MARCHID       = 12'hF12,
        CSR_MIMPID        = 12'hF13,
        CSR_MHARTID       = 12'hF14,
        CSR_MCONFIGPTR    = 12'hF15,

        // Supervisor level CSRs.
        CSR_SSTATUS    = 12'h100,
        CSR_SIE        = 12'h104,
        CSR_STVEC      = 12'h105,
        CSR_SCOUNTEREN = 12'h106,
        CSR_SSCRATCH   = 12'h140,
        CSR_SEPC       = 12'h141,
        CSR_SCAUSE     = 12'h142,
        CSR_STVAL      = 12'h143,
        CSR_SIP        = 12'h144,
        CSR_STIMECMP   = 12'h14D,
        CSR_SATP       = 12'h180,

        // Unprivileged CSRs.
        CSR_CYCLE     = 12'hC00,
        CSR_TIME      = 12'hC01,
        CSR_INSTRET   = 12'hC02
    } csr_addr_t;

    //--------------------------------------------------------------------
    // Trap causes (mcause/scause). MSB = 1 => interrupt, 0 => exception.
    //--------------------------------------------------------------------
    typedef enum logic [maveric_pkg::CAUSE_W - 1:0] {
        // Exceptions.
        EXC_INSTR_ADDR_MA      = 6'd0,
        EXC_INSTR_ACCESS_FAULT = 6'd1,
        EXC_ILLEGAL_INSTR      = 6'd2,
        EXC_BREAKPOINT         = 6'd3,
        EXC_LOAD_ADDR_MA       = 6'd4,
        EXC_LOAD_ACCESS_FAULT  = 6'd5,
        EXC_STORE_ADDR_MA      = 6'd6,
        EXC_STORE_ACCESS_FAULT = 6'd7,
        EXC_U_ENV_CALL         = 6'd8,
        EXC_S_ENV_CALL         = 6'd9,
        EXC_M_ENV_CALL         = 6'd11,
        EXC_INSTR_PAGE_FAULT   = 6'd12,
        EXC_LOAD_PAGE_FAULT    = 6'd13,
        EXC_STORE_PAGE_FAULT   = 6'd15,
        EXC_DOUBLE_TRAP        = 6'd16,
        EXC_SW_CHECK           = 6'd18,
        EXC_HW_ERROR           = 6'd19,

        // Interrupts ({1'b1, code}).
        IRQ_S_SW               = {1'b1, 5'd1},
        IRQ_M_SW               = {1'b1, 5'd3},
        IRQ_S_TIMER            = {1'b1, 5'd5},
        IRQ_M_TIMER            = {1'b1, 5'd7},
        IRQ_S_EXT              = {1'b1, 5'd9},
        IRQ_M_EXT              = {1'b1, 5'd11}
    } trap_cause_t;

    typedef struct packed {
        logic [maveric_pkg::PMP_N - 1:0] R;
        logic [maveric_pkg::PMP_N - 1:0] W;
        logic [maveric_pkg::PMP_N - 1:0] X;
        logic [maveric_pkg::PMP_N - 1:0] L;
        logic [maveric_pkg::PMP_N - 1:0] active;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr0_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr0_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr1_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr1_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr2_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr2_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr3_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr3_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr4_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr4_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr5_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr5_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr6_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr6_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr7_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr7_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr8_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr8_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr9_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr9_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr10_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr10_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr11_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr11_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr12_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr12_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr13_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr13_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr14_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr14_hi;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr15_lo;
        logic [maveric_pkg::PA_W  - 1:0] pmpaddr15_hi;
    } pmp_t;

endpackage
/* verilator lint_on DECLFILENAME */

`endif
