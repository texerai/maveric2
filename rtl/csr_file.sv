/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 16/07/2026
//------------------------------

// -------------------------------------------------------------
// This is a csr register file with all the CSRs implemented in
// the design. Currently implemented list of CSRs:
// - Machine Information Registers: mvendorid, marchid, mimpid
//   mhartid. All set to 0.
// - Machine Trap Setup: mstatus, misa, mie, mtvec, medeleg,
//   mideleg.
// - Machine Trap Handling: mscratch, mepc, mcause, mtval, mip
//
// Current state is as follows:
// - Interrupt handling across several priv lvls.
// - Trap handling across several priv lvls.
// - Delegation across several priv lvls.
// - Mstatus/Sstatus properly written
// - Illegal instriction fire if priv level doesn't match
//   access level.
// -------------------------------------------------------------

`include "maveric_pkg.sv"

module csr_file
// Parameters.
#(
    parameter XLEN       = maveric_pkg::XLEN,
    parameter CSR_ADDR_W = maveric_pkg::CSR_ADDR_W,
    parameter CAUSE_W    = maveric_pkg::CAUSE_W,
    parameter RESET_VAL  = '0
)
// Port decleration.
(
    // Common clock & reset signals.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic                    we_i,
    input  logic [XLEN       - 1:0] wdata_i,
    input  logic [CSR_ADDR_W - 1:0] raddr_i,
    input  logic [CSR_ADDR_W - 1:0] waddr_i,
    input  logic                    csr_access_i,
    input  logic [XLEN       - 1:0] xepc_wdata_i,
    input  logic [CAUSE_W    - 1:0] xcause_wdata_i,
    input  logic [XLEN       - 1:0] xtval_wdata_i,
    input  logic                    trap_taken_i,
    input  logic                    trap_mret_i,
    input  logic                    trap_sret_i,
    input  logic [XLEN       - 1:0] mtime_val_i,
    input  logic                    timer_irq_i,
    input  logic                    software_irq_i,
    input  logic                    instr_ret_i,

    // Output interface.
    output logic [             1:0] priv_mode_o,
    output logic [XLEN       - 1:0] csr_xtvec_rdata_o,
    output logic [XLEN       - 1:0] csr_xepc_rdata_o,
    output logic                    illegal_instr_o,
    output logic                    iqr_detected_o,
    output logic [CAUSE_W    - 1:0] trap_cause_o,
    output logic [XLEN       - 1:0] satp_rdata_o,
    output logic [XLEN       - 1:0] mstatus_rdata_o,
    output logic [XLEN       - 1:0] mstatus_rdata_log_o,
    output logic [XLEN       - 1:0] rdata_o
);
    //----------------------------
    // Local parameters.
    //----------------------------
    // Privilege-level, CSR-address and trap-cause encodings are centralized in
    // csr_pkg (see maveric_pkg.sv); referenced below via explicit scope.
    localparam logic [XLEN       - 1:0] MISA_VALUE =
        (64'h2 << 62) |   // MXL = 2 for RV64.
        (64'h1 << 0)  |   // A.
        (64'h1 << 8)  |   // I.
        (64'h1 << 12) |   // M.
        (64'h1 << 18) |   // S-mode.
        (64'h1 << 20);    // U-mode.


    //----------------------------
    // Internal nets.
    //----------------------------
    // Privilege mode register states.
    logic [1:0] priv_mode_d;
    logic [1:0] priv_mode_q;
    logic       priv_mode_we;

    logic mstatus_we;
    logic medeleg_we;
    logic mideleg_we;
    logic mie_we;
    logic mtvec_we;
    logic mcounteren_we;
    logic mscratch_we;
    logic mepc_we;
    logic mcause_we;
    logic mtval_we;
    logic mip_ssip_we;
    logic menvcfg_stce_we;
    logic mcycle_we;
    logic minstret_we;
    logic stvec_we;
    logic scounteren_we;
    logic sscratch_we;
    logic sepc_we;
    logic scause_we;
    logic stval_we;
    logic stimecmp_we;
    logic satp_we;

    logic [XLEN    - 1:0] mstatus_wdata_d;
    logic [XLEN    - 1:0] medeleg_wdata_d;
    logic [XLEN    - 1:0] mideleg_wdata_d;
    logic [XLEN    - 1:0] mie_wdata_d;
    logic [XLEN    - 1:0] mtvec_wdata_d;
    logic [         31:0] mcounteren_wdata_d;
    logic [XLEN    - 1:0] mscratch_wdata_d;
    logic [XLEN    - 1:0] mepc_wdata_d;
    logic [CAUSE_W - 1:0] mcause_wdata_d;
    logic [XLEN    - 1:0] mtval_wdata_d;
    logic                 mip_ssip_wdata_d;
    logic [XLEN    - 1:0] mip_data;
    logic                 menvcfg_stce_wdata_d;
    logic [XLEN    - 1:0] mcycle_wdata_d;
    logic [XLEN    - 1:0] minstret_wdata_d;
    logic [XLEN    - 1:0] stvec_wdata_d;
    logic [         31:0] scounteren_wdata_d;
    logic [XLEN    - 1:0] sscratch_wdata_d;
    logic [XLEN    - 1:0] sepc_wdata_d;
    logic [CAUSE_W - 1:0] scause_wdata_d;
    logic [XLEN    - 1:0] stval_wdata_d;
    logic [XLEN    - 1:0] stimecmp_wdata_d;
    logic [XLEN    - 1:0] satp_wdata_d;

    logic [XLEN    - 1:0] mstatus_rdata_q;
    logic [XLEN    - 1:0] medeleg_rdata_q;
    logic [XLEN    - 1:0] mideleg_rdata_q;
    logic [XLEN    - 1:0] mie_rdata_q;
    logic [XLEN    - 1:0] mtvec_rdata_q;
    logic [         31:0] mcounteren_rdata_q;
    logic [XLEN    - 1:0] mscratch_rdata_q;
    logic [XLEN    - 1:0] mepc_rdata_q;
    logic [CAUSE_W - 1:0] mcause_rdata_q;
    logic [XLEN    - 1:0] mtval_rdata_q;
    logic                 mip_ssip_rdata_q;
    logic                 menvcfg_stce_rdata_q;
    logic [XLEN    - 1:0] mcycle_rdata_q;
    logic [XLEN    - 1:0] minstret_rdata_q;
    logic [XLEN    - 1:0] stvec_rdata_q;
    logic [         31:0] scounteren_rdata_q;
    logic [XLEN    - 1:0] sscratch_rdata_q;
    logic [XLEN    - 1:0] sepc_rdata_q;
    logic [CAUSE_W - 1:0] scause_rdata_q;
    logic [XLEN    - 1:0] stval_rdata_q;
    logic [XLEN    - 1:0] stimecmp_rdata_q;
    logic [XLEN    - 1:0] satp_rdata_q;

    logic mcause_legal;
    logic scause_legal;
    logic satp_legal;

    logic delegate;


    logic                 m_mode_timer_irq;
    logic                 m_mode_software_irq;
    logic                 m_mode_irq;
    logic [CAUSE_W - 1:0] m_mode_irq_cause;
    logic                 s_mode_timer_irq;
    logic                 s_mode_software_irq;
    logic                 s_mode_irq;
    logic [CAUSE_W - 1:0] s_mode_irq_cause;


    //----------------------------
    // Determine legal cause.
    //----------------------------

    always_comb begin
        mcause_legal = 1'b0;
        scause_legal = 1'b0;

        case ({wdata_i[XLEN - 1], wdata_i[CAUSE_W - 2:0]})
            csr_pkg::IRQ_S_SW,
            csr_pkg::IRQ_S_TIMER,
            csr_pkg::IRQ_S_EXT,
            csr_pkg::EXC_INSTR_ADDR_MA,
            csr_pkg::EXC_INSTR_ACCESS_FAULT,
            csr_pkg::EXC_ILLEGAL_INSTR,
            csr_pkg::EXC_BREAKPOINT,
            csr_pkg::EXC_LOAD_ADDR_MA,
            csr_pkg::EXC_LOAD_ACCESS_FAULT,
            csr_pkg::EXC_STORE_ADDR_MA,
            csr_pkg::EXC_STORE_ACCESS_FAULT,
            csr_pkg::EXC_U_ENV_CALL,
            csr_pkg::EXC_S_ENV_CALL,
            csr_pkg::EXC_INSTR_PAGE_FAULT,
            csr_pkg::EXC_LOAD_PAGE_FAULT,
            csr_pkg::EXC_STORE_PAGE_FAULT,
            csr_pkg::EXC_SW_CHECK,
            csr_pkg::EXC_HW_ERROR: begin
                mcause_legal = 1'b1;
                scause_legal = 1'b1;
            end
            csr_pkg::IRQ_M_SW,
            csr_pkg::IRQ_M_TIMER,
            csr_pkg::IRQ_M_EXT,
            csr_pkg::EXC_M_ENV_CALL,
            csr_pkg::EXC_DOUBLE_TRAP: begin
                mcause_legal = 1'b1;
            end
            default: begin
                mcause_legal = 1'b0;
                scause_legal = 1'b0;
            end
        endcase
    end

    //----------------------------
    // Determine legal access.
    //----------------------------
    always_comb begin
        // Default values.
        illegal_instr_o = 1'b0;

        if (csr_access_i) begin
            if (priv_mode_o == csr_pkg::PRIV_M) begin
                case (raddr_i)
                    csr_pkg::CSR_MSTATUS,
                    csr_pkg::CSR_MISA,
                    csr_pkg::CSR_MEDELEG,
                    csr_pkg::CSR_MIDELEG,
                    csr_pkg::CSR_MIE,
                    csr_pkg::CSR_MTVEC,
                    csr_pkg::CSR_MCOUNTEREN,
                    csr_pkg::CSR_MSCRATCH,
                    csr_pkg::CSR_MEPC,
                    csr_pkg::CSR_MCAUSE,
                    csr_pkg::CSR_MTVAL,
                    csr_pkg::CSR_MIP,
                    csr_pkg::CSR_MENVCFG,
                    csr_pkg::CSR_MCYCLE,
                    csr_pkg::CSR_MINSTRET,
                    csr_pkg::CSR_PMPCFG0,
                    csr_pkg::CSR_PMPADDR0,
                    csr_pkg::CSR_MVENDORID,
                    csr_pkg::CSR_MARCHID,
                    csr_pkg::CSR_MIMPID,
                    csr_pkg::CSR_MHARTID,
                    csr_pkg::CSR_SSTATUS,
                    csr_pkg::CSR_SIE,
                    csr_pkg::CSR_STVEC,
                    csr_pkg::CSR_SCOUNTEREN,
                    csr_pkg::CSR_SSCRATCH,
                    csr_pkg::CSR_SEPC,
                    csr_pkg::CSR_SCAUSE,
                    csr_pkg::CSR_STVAL,
                    csr_pkg::CSR_SIP,
                    csr_pkg::CSR_STIMECMP,
                    csr_pkg::CSR_SATP,
                    csr_pkg::CSR_CYCLE,
                    csr_pkg::CSR_TIME,
                    csr_pkg::CSR_INSTRET: illegal_instr_o = 1'b0;
                    default             : illegal_instr_o = 1'b1;
                endcase
            end else if (priv_mode_o == csr_pkg::PRIV_S) begin
                case (raddr_i)
                    csr_pkg::CSR_SSTATUS,
                    csr_pkg::CSR_SIE,
                    csr_pkg::CSR_STVEC,
                    csr_pkg::CSR_SCOUNTEREN,
                    csr_pkg::CSR_SSCRATCH,
                    csr_pkg::CSR_SEPC,
                    csr_pkg::CSR_SCAUSE,
                    csr_pkg::CSR_STVAL,
                    csr_pkg::CSR_SIP,
                    csr_pkg::CSR_SATP    : illegal_instr_o = 1'b0;
                    csr_pkg::CSR_STIMECMP: illegal_instr_o = !menvcfg_stce_rdata_q;
                    csr_pkg::CSR_CYCLE   : illegal_instr_o = !mcounteren_rdata_q[0];
                    csr_pkg::CSR_TIME    : illegal_instr_o = !mcounteren_rdata_q[1];
                    csr_pkg::CSR_INSTRET : illegal_instr_o = !mcounteren_rdata_q[2];
                    default              : illegal_instr_o = 1'b1;
                endcase
            end else if (priv_mode_o == csr_pkg::PRIV_U) begin
                case (raddr_i)
                    csr_pkg::CSR_CYCLE   : illegal_instr_o = !(mcounteren_rdata_q[0] & scounteren_rdata_q[0]);
                    csr_pkg::CSR_TIME    : illegal_instr_o = !(mcounteren_rdata_q[1] & scounteren_rdata_q[1]);
                    csr_pkg::CSR_INSTRET : illegal_instr_o = !(mcounteren_rdata_q[2] & scounteren_rdata_q[2]);
                    default              : illegal_instr_o = 1'b1;
                endcase
            end else begin
                illegal_instr_o = 1'b1;
            end
        end

    end


    //--------------------------------
    // Determine legal satp value.
    // Only bare & Sv39 is supported.
    //--------------------------------
    always_comb begin
        satp_legal = 1'b0;

        case ({wdata_i[XLEN - 1:XLEN - 4]})
            4'd0,
            4'd8: satp_legal = 1'b1;
            default: begin
                satp_legal = 1'b0;
            end
        endcase
    end



    //-----------------------------
    // Determine delegation logic.
    //-----------------------------
    assign delegate = (priv_mode_q < csr_pkg::PRIV_M) &
                      (xcause_wdata_i[CAUSE_W - 1] ? mideleg_rdata_q[{1'b0, xcause_wdata_i[CAUSE_W - 2:0]}] : medeleg_rdata_q[xcause_wdata_i]);


    //----------------------------
    // Write logic decode.
    //----------------------------

    // Write 0.
    always_comb begin
        // Default values.
        csr_xtvec_rdata_o = '0;
        csr_xepc_rdata_o  = '0;
        priv_mode_we      = '0;
        priv_mode_d       = '0;

        mstatus_we      = 1'b0;
        medeleg_we      = 1'b0;
        mideleg_we      = 1'b0;
        mie_we          = 1'b0;
        mtvec_we        = 1'b0;
        mcounteren_we   = 1'b0;
        mscratch_we     = 1'b0;
        mepc_we         = 1'b0;
        mcause_we       = 1'b0;
        mtval_we        = 1'b0;
        mip_ssip_we     = 1'b0;
        menvcfg_stce_we = 1'b0;
        mcycle_we       = 1'b0;
        minstret_we     = 1'b0;
        stvec_we        = 1'b0;
        scounteren_we   = 1'b0;
        sscratch_we     = 1'b0;
        sepc_we         = 1'b0;
        scause_we       = 1'b0;
        stval_we        = 1'b0;
        stimecmp_we     = 1'b0;
        satp_we         = 1'b0;

        mstatus_wdata_d      = '0;
        medeleg_wdata_d      = '0;
        mideleg_wdata_d      = '0;
        mie_wdata_d          = '0;
        mtvec_wdata_d        = '0;
        mcounteren_wdata_d   = '0;
        mscratch_wdata_d     = '0;
        mepc_wdata_d         = '0;
        mcause_wdata_d       = '0;
        mtval_wdata_d        = '0;
        mip_ssip_wdata_d     = '0;
        mip_data             = '0;
        menvcfg_stce_wdata_d = '0;
        mcycle_wdata_d       = '0;
        minstret_wdata_d     = '0;
        stvec_wdata_d        = '0;
        scounteren_wdata_d   = '0;
        sscratch_wdata_d     = '0;
        sepc_wdata_d         = '0;
        scause_wdata_d       = '0;
        stval_wdata_d        = '0;
        stimecmp_wdata_d     = '0;
        satp_wdata_d         = '0;


        // Increment CSRs.
        mcycle_we        = 1'b1;
        mcycle_wdata_d   = mcycle_rdata_q + {{(XLEN - 1){1'b0}}, 1'b1};
        minstret_we      = instr_ret_i;
        minstret_wdata_d = minstret_rdata_q + {{(XLEN - 1){1'b0}}, 1'b1};


        if (we_i) begin
            case (waddr_i)
                // Machine level CSRs.
                csr_pkg::CSR_MSTATUS: begin
                    mstatus_we      = 1'b1;
                    // mstatus_wdata_d = {32'b1010, 12'b0, wdata_i[19:17], 4'b0,
                    //                                     wdata_i[12:11], 2'b0,
                    //                                     wdata_i[ 8:7 ], 1'b0,
                    //                                     wdata_i[ 5   ], 1'b0,
                    //                                     wdata_i[ 3   ], 1'b0,
                    //                                     wdata_i[ 1   ], 1'b0};
                    mstatus_wdata_d = {((&wdata_i[14:13]) || (&wdata_i[14:13])), 31'b1010, 12'b0,
                                                        wdata_i[19:17], 2'b0,
                                                        wdata_i[14:7 ], 1'b0,
                                                        wdata_i[ 5   ], 1'b0,
                                                        wdata_i[ 3   ], 1'b0,
                                                        wdata_i[ 1   ], 1'b0};
                end
                csr_pkg::CSR_MEDELEG: begin
                    medeleg_we      = 1'b1;
                    medeleg_wdata_d = {44'b0, wdata_i[19:18], 2'b0,
                                              wdata_i[15   ], 1'b0,
                                              wdata_i[13:12], 2'b0,
                                              wdata_i[ 9:0 ]};
                end
                csr_pkg::CSR_MIDELEG: begin
                    mideleg_we      = 1'b1;
                    mideleg_wdata_d = {54'b0, wdata_i[9], 3'b0,
                                              wdata_i[5], 3'b0,
                                              wdata_i[1], 1'b0};
                end
                csr_pkg::CSR_MIE: begin
                    mie_we      = 1'b1;
                    mie_wdata_d = {50'b0, wdata_i[13], 1'b0,
                                          wdata_i[11], 1'b0,
                                          wdata_i[ 9], 1'b0,
                                          wdata_i[ 7], 1'b0,
                                          wdata_i[ 5], 1'b0,
                                          wdata_i[ 3], 1'b0,
                                          wdata_i[ 1], 1'b0};
                end
                csr_pkg::CSR_MTVEC: begin
                    mtvec_we      = 1'b1;
                    mtvec_wdata_d = {wdata_i[XLEN - 1:2], 1'b0, wdata_i[0]};
                end
                csr_pkg::CSR_MCOUNTEREN: begin
                    mcounteren_we      = 1'b1;
                    mcounteren_wdata_d = {29'b0, wdata_i[2:0]};
                end
                csr_pkg::CSR_MSCRATCH: begin
                    mscratch_we      = 1'b1;
                    mscratch_wdata_d = wdata_i;
                end
                csr_pkg::CSR_MEPC: begin
                    mepc_we      = 1'b1;
                    mepc_wdata_d = {wdata_i[XLEN - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
                end
                csr_pkg::CSR_MCAUSE: begin
                    mcause_we      = mcause_legal;
                    mcause_wdata_d = {wdata_i[XLEN - 1], wdata_i[CAUSE_W - 2:0]};
                end
                csr_pkg::CSR_MTVAL: begin
                    mtval_we      = 1'b1;
                    mtval_wdata_d = wdata_i;
                end
                csr_pkg::CSR_MIP: begin
                    mip_ssip_we      = 1'b1;
                    mip_ssip_wdata_d = wdata_i[1];
                end
                csr_pkg::CSR_MENVCFG: begin
                    menvcfg_stce_we      = 1'b1;
                    menvcfg_stce_wdata_d = wdata_i[XLEN - 1];
                end
                csr_pkg::CSR_MCYCLE: begin
                    mcycle_we      = 1'b1;
                    mcycle_wdata_d = wdata_i;
                end
                csr_pkg::CSR_INSTRET: begin
                    minstret_we      = 1'b1;
                    minstret_wdata_d = wdata_i;
                end


                // Supervisor level CSRs.
                csr_pkg::CSR_SSTATUS: begin
                    mstatus_we      = 1'b1;
                    // mstatus_wdata_d = {mstatus_rdata_q[63:20], wdata_i[19:18], mstatus_rdata_q[17:9],
                    //                                            wdata_i[    8], mstatus_rdata_q[ 7:6],
                    //                                            wdata_i[    5], mstatus_rdata_q[ 4:2],
                    //                                            wdata_i[    1], mstatus_rdata_q[   0]};
                    mstatus_wdata_d = {((&wdata_i[14:13]) || (&wdata_i[14:13])), mstatus_rdata_q[62:20],
                                                               wdata_i[19:18], mstatus_rdata_q[17:15],
                                                               wdata_i[14:13], mstatus_rdata_q[12:11],
                                                               wdata_i[10: 8], mstatus_rdata_q[ 7:6],
                                                               wdata_i[    5], mstatus_rdata_q[ 4:2],
                                                               wdata_i[    1], mstatus_rdata_q[   0]};
                end
                csr_pkg::CSR_SIE: begin
                    mie_we      = 1'b1;
                    mie_wdata_d = {mie_rdata_q[63:14], wdata_i[13], mie_rdata_q[12:10],
                                                       wdata_i[ 9], mie_rdata_q[ 8:6 ],
                                                       wdata_i[ 5], mie_rdata_q[ 4:2 ],
                                                       wdata_i[ 1], mie_rdata_q[ 0   ]};
                end
                csr_pkg::CSR_STVEC: begin
                    stvec_we      = 1'b1;
                    stvec_wdata_d = {wdata_i[XLEN - 1:2], 1'b0, wdata_i[0]};
                end
                csr_pkg::CSR_SCOUNTEREN: begin
                    scounteren_we      = 1'b1;
                    scounteren_wdata_d = {29'b0, wdata_i[2:0]};
                end
                csr_pkg::CSR_SSCRATCH: begin
                    sscratch_we      = 1'b1;
                    sscratch_wdata_d = wdata_i;
                end
                csr_pkg::CSR_SEPC: begin
                    sepc_we      = 1'b1;
                    sepc_wdata_d = {wdata_i[XLEN - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
                end
                csr_pkg::CSR_SCAUSE: begin
                    scause_we      = scause_legal;
                    scause_wdata_d = {wdata_i[XLEN - 1], wdata_i[CAUSE_W - 2:0]};
                end
                csr_pkg::CSR_STVAL: begin
                    stval_we      = 1'b1;
                    stval_wdata_d = wdata_i;
                end
                csr_pkg::CSR_SIP: begin
                    mip_ssip_we      = 1'b1;
                    mip_ssip_wdata_d = wdata_i[1];
                end
                csr_pkg::CSR_STIMECMP: begin
                    stimecmp_we      = 1'b1;
                    stimecmp_wdata_d = wdata_i;
                end
                csr_pkg::CSR_SATP: begin
                    satp_we      = satp_legal;
                    satp_wdata_d = wdata_i;
                end
                default: begin
                    mstatus_we      = 1'b0;
                    medeleg_we      = 1'b0;
                    mideleg_we      = 1'b0;
                    mie_we          = 1'b0;
                    mtvec_we        = 1'b0;
                    mcounteren_we   = 1'b0;
                    mscratch_we     = 1'b0;
                    mepc_we         = 1'b0;
                    mcause_we       = 1'b0;
                    mtval_we        = 1'b0;
                    mip_ssip_we     = 1'b0;
                    menvcfg_stce_we = 1'b0;
                    mcycle_we       = 1'b0;
                    minstret_we     = 1'b0;
                    stvec_we        = 1'b0;
                    scounteren_we   = 1'b0;
                    sscratch_we     = 1'b0;
                    sepc_we         = 1'b0;
                    scause_we       = 1'b0;
                    stval_we        = 1'b0;
                    stimecmp_we     = 1'b0;
                    satp_we         = 1'b0;

                    mstatus_wdata_d      = '0;
                    medeleg_wdata_d      = '0;
                    mideleg_wdata_d      = '0;
                    mie_wdata_d          = '0;
                    mtvec_wdata_d        = '0;
                    mcounteren_wdata_d   = '0;
                    mscratch_wdata_d     = '0;
                    mepc_wdata_d         = '0;
                    mcause_wdata_d       = '0;
                    mtval_wdata_d        = '0;
                    mip_ssip_wdata_d     = '0;
                    mip_data             = '0;
                    menvcfg_stce_wdata_d = '0;
                    mcycle_wdata_d       = '0;
                    minstret_wdata_d     = '0;
                    stvec_wdata_d        = '0;
                    scounteren_wdata_d   = '0;
                    sscratch_wdata_d     = '0;
                    sepc_wdata_d         = '0;
                    scause_wdata_d       = '0;
                    stval_wdata_d        = '0;
                    stimecmp_wdata_d     = '0;
                    satp_wdata_d         = '0;
                end
            endcase
        end


        // Trap taken.
        if (trap_taken_i) begin
            if (delegate) begin // Delegated to S-mode.
                csr_xtvec_rdata_o = ((stvec_rdata_q >> 2) << 2) + (64'd4 * {63'b0, stvec_rdata_q[0]});
                priv_mode_we      = 1'b1;
                priv_mode_d       = csr_pkg::PRIV_S;

                mstatus_we  = 1'b1;
                sepc_we     = 1'b1;
                scause_we   = 1'b1;
                stval_we    = 1'b1;

                mstatus_wdata_d = {mstatus_rdata_q[63:9], priv_mode_q[0], mstatus_rdata_q[7:6], mstatus_rdata_q[1], mstatus_rdata_q[4:2], 1'b0, mstatus_rdata_q[0]};
                sepc_wdata_d    = xepc_wdata_i;
                scause_wdata_d  = xcause_wdata_i;
                stval_wdata_d   = xtval_wdata_i;
            end else begin // Handled by M-mode.
                csr_xtvec_rdata_o = ((mtvec_rdata_q >> 2) << 2) + (64'd4 * {63'b0, mtvec_rdata_q[0]});
                priv_mode_we      = 1'b1;
                priv_mode_d       = csr_pkg::PRIV_M;

                mstatus_we  = 1'b1;
                mepc_we     = 1'b1;
                mcause_we   = 1'b1;
                mtval_we    = 1'b1;

                mstatus_wdata_d = {mstatus_rdata_q[63:13], priv_mode_q, mstatus_rdata_q[10:8], mstatus_rdata_q[3], mstatus_rdata_q[6:4], 1'b0, mstatus_rdata_q[2:0]};
                mepc_wdata_d    = xepc_wdata_i;
                mcause_wdata_d  = xcause_wdata_i;
                mtval_wdata_d   = xtval_wdata_i;
            end
        end
        else if (trap_mret_i) begin // MRET.
            csr_xepc_rdata_o  = mepc_rdata_q;
            priv_mode_we      = 1'b1;
            priv_mode_d       = mstatus_rdata_q[12:11];

            mstatus_we = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:18], (mstatus_rdata_q[12:11] != csr_pkg::PRIV_M) ? 1'b0 : mstatus_rdata_q[17], mstatus_rdata_q[16:13], 2'(csr_pkg::PRIV_U),
                               mstatus_rdata_q[10:8], 1'b1, mstatus_rdata_q[6:4], mstatus_rdata_q[7], mstatus_rdata_q[2:0]};
        end
        else if (trap_sret_i) begin // SRET.
            csr_xepc_rdata_o  = sepc_rdata_q;
            priv_mode_we      = 1'b1;
            priv_mode_d       = {1'b0, mstatus_rdata_q[8]};

            mstatus_we = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:9], 1'(csr_pkg::PRIV_U), mstatus_rdata_q[7:6], 1'b1, mstatus_rdata_q[4:2], mstatus_rdata_q[5], mstatus_rdata_q[0]};
        end

        // MIP.
        mip_data = {56'b0, timer_irq_i, 1'b0, (mtime_val_i >= stimecmp_rdata_q), 1'b0, software_irq_i, 1'b0, mip_ssip_rdata_q, 1'b0};

    end

    //----------------------------
    // Read logic decode.
    //----------------------------

    // Read 0.
    always_comb begin
        // Default values.
        rdata_o = '0;

        case (raddr_i)
            // Machine level CSRs.
            csr_pkg::CSR_MSTATUS : rdata_o = mstatus_rdata_q;
            csr_pkg::CSR_MISA    : rdata_o = MISA_VALUE;
            csr_pkg::CSR_MEDELEG : rdata_o = medeleg_rdata_q;
            csr_pkg::CSR_MIDELEG : rdata_o = mideleg_rdata_q;
            csr_pkg::CSR_MIE     : rdata_o = mie_rdata_q;
            csr_pkg::CSR_MTVEC   : rdata_o = mtvec_rdata_q;
            csr_pkg::CSR_MCOUNTEREN: rdata_o = {32'b0, mcounteren_rdata_q};
            csr_pkg::CSR_MSCRATCH: rdata_o = mscratch_rdata_q;
            csr_pkg::CSR_MEPC    : rdata_o = mepc_rdata_q;
            csr_pkg::CSR_MCAUSE  : rdata_o = {mcause_rdata_q[CAUSE_W - 1], 58'b0, mcause_rdata_q[CAUSE_W - 2:0]};
            csr_pkg::CSR_MTVAL   : rdata_o = mtval_rdata_q;
            csr_pkg::CSR_MIP     : rdata_o = mip_data;
            csr_pkg::CSR_MENVCFG : rdata_o = {menvcfg_stce_rdata_q, {(XLEN - 1){1'b0}}};
            csr_pkg::CSR_MCYCLE  : rdata_o = mcycle_rdata_q;
            csr_pkg::CSR_MINSTRET: rdata_o = minstret_rdata_q;
            csr_pkg::CSR_MVENDORID,
            csr_pkg::CSR_MARCHID,
            csr_pkg::CSR_MIMPID,
            csr_pkg::CSR_MHARTID : rdata_o = '0;

            // Supervisor level CSRs.
            csr_pkg::CSR_SSTATUS : rdata_o = {mstatus_rdata_q[63], 29'd0, mstatus_rdata_q[33:32], 7'b0,
                                                     mstatus_rdata_q[24:23], 3'b0,
                                                     mstatus_rdata_q[19:13], 2'b0,
                                                     mstatus_rdata_q[10:8 ], 1'b0,
                                                     mstatus_rdata_q[ 6:5 ], 3'b0,
                                                     mstatus_rdata_q[ 1   ], 1'b0};
            csr_pkg::CSR_SIE     : rdata_o = {50'd0, mie_rdata_q[13], 3'b0,
                                                     mie_rdata_q[ 9], 3'b0,
                                                     mie_rdata_q[ 5], 3'b0,
                                                     mie_rdata_q[ 1], 1'b0};
            csr_pkg::CSR_STVEC   : rdata_o = stvec_rdata_q;
            csr_pkg::CSR_SCOUNTEREN: rdata_o = {32'b0, scounteren_rdata_q};
            csr_pkg::CSR_SSCRATCH: rdata_o = sscratch_rdata_q;
            csr_pkg::CSR_SEPC    : rdata_o = sepc_rdata_q;
            csr_pkg::CSR_SCAUSE  : rdata_o = {scause_rdata_q[CAUSE_W - 1], 58'b0, scause_rdata_q[CAUSE_W - 2:0]};
            csr_pkg::CSR_STVAL   : rdata_o = stval_rdata_q;
            csr_pkg::CSR_SIP     : rdata_o = {50'd0, mip_data[13], 3'b0,
                                                     mip_data[ 9], 3'b0,
                                                     mip_data[ 5], 3'b0,
                                                     mip_data[ 1], 1'b0};
            csr_pkg::CSR_STIMECMP: rdata_o = stimecmp_rdata_q;
            csr_pkg::CSR_SATP    : rdata_o = satp_rdata_q;

            // Unprivileged CSRs.
            csr_pkg::CSR_CYCLE   : rdata_o = mcycle_rdata_q;
            csr_pkg::CSR_TIME    : rdata_o = mtime_val_i;
            csr_pkg::CSR_INSTRET : rdata_o = minstret_rdata_q;

            default: begin
                rdata_o = '0;
            end
        endcase
    end





    //----------------------------
    // Lower-level modulues:
    // CS registers.
    //----------------------------

    // Privilege level register.
    register_en # (
        .DATA_WIDTH (2     ),
        .RESET_VAL  (csr_pkg::PRIV_M) // M-mode.
    ) PRIV_mode_REG0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (priv_mode_we),
        .wdata_i (priv_mode_d ),
        .rdata_o (priv_mode_q )
    );
    assign priv_mode_o = priv_mode_q;

    //----------------------------
    // Machine level CSRs.
    //----------------------------

    // mstatus.
    register_en # (
        .DATA_WIDTH (XLEN         ),
        .RESET_VAL  (64'ha00000000)
    ) MSTATUS_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (mstatus_we     ),
        .wdata_i (mstatus_wdata_d),
        .rdata_o (mstatus_rdata_q)
    );
    assign mstatus_rdata_log_o = mstatus_we ? mstatus_wdata_d : mstatus_rdata_q;
    assign mstatus_rdata_o     = mstatus_rdata_q;

    // medeleg.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MEDELEG_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (medeleg_we     ),
        .wdata_i (medeleg_wdata_d),
        .rdata_o (medeleg_rdata_q)
    );

    // mideleg.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MIDELEG_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (mideleg_we     ),
        .wdata_i (mideleg_wdata_d),
        .rdata_o (mideleg_rdata_q)
    );

    // mie.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MIE_CSR0 (
        .clk_i   (clk_i      ),
        .arst_i  (arst_i     ),
        .we_i    (mie_we     ),
        .wdata_i (mie_wdata_d),
        .rdata_o (mie_rdata_q)
    );

    // mtvec.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MTVEC_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (mtvec_we     ),
        .wdata_i (mtvec_wdata_d),
        .rdata_o (mtvec_rdata_q)
    );

    // mcounteren.
    register_en # (
        .DATA_WIDTH (32       ),
        .RESET_VAL  (RESET_VAL)
    ) MCOUNTEREN_CSR0 (
        .clk_i   (clk_i             ),
        .arst_i  (arst_i            ),
        .we_i    (mcounteren_we     ),
        .wdata_i (mcounteren_wdata_d),
        .rdata_o (mcounteren_rdata_q)
    );

    // mscratch.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MSCRATCH_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (mscratch_we     ),
        .wdata_i (mscratch_wdata_d),
        .rdata_o (mscratch_rdata_q)
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MEPC_CSR0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (mepc_we     ),
        .wdata_i (mepc_wdata_d),
        .rdata_o (mepc_rdata_q)
    );

    // mcause.
    register_en # (
        .DATA_WIDTH (CAUSE_W  ),
        .RESET_VAL  (RESET_VAL)
    ) MCAUSE_CSR0 (
        .clk_i   (clk_i         ),
        .arst_i  (arst_i        ),
        .we_i    (mcause_we     ),
        .wdata_i (mcause_wdata_d),
        .rdata_o (mcause_rdata_q)
    );

    // mtval.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MTVAL_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (mtval_we     ),
        .wdata_i (mtval_wdata_d),
        .rdata_o (mtval_rdata_q)
    );

    // mip/sip SSIP bit.
    register_en # (
        .DATA_WIDTH (1        ),
        .RESET_VAL  (RESET_VAL)
    ) MIP_SSIP_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (mip_ssip_we     ),
        .wdata_i (mip_ssip_wdata_d),
        .rdata_o (mip_ssip_rdata_q)
    );

    // menvcfg STCE bit.
    register_en # (
        .DATA_WIDTH (1        ),
        .RESET_VAL  (RESET_VAL)
    ) MENVCFG_STCE_CSR0 (
        .clk_i   (clk_i               ),
        .arst_i  (arst_i              ),
        .we_i    (menvcfg_stce_we     ),
        .wdata_i (menvcfg_stce_wdata_d),
        .rdata_o (menvcfg_stce_rdata_q)
    );

    // mcycle.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MCYCLE_CSR0 (
        .clk_i   (clk_i         ),
        .arst_i  (arst_i        ),
        .we_i    (mcycle_we     ),
        .wdata_i (mcycle_wdata_d),
        .rdata_o (mcycle_rdata_q)
    );

    // minstret.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) MINSTRET_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (minstret_we     ),
        .wdata_i (minstret_wdata_d),
        .rdata_o (minstret_rdata_q)
    );



    //----------------------------
    // Supervisor level CSRs.
    //----------------------------

    // stvec.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) STVEC_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (stvec_we     ),
        .wdata_i (stvec_wdata_d),
        .rdata_o (stvec_rdata_q)
    );

    // scounteren.
    register_en # (
        .DATA_WIDTH (32       ),
        .RESET_VAL  (RESET_VAL)
    ) SCOUNTEREN_CSR0 (
        .clk_i   (clk_i             ),
        .arst_i  (arst_i            ),
        .we_i    (scounteren_we     ),
        .wdata_i (scounteren_wdata_d),
        .rdata_o (scounteren_rdata_q)
    );

    // sscratch.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) SSCRATCH_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (sscratch_we     ),
        .wdata_i (sscratch_wdata_d),
        .rdata_o (sscratch_rdata_q)
    );

    // sepc.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) SEPC_CSR0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (sepc_we     ),
        .wdata_i (sepc_wdata_d),
        .rdata_o (sepc_rdata_q)
    );

    // scause.
    register_en # (
        .DATA_WIDTH (CAUSE_W  ),
        .RESET_VAL  (RESET_VAL)
    ) SCAUSE_CSR0 (
        .clk_i   (clk_i         ),
        .arst_i  (arst_i        ),
        .we_i    (scause_we     ),
        .wdata_i (scause_wdata_d),
        .rdata_o (scause_rdata_q)
    );

    // stval.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) STVAL_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (stval_we     ),
        .wdata_i (stval_wdata_d),
        .rdata_o (stval_rdata_q)
    );

    // stimecmp.
    register_en # (
        .DATA_WIDTH (XLEN                ),
        .RESET_VAL  (64'hFFFFFFFFFFFFFFFF)
    ) STIMECMP_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (stimecmp_we     ),
        .wdata_i (stimecmp_wdata_d),
        .rdata_o (stimecmp_rdata_q)
    );

    // satp.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) SATP_CSR0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (satp_we     ),
        .wdata_i (satp_wdata_d),
        .rdata_o (satp_rdata_q)
    );
    assign satp_rdata_o = satp_we ? satp_wdata_d : satp_rdata_q;




    //----------------------------
    // Output logic.
    //----------------------------

    //----------------------------
    // Detect interrupts.
    //----------------------------
    assign m_mode_timer_irq    = (mip_data[7] & mie_rdata_q[7]);
    assign m_mode_software_irq = (mip_data[3] & mie_rdata_q[3]);
    assign m_mode_irq          = m_mode_timer_irq | m_mode_software_irq;
    assign m_mode_irq_cause    = m_mode_software_irq ? csr_pkg::IRQ_M_SW : csr_pkg::IRQ_M_TIMER; // Software interrupt has higher priority than timer interrupt.

    assign s_mode_timer_irq    = (mip_data[5] & mie_rdata_q[5]);
    assign s_mode_software_irq = (mip_data[1] & mie_rdata_q[1]);
    assign s_mode_irq          = s_mode_timer_irq | s_mode_software_irq;
    assign s_mode_irq_cause    = s_mode_software_irq ? csr_pkg::IRQ_S_SW : csr_pkg::IRQ_S_TIMER; // Software interrupt has higher priority than timer interrupt.

    always_comb begin
        iqr_detected_o = 1'b0;
        trap_cause_o   = '0;

        case (priv_mode_q)
            csr_pkg::PRIV_M: begin
                iqr_detected_o = mstatus_rdata_q[3] & (m_mode_irq | (s_mode_irq & (~mideleg_rdata_q[{1'b0, s_mode_irq_cause[CAUSE_W - 2:0]}])));
                trap_cause_o   = m_mode_irq_cause;
            end
            csr_pkg::PRIV_S: begin
                iqr_detected_o = m_mode_irq | (mstatus_rdata_q[1] & s_mode_irq);
                trap_cause_o   = m_mode_irq ? m_mode_irq_cause : s_mode_irq_cause;
            end
            csr_pkg::PRIV_U: begin
                iqr_detected_o = m_mode_irq | s_mode_irq;
                trap_cause_o   = m_mode_irq ? m_mode_irq_cause : s_mode_irq_cause;
            end
            default: begin
                iqr_detected_o = 1'b0;
                trap_cause_o   = '0;
            end
        endcase
    end

endmodule
