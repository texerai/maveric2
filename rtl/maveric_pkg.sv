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
        CSR_MSTATUS   = 12'h300,
        CSR_MISA      = 12'h301,
        CSR_MEDELEG   = 12'h302,
        CSR_MIDELEG   = 12'h303,
        CSR_MIE       = 12'h304,
        CSR_MTVEC     = 12'h305,
        CSR_MCOUNTEREN = 12'h306,
        CSR_MSCRATCH  = 12'h340,
        CSR_MEPC      = 12'h341,
        CSR_MCAUSE    = 12'h342,
        CSR_MTVAL     = 12'h343,
        CSR_MIP       = 12'h344,
        CSR_MENVCFG   = 12'h30A,
        CSR_PMPCFG0   = 12'h3A0,
        CSR_PMPADDR0  = 12'h3B0,
        CSR_MCYCLE    = 12'hB00,
        CSR_MINSTRET  = 12'hB02,
        CSR_MVENDORID = 12'hF11,
        CSR_MARCHID   = 12'hF12,
        CSR_MIMPID    = 12'hF13,
        CSR_MHARTID   = 12'hF14,

        // Supervisor level CSRs.
        CSR_SSTATUS   = 12'h100,
        CSR_SIE       = 12'h104,
        CSR_STVEC     = 12'h105,
        CSR_SCOUNTEREN = 12'h106,
        CSR_SSCRATCH  = 12'h140,
        CSR_SEPC      = 12'h141,
        CSR_SCAUSE    = 12'h142,
        CSR_STVAL     = 12'h143,
        CSR_SIP       = 12'h144,
        CSR_STIMECMP  = 12'h14D,
        CSR_SATP      = 12'h180,

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

endpackage
/* verilator lint_on DECLFILENAME */

`endif
