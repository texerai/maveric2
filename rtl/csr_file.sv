/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 18/07/2026
//------------------------------

// --------------------------------------------------------------------------------------
// This is a csr register file with all the CSRs implemented in
// the design. Currently implemented list of CSRs:
//-----------------------------------------------------------------------------
//---------------------------MACHINE CSRS--------------------------------------
//---------------------------TOTAL: 38(52)-------------------------------------
// - Machine Information Registers: mvendorid, marchid, mimpid, mhartid. All set to 0.
// - Machine Trap Setup: mstatus, misa, medeleg, mideleg, mie, mtvec, mcounteren.
// - Machine Trap Handling: mscratch, mepc, mcause, mtval, mip.
// - Machine Configuration: menvcfg (only STCE writable).
// - Machine Memory Protection: pmpcfg0 - pmpcfg15, pmpaddr0 -pmpaddr15.
// - Machine Counter/Timers: mcycle, minstret.
// - Machine Counter Setup: mcountinhibit.
//-----------------------------------------------------------------------------
//---------------------------SUPERVISOR CSRS-----------------------------------
//---------------------------TOTAL: 12-----------------------------------------
// - Supervisor Trap Setup: sstatus, sie, stvec, scounteren.
// - Supervisor Trap Handling: sscratch, sepc, scause, stval, sip.
// - Supervisor Protection and Translation: satp.
// - Supervisor Timers Compare: stimecmp.
//-----------------------------------------------------------------------------
//---------------------------Unprivileged CSRS---------------------------------
//---------------------------TOTAL: 3------------------------------------------
// - Unprivileged Counter/Timers: cycle, time, instret.
// --------------------------------------------------------------------------------------

`include "maveric_pkg.sv"

module csr_file
// Parameters.
#(
    parameter XLEN       = maveric_pkg::XLEN,
    parameter CSR_ADDR_W = maveric_pkg::CSR_ADDR_W,
    parameter CAUSE_W    = maveric_pkg::CAUSE_W,
    parameter PMP_ADDR_W = maveric_pkg::PMP_ADDR_W,
    parameter PA_W       = maveric_pkg::PA_W,
    parameter PMP_N      = maveric_pkg::PMP_N,
    parameter RESET_VAL  = '0
)
// Port decleration.
(
    // Common clock & reset signals.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic                    we_i,
    input  logic                    csr_write_instr_i,
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
    output csr_pkg::pmp_t           pmp_data_o,
    output logic [XLEN       - 1:0] mstatus_rdata_o,
    output logic [XLEN       - 1:0] csr_wdata_log_o,
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
    logic mcountinhibit_we;
    logic mscratch_we;
    logic mepc_we;
    logic mcause_we;
    logic mtval_we;
    logic mip_ssip_we;
    logic menvcfg_we;
    logic mcycle_we;
    logic minstret_we;
    logic pmpcfg0_we;
    logic pmpcfg1_we;
    logic [PMP_N - 1:0] pmpaddr_we;
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
    logic [         31:0] mcountinhibit_wdata_d;
    logic [XLEN    - 1:0] mscratch_wdata_d;
    logic [XLEN    - 1:0] mepc_wdata_d;
    logic [CAUSE_W - 1:0] mcause_wdata_d;
    logic [XLEN    - 1:0] mtval_wdata_d;
    logic                 mip_ssip_wdata_d;
    logic [XLEN    - 1:0] mip_data;
    logic                 menvcfg_wdata_d;
    logic [XLEN    - 1:0] mcycle_wdata_d;
    logic [XLEN    - 1:0] minstret_wdata_d;
    logic [XLEN    - 1:0] pmpcfg0_wdata_d;
    logic [XLEN    - 1:0] pmpcfg1_wdata_d;
    logic [PMP_ADDR_W - 1:0] pmpaddr_wdata_d [PMP_N - 1:0];
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
    logic [         31:0] mcountinhibit_rdata_q;
    logic [XLEN    - 1:0] mscratch_rdata_q;
    logic [XLEN    - 1:0] mepc_rdata_q;
    logic [CAUSE_W - 1:0] mcause_rdata_q;
    logic [XLEN    - 1:0] mtval_rdata_q;
    logic                 mip_ssip_rdata_q;
    logic                 menvcfg_rdata_q;
    logic [XLEN    - 1:0] mcycle_rdata_q;
    logic [XLEN    - 1:0] minstret_rdata_q;
    logic [XLEN    - 1:0] pmpcfg0_rdata_q;
    logic [XLEN    - 1:0] pmpcfg1_rdata_q;
    logic [PMP_ADDR_W - 1:0] pmpaddr_rdata_q [PMP_N - 1:0];
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

    logic msi;
    logic mti;
    logic ssi;
    logic sti;
    logic ssi_to_m;
    logic sti_to_m;
    logic ssi_to_s;
    logic sti_to_s;

    // Logic for pmp address ranges.
    logic [PA_W - 1:0] pmpaddr_lo [PMP_N - 1:0];
    logic [PA_W - 1:0] pmpaddr_hi [PMP_N - 1:0];


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
                    csr_pkg::CSR_MCOUNTINHIBIT,
                    csr_pkg::CSR_MSCRATCH,
                    csr_pkg::CSR_MEPC,
                    csr_pkg::CSR_MCAUSE,
                    csr_pkg::CSR_MTVAL,
                    csr_pkg::CSR_MIP,
                    csr_pkg::CSR_MENVCFG,
                    csr_pkg::CSR_MCYCLE,
                    csr_pkg::CSR_MINSTRET,
                    csr_pkg::CSR_PMPCFG0,
                    csr_pkg::CSR_PMPCFG1,
                    csr_pkg::CSR_PMPADDR0,
                    csr_pkg::CSR_PMPADDR1,
                    csr_pkg::CSR_PMPADDR2,
                    csr_pkg::CSR_PMPADDR3,
                    csr_pkg::CSR_PMPADDR4,
                    csr_pkg::CSR_PMPADDR5,
                    csr_pkg::CSR_PMPADDR6,
                    csr_pkg::CSR_PMPADDR7,
                    csr_pkg::CSR_PMPADDR8,
                    csr_pkg::CSR_PMPADDR9,
                    csr_pkg::CSR_PMPADDR10,
                    csr_pkg::CSR_PMPADDR11,
                    csr_pkg::CSR_PMPADDR12,
                    csr_pkg::CSR_PMPADDR13,
                    csr_pkg::CSR_PMPADDR14,
                    csr_pkg::CSR_PMPADDR15,
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
                    csr_pkg::CSR_SATP   : illegal_instr_o = 1'b0;
                    csr_pkg::CSR_CYCLE,
                    csr_pkg::CSR_TIME,
                    csr_pkg::CSR_INSTRET: illegal_instr_o = csr_write_instr_i;
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
                    csr_pkg::CSR_STIMECMP: illegal_instr_o = !(menvcfg_rdata_q && mcounteren_rdata_q[1]);
                    csr_pkg::CSR_CYCLE   : illegal_instr_o = !mcounteren_rdata_q[0] || csr_write_instr_i;
                    csr_pkg::CSR_TIME    : illegal_instr_o = !mcounteren_rdata_q[1] || csr_write_instr_i;
                    csr_pkg::CSR_INSTRET : illegal_instr_o = !mcounteren_rdata_q[2] || csr_write_instr_i;
                    default              : illegal_instr_o = 1'b1;
                endcase
            end else if (priv_mode_o == csr_pkg::PRIV_U) begin
                case (raddr_i)
                    csr_pkg::CSR_CYCLE  : illegal_instr_o = !(mcounteren_rdata_q[0] & scounteren_rdata_q[0]) || csr_write_instr_i;
                    csr_pkg::CSR_TIME   : illegal_instr_o = !(mcounteren_rdata_q[1] & scounteren_rdata_q[1]) || csr_write_instr_i;
                    csr_pkg::CSR_INSTRET: illegal_instr_o = !(mcounteren_rdata_q[2] & scounteren_rdata_q[2]) || csr_write_instr_i;
                    default             : illegal_instr_o = 1'b1;
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
    assign delegate = (priv_mode_q < csr_pkg::PRIV_M) &&
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

        mstatus_we       = 1'b0;
        medeleg_we       = 1'b0;
        mideleg_we       = 1'b0;
        mie_we           = 1'b0;
        mtvec_we         = 1'b0;
        mcounteren_we    = 1'b0;
        mcountinhibit_we = 1'b0;
        mscratch_we      = 1'b0;
        mepc_we          = 1'b0;
        mcause_we        = 1'b0;
        mtval_we         = 1'b0;
        mip_ssip_we      = 1'b0;
        menvcfg_we       = 1'b0;
        mcycle_we        = 1'b0;
        minstret_we      = 1'b0;
        pmpcfg0_we       = 1'b0;
        pmpcfg1_we       = 1'b0;
        pmpaddr_we       = '0;
        stvec_we         = 1'b0;
        scounteren_we    = 1'b0;
        sscratch_we      = 1'b0;
        sepc_we          = 1'b0;
        scause_we        = 1'b0;
        stval_we         = 1'b0;
        stimecmp_we      = 1'b0;
        satp_we          = 1'b0;

        mstatus_wdata_d       = '0;
        medeleg_wdata_d       = '0;
        mideleg_wdata_d       = '0;
        mie_wdata_d           = '0;
        mtvec_wdata_d         = '0;
        mcounteren_wdata_d    = '0;
        mcountinhibit_wdata_d = '0;
        mscratch_wdata_d      = '0;
        mepc_wdata_d          = '0;
        mcause_wdata_d        = '0;
        mtval_wdata_d         = '0;
        mip_ssip_wdata_d      = '0;
        mip_data              = '0;
        menvcfg_wdata_d       = '0;
        mcycle_wdata_d        = '0;
        minstret_wdata_d      = '0;
        pmpcfg0_wdata_d       = '0;
        pmpcfg1_wdata_d       = '0;
        pmpaddr_wdata_d[0 ]   = '0;
        pmpaddr_wdata_d[1 ]   = '0;
        pmpaddr_wdata_d[2 ]   = '0;
        pmpaddr_wdata_d[3 ]   = '0;
        pmpaddr_wdata_d[4 ]   = '0;
        pmpaddr_wdata_d[5 ]   = '0;
        pmpaddr_wdata_d[6 ]   = '0;
        pmpaddr_wdata_d[7 ]   = '0;
        pmpaddr_wdata_d[8 ]   = '0;
        pmpaddr_wdata_d[9 ]   = '0;
        pmpaddr_wdata_d[10]   = '0;
        pmpaddr_wdata_d[11]   = '0;
        pmpaddr_wdata_d[12]   = '0;
        pmpaddr_wdata_d[13]   = '0;
        pmpaddr_wdata_d[14]   = '0;
        pmpaddr_wdata_d[15]   = '0;
        stvec_wdata_d         = '0;
        scounteren_wdata_d    = '0;
        sscratch_wdata_d      = '0;
        sepc_wdata_d          = '0;
        scause_wdata_d        = '0;
        stval_wdata_d         = '0;
        stimecmp_wdata_d      = '0;
        satp_wdata_d          = '0;

        csr_wdata_log_o = '0;

        // Increment CSRs.
        mcycle_we        = !mcountinhibit_rdata_q[0];
        mcycle_wdata_d   = mcycle_rdata_q + {{(XLEN - 1){1'b0}}, 1'b1};
        minstret_we      = instr_ret_i && !mcountinhibit_rdata_q[2];
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
                    csr_wdata_log_o = mstatus_wdata_d;
                end
                csr_pkg::CSR_MEDELEG: begin
                    medeleg_we      = 1'b1;
                    medeleg_wdata_d = {44'b0, wdata_i[19:18], 2'b0,
                                              wdata_i[15   ], 1'b0,
                                              wdata_i[13:12], 2'b0,
                                              wdata_i[ 9:0 ]};
                    csr_wdata_log_o = medeleg_wdata_d;
                end
                csr_pkg::CSR_MIDELEG: begin
                    mideleg_we      = 1'b1;
                    mideleg_wdata_d = {54'b0, wdata_i[9], 3'b0,
                                              wdata_i[5], 3'b0,
                                              wdata_i[1], 1'b0};
                    csr_wdata_log_o = mideleg_wdata_d;
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
                    csr_wdata_log_o = mie_wdata_d;
                end
                csr_pkg::CSR_MTVEC: begin
                    mtvec_we      = 1'b1;
                    mtvec_wdata_d = {wdata_i[XLEN - 1:2], 1'b0, wdata_i[0]};
                    csr_wdata_log_o = mtvec_wdata_d;
                end
                csr_pkg::CSR_MCOUNTEREN: begin
                    mcounteren_we      = 1'b1;
                    mcounteren_wdata_d = {29'b0, wdata_i[2:0]};
                    csr_wdata_log_o    = {32'b0, mcounteren_wdata_d};
                end
                csr_pkg::CSR_MCOUNTINHIBIT: begin
                    mcountinhibit_we      = 1'b1;
                    mcountinhibit_wdata_d = {29'b0, wdata_i[1], 1'b0, wdata_i[0]};
                    csr_wdata_log_o       = {32'b0, mcountinhibit_wdata_d};
                end
                csr_pkg::CSR_MSCRATCH: begin
                    mscratch_we      = 1'b1;
                    mscratch_wdata_d = wdata_i;
                    csr_wdata_log_o  = mscratch_wdata_d;
                end
                csr_pkg::CSR_MEPC: begin
                    mepc_we      = 1'b1;
                    mepc_wdata_d = {wdata_i[XLEN - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
                    csr_wdata_log_o = mepc_wdata_d;
                end
                csr_pkg::CSR_MCAUSE: begin
                    mcause_we      = mcause_legal;
                    mcause_wdata_d = {wdata_i[XLEN - 1], wdata_i[CAUSE_W - 2:0]};
                    csr_wdata_log_o = wdata_i;
                end
                csr_pkg::CSR_MTVAL: begin
                    mtval_we      = 1'b1;
                    mtval_wdata_d = wdata_i;
                    csr_wdata_log_o = mtval_wdata_d;
                end
                csr_pkg::CSR_MIP: begin
                    mip_ssip_we      = 1'b1;
                    mip_ssip_wdata_d = wdata_i[1];
                    csr_wdata_log_o  = {mip_data[XLEN - 1:2], wdata_i[1], 1'b0};
                end
                csr_pkg::CSR_MENVCFG: begin
                    menvcfg_we      = 1'b1;
                    menvcfg_wdata_d = {wdata_i[XLEN - 1]};
                    csr_wdata_log_o = {wdata_i[XLEN - 1], 63'b0};
                end
                csr_pkg::CSR_MCYCLE: begin
                    mcycle_we      = 1'b1;
                    mcycle_wdata_d = wdata_i;
                    csr_wdata_log_o = mcycle_wdata_d;
                end
                csr_pkg::CSR_MINSTRET: begin
                    minstret_we      = 1'b1;
                    minstret_wdata_d = wdata_i;
                    csr_wdata_log_o  = minstret_wdata_d;
                end
                csr_pkg::CSR_PMPCFG0: begin
                    pmpcfg0_we      = 1'b1;
                    pmpcfg0_wdata_d = {pmpcfg0_rdata_q[(7 * 8) + 7] ? pmpcfg0_rdata_q[(7 * 8) + 7:(7 * 8)] : wdata_i[(7 * 8) + 7:(7 * 8)],
                                       pmpcfg0_rdata_q[(6 * 8) + 7] ? pmpcfg0_rdata_q[(6 * 8) + 7:(6 * 8)] : wdata_i[(6 * 8) + 7:(6 * 8)],
                                       pmpcfg0_rdata_q[(5 * 8) + 7] ? pmpcfg0_rdata_q[(5 * 8) + 7:(5 * 8)] : wdata_i[(5 * 8) + 7:(5 * 8)],
                                       pmpcfg0_rdata_q[(4 * 8) + 7] ? pmpcfg0_rdata_q[(4 * 8) + 7:(4 * 8)] : wdata_i[(4 * 8) + 7:(4 * 8)],
                                       pmpcfg0_rdata_q[(3 * 8) + 7] ? pmpcfg0_rdata_q[(3 * 8) + 7:(3 * 8)] : wdata_i[(3 * 8) + 7:(3 * 8)],
                                       pmpcfg0_rdata_q[(2 * 8) + 7] ? pmpcfg0_rdata_q[(2 * 8) + 7:(2 * 8)] : wdata_i[(2 * 8) + 7:(2 * 8)],
                                       pmpcfg0_rdata_q[(1 * 8) + 7] ? pmpcfg0_rdata_q[(1 * 8) + 7:(1 * 8)] : wdata_i[(1 * 8) + 7:(1 * 8)],
                                       pmpcfg0_rdata_q[(0 * 8) + 7] ? pmpcfg0_rdata_q[(0 * 8) + 7:(0 * 8)] : wdata_i[(0 * 8) + 7:(0 * 8)]};
                    csr_wdata_log_o = pmpcfg0_wdata_d;
                end
                csr_pkg::CSR_PMPCFG1: begin
                    pmpcfg1_we      = 1'b1;
                    pmpcfg0_wdata_d = {pmpcfg1_rdata_q[(7 * 8) + 7] ? pmpcfg1_rdata_q[(7 * 8) + 7:(7 * 8)] : wdata_i[(7 * 8) + 7:(7 * 8)],
                                       pmpcfg1_rdata_q[(6 * 8) + 7] ? pmpcfg1_rdata_q[(6 * 8) + 7:(6 * 8)] : wdata_i[(6 * 8) + 7:(6 * 8)],
                                       pmpcfg1_rdata_q[(5 * 8) + 7] ? pmpcfg1_rdata_q[(5 * 8) + 7:(5 * 8)] : wdata_i[(5 * 8) + 7:(5 * 8)],
                                       pmpcfg1_rdata_q[(4 * 8) + 7] ? pmpcfg1_rdata_q[(4 * 8) + 7:(4 * 8)] : wdata_i[(4 * 8) + 7:(4 * 8)],
                                       pmpcfg1_rdata_q[(3 * 8) + 7] ? pmpcfg1_rdata_q[(3 * 8) + 7:(3 * 8)] : wdata_i[(3 * 8) + 7:(3 * 8)],
                                       pmpcfg1_rdata_q[(2 * 8) + 7] ? pmpcfg1_rdata_q[(2 * 8) + 7:(2 * 8)] : wdata_i[(2 * 8) + 7:(2 * 8)],
                                       pmpcfg1_rdata_q[(1 * 8) + 7] ? pmpcfg1_rdata_q[(1 * 8) + 7:(1 * 8)] : wdata_i[(1 * 8) + 7:(1 * 8)],
                                       pmpcfg1_rdata_q[(0 * 8) + 7] ? pmpcfg1_rdata_q[(0 * 8) + 7:(0 * 8)] : wdata_i[(0 * 8) + 7:(0 * 8)]};
                    csr_wdata_log_o = pmpcfg1_wdata_d;
                end
                csr_pkg::CSR_PMPADDR0: begin
                    pmpaddr_we[0]      = (pmpcfg0_rdata_q[(0 * 8) + 7] || (pmpcfg0_rdata_q[(1 * 8) + 7] && (pmpcfg0_rdata_q[(1 * 8) + 4:(1 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[0] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[0]};
                end
                csr_pkg::CSR_PMPADDR1: begin
                    pmpaddr_we[1]      = (pmpcfg0_rdata_q[(1 * 8) + 7] || (pmpcfg0_rdata_q[(2 * 8) + 7] && (pmpcfg0_rdata_q[(2 * 8) + 4:(2 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[1] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[1]};
                end
                csr_pkg::CSR_PMPADDR2: begin
                    pmpaddr_we[2]      = (pmpcfg0_rdata_q[(2 * 8) + 7] || (pmpcfg0_rdata_q[(3 * 8) + 7] && (pmpcfg0_rdata_q[(3 * 8) + 4:(3 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[2] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[2]};
                end
                csr_pkg::CSR_PMPADDR3: begin
                    pmpaddr_we[3]      = (pmpcfg0_rdata_q[(3 * 8) + 7] || (pmpcfg0_rdata_q[(4 * 8) + 7] && (pmpcfg0_rdata_q[(4 * 8) + 4:(4 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[3] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[3]};
                end
                csr_pkg::CSR_PMPADDR4: begin
                    pmpaddr_we[4]      = (pmpcfg0_rdata_q[(4 * 8) + 7] || (pmpcfg0_rdata_q[(5 * 8) + 7] && (pmpcfg0_rdata_q[(5 * 8) + 4:(5 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[4] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[4]};
                end
                csr_pkg::CSR_PMPADDR5: begin
                    pmpaddr_we[5]      = (pmpcfg0_rdata_q[(5 * 8) + 7] || (pmpcfg0_rdata_q[(6 * 8) + 7] && (pmpcfg0_rdata_q[(6 * 8) + 4:(6 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[5] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[5]};
                end
                csr_pkg::CSR_PMPADDR6: begin
                    pmpaddr_we[6]      = (pmpcfg0_rdata_q[(6 * 8) + 7] || (pmpcfg0_rdata_q[(7 * 8) + 7] && (pmpcfg0_rdata_q[(7 * 8) + 4:(7 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[6] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[6]};
                end
                csr_pkg::CSR_PMPADDR7: begin
                    pmpaddr_we[7]      = (pmpcfg0_rdata_q[(7 * 8) + 7] || (pmpcfg1_rdata_q[(0 * 8) + 7] && (pmpcfg1_rdata_q[(0 * 8) + 4:(0 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[7] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[7]};
                end
                csr_pkg::CSR_PMPADDR8: begin
                    pmpaddr_we[8]      = (pmpcfg1_rdata_q[(0 * 8) + 7] || (pmpcfg1_rdata_q[(1 * 8) + 7] && (pmpcfg1_rdata_q[(1 * 8) + 4:(1 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[8] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[8]};
                end
                csr_pkg::CSR_PMPADDR9: begin
                    pmpaddr_we[9]      = (pmpcfg1_rdata_q[(1 * 8) + 7] || (pmpcfg1_rdata_q[(2 * 8) + 7] && (pmpcfg1_rdata_q[(2 * 8) + 4:(2 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[9] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[9]};
                end
                csr_pkg::CSR_PMPADDR10: begin
                    pmpaddr_we[10]      = (pmpcfg1_rdata_q[(2 * 8) + 7] || (pmpcfg1_rdata_q[(3 * 8) + 7] && (pmpcfg1_rdata_q[(3 * 8) + 4:(3 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[10] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[10]};
                end
                csr_pkg::CSR_PMPADDR11: begin
                    pmpaddr_we[11]      = (pmpcfg1_rdata_q[(3 * 8) + 7] || (pmpcfg1_rdata_q[(4 * 8) + 7] && (pmpcfg1_rdata_q[(4 * 8) + 4:(4 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[11] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[11]};
                end
                csr_pkg::CSR_PMPADDR12: begin
                    pmpaddr_we[12]      = (pmpcfg1_rdata_q[(4 * 8) + 7] || (pmpcfg1_rdata_q[(5 * 8) + 7] && (pmpcfg1_rdata_q[(5 * 8) + 4:(5 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[12] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[12]};
                end
                csr_pkg::CSR_PMPADDR13: begin
                    pmpaddr_we[13]      = (pmpcfg1_rdata_q[(5 * 8) + 7] || (pmpcfg1_rdata_q[(6 * 8) + 7] && (pmpcfg1_rdata_q[(6 * 8) + 4:(6 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[13] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[13]};
                end
                csr_pkg::CSR_PMPADDR14: begin
                    pmpaddr_we[14]      = (pmpcfg1_rdata_q[(6 * 8) + 7] || (pmpcfg1_rdata_q[(7 * 8) + 7] && (pmpcfg1_rdata_q[(7 * 8) + 4:(7 * 8) + 3] == 2'b1))) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[14] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[14]};
                end
                csr_pkg::CSR_PMPADDR15: begin
                    pmpaddr_we[15]      = (pmpcfg1_rdata_q[(7 * 8) + 7]) ? 1'b0 : 1'b1;
                    pmpaddr_wdata_d[15] = wdata_i[PMP_ADDR_W - 1:0];
                    csr_wdata_log_o    = {10'b0, pmpaddr_wdata_d[15]};
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
                    csr_wdata_log_o = mstatus_wdata_d;
                end
                csr_pkg::CSR_SIE: begin
                    mie_we      = 1'b1;
                    mie_wdata_d = {mie_rdata_q[63:14], wdata_i[13], mie_rdata_q[12:10],
                                                       wdata_i[ 9], mie_rdata_q[ 8:6 ],
                                                       wdata_i[ 5], mie_rdata_q[ 4:2 ],
                                                       wdata_i[ 1], mie_rdata_q[ 0   ]};
                    csr_wdata_log_o = mie_wdata_d;
                end
                csr_pkg::CSR_STVEC: begin
                    stvec_we      = 1'b1;
                    stvec_wdata_d = {wdata_i[XLEN - 1:2], 1'b0, wdata_i[0]};
                    csr_wdata_log_o = stvec_wdata_d;
                end
                csr_pkg::CSR_SCOUNTEREN: begin
                    scounteren_we      = 1'b1;
                    scounteren_wdata_d = {29'b0, wdata_i[2:0]};
                    csr_wdata_log_o    = {32'b0, scounteren_wdata_d};
                end
                csr_pkg::CSR_SSCRATCH: begin
                    sscratch_we      = 1'b1;
                    sscratch_wdata_d = wdata_i;
                    csr_wdata_log_o  = sscratch_wdata_d;
                end
                csr_pkg::CSR_SEPC: begin
                    sepc_we      = 1'b1;
                    sepc_wdata_d = {wdata_i[XLEN - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
                    csr_wdata_log_o = sepc_wdata_d;
                end
                csr_pkg::CSR_SCAUSE: begin
                    scause_we      = scause_legal;
                    scause_wdata_d = {wdata_i[XLEN - 1], wdata_i[CAUSE_W - 2:0]};
                    csr_wdata_log_o = wdata_i;
                end
                csr_pkg::CSR_STVAL: begin
                    stval_we      = 1'b1;
                    stval_wdata_d = wdata_i;
                    csr_wdata_log_o = wdata_i;
                end
                csr_pkg::CSR_SIP: begin
                    mip_ssip_we      = 1'b1;
                    mip_ssip_wdata_d = wdata_i[1];
                    csr_wdata_log_o  = {mip_data[XLEN - 1:2], wdata_i[1], 1'b0};
                end
                csr_pkg::CSR_STIMECMP: begin
                    stimecmp_we      = 1'b1;
                    stimecmp_wdata_d = wdata_i;
                    csr_wdata_log_o  = stimecmp_wdata_d;
                end
                csr_pkg::CSR_SATP: begin
                    satp_we      = satp_legal;
                    satp_wdata_d = wdata_i;
                    csr_wdata_log_o = satp_wdata_d;
                end
                default: begin
                    mstatus_we       = 1'b0;
                    medeleg_we       = 1'b0;
                    mideleg_we       = 1'b0;
                    mie_we           = 1'b0;
                    mtvec_we         = 1'b0;
                    mcounteren_we    = 1'b0;
                    mcountinhibit_we = 1'b0;
                    mscratch_we      = 1'b0;
                    mepc_we          = 1'b0;
                    mcause_we        = 1'b0;
                    mtval_we         = 1'b0;
                    mip_ssip_we      = 1'b0;
                    menvcfg_we       = 1'b0;
                    mcycle_we        = 1'b0;
                    minstret_we      = 1'b0;
                    pmpcfg0_we       = 1'b0;
                    pmpcfg1_we       = 1'b0;
                    pmpaddr_we       = '0;
                    stvec_we         = 1'b0;
                    scounteren_we    = 1'b0;
                    sscratch_we      = 1'b0;
                    sepc_we          = 1'b0;
                    scause_we        = 1'b0;
                    stval_we         = 1'b0;
                    stimecmp_we      = 1'b0;
                    satp_we          = 1'b0;

                    mstatus_wdata_d       = '0;
                    medeleg_wdata_d       = '0;
                    mideleg_wdata_d       = '0;
                    mie_wdata_d           = '0;
                    mtvec_wdata_d         = '0;
                    mcounteren_wdata_d    = '0;
                    mcountinhibit_wdata_d = '0;
                    mscratch_wdata_d      = '0;
                    mepc_wdata_d          = '0;
                    mcause_wdata_d        = '0;
                    mtval_wdata_d         = '0;
                    mip_ssip_wdata_d      = '0;
                    mip_data              = '0;
                    menvcfg_wdata_d       = '0;
                    mcycle_wdata_d        = '0;
                    minstret_wdata_d      = '0;
                    pmpcfg0_wdata_d       = '0;
                    pmpcfg1_wdata_d       = '0;
                    pmpaddr_wdata_d[0 ]   = '0;
                    pmpaddr_wdata_d[1 ]   = '0;
                    pmpaddr_wdata_d[2 ]   = '0;
                    pmpaddr_wdata_d[3 ]   = '0;
                    pmpaddr_wdata_d[4 ]   = '0;
                    pmpaddr_wdata_d[5 ]   = '0;
                    pmpaddr_wdata_d[6 ]   = '0;
                    pmpaddr_wdata_d[7 ]   = '0;
                    pmpaddr_wdata_d[8 ]   = '0;
                    pmpaddr_wdata_d[9 ]   = '0;
                    pmpaddr_wdata_d[10]   = '0;
                    pmpaddr_wdata_d[11]   = '0;
                    pmpaddr_wdata_d[12]   = '0;
                    pmpaddr_wdata_d[13]   = '0;
                    pmpaddr_wdata_d[14]   = '0;
                    pmpaddr_wdata_d[15]   = '0;
                    stvec_wdata_d         = '0;
                    scounteren_wdata_d    = '0;
                    sscratch_wdata_d      = '0;
                    sepc_wdata_d          = '0;
                    scause_wdata_d        = '0;
                    stval_wdata_d         = '0;
                    stimecmp_wdata_d      = '0;
                    satp_wdata_d          = '0;

                    csr_wdata_log_o = '0;
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
            csr_pkg::CSR_MSTATUS      : rdata_o = mstatus_rdata_q;
            csr_pkg::CSR_MISA         : rdata_o = MISA_VALUE;
            csr_pkg::CSR_MEDELEG      : rdata_o = medeleg_rdata_q;
            csr_pkg::CSR_MIDELEG      : rdata_o = mideleg_rdata_q;
            csr_pkg::CSR_MIE          : rdata_o = mie_rdata_q;
            csr_pkg::CSR_MTVEC        : rdata_o = mtvec_rdata_q;
            csr_pkg::CSR_MCOUNTEREN   : rdata_o = {32'b0, mcounteren_rdata_q};
            csr_pkg::CSR_MCOUNTINHIBIT: rdata_o = {32'b0, mcountinhibit_rdata_q};
            csr_pkg::CSR_MSCRATCH     : rdata_o = mscratch_rdata_q;
            csr_pkg::CSR_MEPC         : rdata_o = mepc_rdata_q;
            csr_pkg::CSR_MCAUSE       : rdata_o = {mcause_rdata_q[CAUSE_W - 1], 58'b0, mcause_rdata_q[CAUSE_W - 2:0]};
            csr_pkg::CSR_MTVAL        : rdata_o = mtval_rdata_q;
            csr_pkg::CSR_MIP          : rdata_o = mip_data;
            csr_pkg::CSR_MENVCFG      : rdata_o = {menvcfg_rdata_q, 63'b0};
            csr_pkg::CSR_MCYCLE       : rdata_o = mcycle_rdata_q;
            csr_pkg::CSR_MINSTRET     : rdata_o = minstret_rdata_q;
            csr_pkg::CSR_PMPCFG0      : rdata_o = pmpcfg0_rdata_q;
            csr_pkg::CSR_PMPCFG1      : rdata_o = pmpcfg1_rdata_q;
            csr_pkg::CSR_PMPADDR0     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[0]};
            csr_pkg::CSR_PMPADDR1     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[1]};
            csr_pkg::CSR_PMPADDR2     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[2]};
            csr_pkg::CSR_PMPADDR3     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[3]};
            csr_pkg::CSR_PMPADDR4     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[4]};
            csr_pkg::CSR_PMPADDR5     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[5]};
            csr_pkg::CSR_PMPADDR6     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[6]};
            csr_pkg::CSR_PMPADDR7     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[7]};
            csr_pkg::CSR_PMPADDR8     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[8]};
            csr_pkg::CSR_PMPADDR9     : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[9]};
            csr_pkg::CSR_PMPADDR10    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[10]};
            csr_pkg::CSR_PMPADDR11    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[11]};
            csr_pkg::CSR_PMPADDR12    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[12]};
            csr_pkg::CSR_PMPADDR13    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[13]};
            csr_pkg::CSR_PMPADDR14    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[14]};
            csr_pkg::CSR_PMPADDR15    : rdata_o = {{(XLEN - PMP_ADDR_W){1'b0}}, pmpaddr_rdata_q[15]};
            csr_pkg::CSR_MVENDORID,
            csr_pkg::CSR_MARCHID,
            csr_pkg::CSR_MIMPID,
            csr_pkg::CSR_MHARTID      : rdata_o = '0;

            // Supervisor level CSRs.
            csr_pkg::CSR_SSTATUS      : rdata_o = {mstatus_rdata_q[63], 29'd0, mstatus_rdata_q[33:32], 7'b0,
                                                          mstatus_rdata_q[24:23], 3'b0,
                                                          mstatus_rdata_q[19:13], 2'b0,
                                                          mstatus_rdata_q[10:8 ], 1'b0,
                                                          mstatus_rdata_q[ 6:5 ], 3'b0,
                                                          mstatus_rdata_q[ 1   ], 1'b0};
            csr_pkg::CSR_SIE          : rdata_o = {50'd0, mie_rdata_q[13], 3'b0,
                                                          mie_rdata_q[ 9], 3'b0,
                                                          mie_rdata_q[ 5], 3'b0,
                                                          mie_rdata_q[ 1], 1'b0};
            csr_pkg::CSR_STVEC        : rdata_o = stvec_rdata_q;
            csr_pkg::CSR_SCOUNTEREN   : rdata_o = {32'b0, scounteren_rdata_q};
            csr_pkg::CSR_SSCRATCH     : rdata_o = sscratch_rdata_q;
            csr_pkg::CSR_SEPC         : rdata_o = sepc_rdata_q;
            csr_pkg::CSR_SCAUSE       : rdata_o = {scause_rdata_q[CAUSE_W - 1], 58'b0, scause_rdata_q[CAUSE_W - 2:0]};
            csr_pkg::CSR_STVAL        : rdata_o = stval_rdata_q;
            csr_pkg::CSR_SIP          : rdata_o = {50'd0, mip_data[13], 3'b0,
                                                        mip_data[ 9], 3'b0,
                                                        mip_data[ 5], 3'b0,
                                                        mip_data[ 1], 1'b0};
            csr_pkg::CSR_STIMECMP     : rdata_o = stimecmp_rdata_q;
            csr_pkg::CSR_SATP         : rdata_o = satp_rdata_q;

            // Unprivileged CSRs.
            csr_pkg::CSR_CYCLE        : rdata_o = mcycle_rdata_q;
            csr_pkg::CSR_TIME         : rdata_o = mtime_val_i;
            csr_pkg::CSR_INSTRET      : rdata_o = minstret_rdata_q;

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
        .DATA_WIDTH (2              ),
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

    // mcountinhibit.
    register_en # (
        .DATA_WIDTH (32       ),
        .RESET_VAL  (RESET_VAL)
    ) MCOUNTERINHIBIT_CSR0 (
        .clk_i   (clk_i                  ),
        .arst_i  (arst_i                 ),
        .we_i    (mcountinhibit_we     ),
        .wdata_i (mcountinhibit_wdata_d),
        .rdata_o (mcountinhibit_rdata_q)
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
    ) MENVCFG_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (menvcfg_we     ),
        .wdata_i (menvcfg_wdata_d),
        .rdata_o (menvcfg_rdata_q)
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

    // PMPCFG0.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) PMPCFG0_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (pmpcfg0_we     ),
        .wdata_i (pmpcfg0_wdata_d),
        .rdata_o (pmpcfg0_rdata_q)
    );

    // PMPCFG1.
    register_en # (
        .DATA_WIDTH (XLEN     ),
        .RESET_VAL  (RESET_VAL)
    ) PMPCFG1_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (pmpcfg1_we     ),
        .wdata_i (pmpcfg1_wdata_d),
        .rdata_o (pmpcfg1_rdata_q)
    );


    // PMPADDR CSRs.
    genvar i;
    generate
        for (i = 0; i < PMP_N; i++) begin : gen_pmpcsraddr
            register_en  # (
                .DATA_WIDTH (PMP_ADDR_W  ),
                .RESET_VAL  (RESET_VAL)
            ) PMPADDR_CSR0 (
                .clk_i   (clk_i             ),
                .arst_i  (arst_i            ),
                .we_i    (pmpaddr_we[i]     ),
                .wdata_i (pmpaddr_wdata_d[i]),
                .rdata_o (pmpaddr_rdata_q[i])
            );
        end
    endgenerate


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
    // PMP address range logic.
    //----------------------------
    genvar j;
    generate
        for (j = 0; j < PMP_N/2; j++) begin : gen_compute_pmp_range0
            if (j == 0) begin : gen_compute_pmp0_range0
                pmp_range  # (
                    .PMP_ADDR_W (PMP_ADDR_W),
                    .PA_W       (PA_W      )
                ) PMP0_RANGE0 (
                    .cfg_a_i    (pmpcfg0_rdata_q[4:3]),
                    .addr0_i    ('0                  ),
                    .addr1_i    (pmpaddr_rdata_q[j]  ),
                    .active_o   (pmp_data_o.active[j]),
                    .range_lo_o (pmpaddr_lo[j]       ),
                    .range_hi_o (pmpaddr_hi[j]       )
                );
            end else begin : gen_compute_pmp0_range1
                pmp_range  # (
                    .PMP_ADDR_W (PMP_ADDR_W),
                    .PA_W       (PA_W      )
                ) PMP0_RANGE1 (
                    .cfg_a_i    (pmpcfg0_rdata_q[(j * 8) + 4:(j * 8) + 3]),
                    .addr0_i    (pmpaddr_rdata_q[j - 1]                  ),
                    .addr1_i    (pmpaddr_rdata_q[j]                      ),
                    .active_o   (pmp_data_o.active[j]                    ),
                    .range_lo_o (pmpaddr_lo[j]                           ),
                    .range_hi_o (pmpaddr_hi[j]                           )
                );
            end
        end
    endgenerate
    genvar k;
    generate
        for (k = 0; k < PMP_N/2; k++) begin : gen_compute_pmp_range1
            pmp_range  # (
                .PMP_ADDR_W (PMP_ADDR_W),
                .PA_W       (PA_W      )
            ) PMP1_RANGE0 (
                .cfg_a_i    (pmpcfg1_rdata_q[(k * 8) + 4:(k * 8) + 3]),
                .addr0_i    (pmpaddr_rdata_q[k + 7]                  ),
                .addr1_i    (pmpaddr_rdata_q[k + 8]                  ),
                .active_o   (pmp_data_o.active[k + 8]                ),
                .range_lo_o (pmpaddr_lo[k + 8]                       ),
                .range_hi_o (pmpaddr_hi[k + 8]                       )
            );
        end
    endgenerate


    //----------------------------
    // Output logic.
    //----------------------------
    always_comb begin : blockName
        for (int m = 0; m < PMP_N/2; m++) begin
            pmp_data_o.R[m] = pmpcfg0_rdata_q[(m * 8)    ];
            pmp_data_o.W[m] = pmpcfg0_rdata_q[(m * 8) + 1];
            pmp_data_o.X[m] = pmpcfg0_rdata_q[(m * 8) + 2];
            pmp_data_o.L[m] = pmpcfg0_rdata_q[(m * 8) + 7];
        end

        for (int n = 0; n < PMP_N/2; n++) begin
            pmp_data_o.R[n + 8] = pmpcfg1_rdata_q[(n * 8)    ];
            pmp_data_o.W[n + 8] = pmpcfg1_rdata_q[(n * 8) + 1];
            pmp_data_o.X[n + 8] = pmpcfg1_rdata_q[(n * 8) + 2];
            pmp_data_o.L[n + 8] = pmpcfg1_rdata_q[(n * 8) + 7];
        end
    end

    assign pmp_data_o.pmpaddr0_lo  = pmpaddr_lo[0];
    assign pmp_data_o.pmpaddr0_hi  = pmpaddr_hi[0];
    assign pmp_data_o.pmpaddr1_lo  = pmpaddr_lo[1];
    assign pmp_data_o.pmpaddr1_hi  = pmpaddr_hi[1];
    assign pmp_data_o.pmpaddr2_lo  = pmpaddr_lo[2];
    assign pmp_data_o.pmpaddr2_hi  = pmpaddr_hi[2];
    assign pmp_data_o.pmpaddr3_lo  = pmpaddr_lo[3];
    assign pmp_data_o.pmpaddr3_hi  = pmpaddr_hi[3];
    assign pmp_data_o.pmpaddr4_lo  = pmpaddr_lo[4];
    assign pmp_data_o.pmpaddr4_hi  = pmpaddr_hi[4];
    assign pmp_data_o.pmpaddr5_lo  = pmpaddr_lo[5];
    assign pmp_data_o.pmpaddr5_hi  = pmpaddr_hi[5];
    assign pmp_data_o.pmpaddr6_lo  = pmpaddr_lo[6];
    assign pmp_data_o.pmpaddr6_hi  = pmpaddr_hi[6];
    assign pmp_data_o.pmpaddr7_lo  = pmpaddr_lo[7];
    assign pmp_data_o.pmpaddr7_hi  = pmpaddr_hi[7];
    assign pmp_data_o.pmpaddr8_lo  = pmpaddr_lo[8];
    assign pmp_data_o.pmpaddr8_hi  = pmpaddr_hi[8];
    assign pmp_data_o.pmpaddr9_lo  = pmpaddr_lo[9];
    assign pmp_data_o.pmpaddr9_hi  = pmpaddr_hi[9];
    assign pmp_data_o.pmpaddr10_lo = pmpaddr_lo[10];
    assign pmp_data_o.pmpaddr10_hi = pmpaddr_hi[10];
    assign pmp_data_o.pmpaddr11_lo = pmpaddr_lo[11];
    assign pmp_data_o.pmpaddr11_hi = pmpaddr_hi[11];
    assign pmp_data_o.pmpaddr12_lo = pmpaddr_lo[12];
    assign pmp_data_o.pmpaddr12_hi = pmpaddr_hi[12];
    assign pmp_data_o.pmpaddr13_lo = pmpaddr_lo[13];
    assign pmp_data_o.pmpaddr13_hi = pmpaddr_hi[13];
    assign pmp_data_o.pmpaddr14_lo = pmpaddr_lo[14];
    assign pmp_data_o.pmpaddr14_hi = pmpaddr_hi[14];
    assign pmp_data_o.pmpaddr15_lo = pmpaddr_lo[15];
    assign pmp_data_o.pmpaddr15_hi = pmpaddr_hi[15];

    //----------------------------
    // Detect interrupts.
    //----------------------------
    assign msi = (mip_data[3] & mie_rdata_q[3]);
    assign mti = (mip_data[7] & mie_rdata_q[7]);
    assign ssi = (mip_data[1] & mie_rdata_q[1]);
    assign sti = (mip_data[5] & mie_rdata_q[5]);

    assign ssi_to_m = ssi && (~mideleg_rdata_q[{1'b0, (CAUSE_W - 1)'(csr_pkg::IRQ_S_SW)}]);
    assign sti_to_m = sti && (~mideleg_rdata_q[{1'b0, (CAUSE_W - 1)'(csr_pkg::IRQ_S_TIMER)}]);
    assign ssi_to_s = ssi && mideleg_rdata_q[{1'b0, (CAUSE_W - 1)'(csr_pkg::IRQ_S_SW)}];
    assign sti_to_s = sti && mideleg_rdata_q[{1'b0, (CAUSE_W - 1)'(csr_pkg::IRQ_S_TIMER)}];

    always_comb begin
        iqr_detected_o = 1'b0;
        trap_cause_o   = '0;

        case (priv_mode_q)
            csr_pkg::PRIV_M: begin
                if (mstatus_rdata_q[3]) begin
                    if (msi) begin
                        iqr_detected_o = 1'b1;
                        trap_cause_o   = csr_pkg::IRQ_M_SW;
                    end else if (mti) begin
                        iqr_detected_o = 1'b1;
                        trap_cause_o   = csr_pkg::IRQ_M_TIMER;
                    end else if (ssi_to_m) begin
                        iqr_detected_o = 1'b1;
                        trap_cause_o   = csr_pkg::IRQ_S_SW;
                    end else if (sti_to_m) begin
                        iqr_detected_o = 1'b1;
                        trap_cause_o   = csr_pkg::IRQ_S_TIMER;
                    end
                end
            end
            csr_pkg::PRIV_S: begin
                if (msi) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_M_SW;
                end else if (mti) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_M_TIMER;
                end else if (ssi_to_m) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_SW;
                end else if (sti_to_m) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_TIMER;
                end else if (mstatus_rdata_q[1] && ssi_to_s) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_SW;
                end else if (mstatus_rdata_q[1] && sti_to_s) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_TIMER;
                end
            end
            csr_pkg::PRIV_U: begin
                if (msi) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_M_SW;
                end else if (mti) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_M_TIMER;
                end else if (ssi_to_m) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_SW;
                end else if (sti_to_m) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_TIMER;
                end else if (ssi_to_s) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_SW;
                end else if (sti_to_s) begin
                    iqr_detected_o = 1'b1;
                    trap_cause_o   = csr_pkg::IRQ_S_TIMER;
                end
            end
            default: begin
                iqr_detected_o = 1'b0;
                trap_cause_o   = '0;
            end
        endcase
    end

endmodule
