/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 03/07/2026
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

module csr_file
// Parameters.
#(
    parameter CSR_DATA_W = 64,
    parameter CSR_ADDR_W = 12,
    parameter CAUSE_W    = 6,
    parameter RESET_VAL  = '0
)
// Port decleration.
(
    // Common clock & reset signals.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic                    we_i,
    input  logic [CSR_DATA_W - 1:0] wdata_i,
    input  logic [CSR_ADDR_W - 1:0] raddr_i,
    input  logic [CSR_ADDR_W - 1:0] waddr_i,
    input  logic                    csr_access_i,
    input  logic [CSR_DATA_W - 1:0] xepc_wdata_i,
    input  logic [CAUSE_W    - 1:0] xcause_wdata_i,
    input  logic                    trap_taken_i,
    input  logic                    trap_mret_i,
    input  logic                    trap_sret_i,
    input  logic [CSR_DATA_W - 1:0] mtime_val_i,
    input  logic                    timer_irq_i,
    input  logic                    software_irq_i,

    // Output interface.
    output logic [             1:0] priv_mode_o,
    output logic [CSR_DATA_W - 1:0] csr_xtvec_rdata_o,
    output logic [CSR_DATA_W - 1:0] csr_xepc_rdata_o,
    output logic                    illegal_instr_o,
    output logic                    iqr_detected_o,
    output logic [CAUSE_W    - 1:0] trap_cause_o,
    output logic [CSR_DATA_W - 1:0] mstatus_rdata_o,
    output logic [CSR_DATA_W - 1:0] rdata_o
);
    //----------------------------
    // Local parameters.
    //----------------------------
    localparam [1:0] M_MODE = 2'b11;
    localparam [1:0] S_MODE = 2'b01;
    localparam [1:0] U_MODE = 2'b00;

    localparam logic [CSR_DATA_W - 1:0] MISA_VALUE =
        (64'h2 << 62) |   // MXL = 2 for RV64.
        (64'h1 << 0)  |   // A.
        (64'h1 << 8)  |   // I.
        (64'h1 << 12) |   // M.
        (64'h1 << 18) |   // S-mode. In progress.
        (64'h1 << 20);    // U-mode. In progress.


    // Interrupt codes.
    localparam logic [CAUSE_W - 1:0] S_INT_SW    = {1'b1, 5'd1};
    localparam logic [CAUSE_W - 1:0] M_INT_SW    = {1'b1, 5'd3};
    localparam logic [CAUSE_W - 1:0] S_INT_TIMER = {1'b1, 5'd5};
    localparam logic [CAUSE_W - 1:0] M_INT_TIMER = {1'b1, 5'd7};
    localparam logic [CAUSE_W - 1:0] S_INT_EXT   = {1'b1, 5'd9};
    localparam logic [CAUSE_W - 1:0] M_INT_EXT   = {1'b1, 5'd11};

    // Exception codes.
    localparam logic [CAUSE_W - 1:0] X_INSTR_ADDR_MA      = 6'd0;
    localparam logic [CAUSE_W - 1:0] X_INSTR_ACCESS_FAULT = 6'd1;
    localparam logic [CAUSE_W - 1:0] X_ILLEGAL_INSTR      = 6'd2;
    localparam logic [CAUSE_W - 1:0] X_BREAKPOINT         = 6'd3;
    localparam logic [CAUSE_W - 1:0] X_LOAD_ADDR_MA       = 6'd4;
    localparam logic [CAUSE_W - 1:0] X_LOAD_ACCESS_FAULT  = 6'd5;
    localparam logic [CAUSE_W - 1:0] X_STORE_ADDR_MA      = 6'd6;
    localparam logic [CAUSE_W - 1:0] X_STORE_ACCESS_FAULT = 6'd7;
    localparam logic [CAUSE_W - 1:0] U_ENV_CALL           = 6'd8;
    localparam logic [CAUSE_W - 1:0] S_ENV_CALL           = 6'd9;
    localparam logic [CAUSE_W - 1:0] M_ENV_CALL           = 6'd11;
    localparam logic [CAUSE_W - 1:0] X_INSTR_PAGE_FAULT   = 6'd12;
    localparam logic [CAUSE_W - 1:0] X_LOAD_PAGE_FAULT    = 6'd13;
    localparam logic [CAUSE_W - 1:0] X_STORE_PAGE_FAULT   = 6'd15;
    localparam logic [CAUSE_W - 1:0] X_DOUBLE_TRAP        = 6'd16;
    localparam logic [CAUSE_W - 1:0] X_SW_CHECK           = 6'd18;
    localparam logic [CAUSE_W - 1:0] X_HW_ERROR           = 6'd19;


    // M-mode CSR addresses.
    localparam logic [CSR_ADDR_W - 1:0] MSTATUS_CSR_ADDR   = 12'h300;
    localparam logic [CSR_ADDR_W - 1:0] MISA_CSR_ADDR      = 12'h301;
    localparam logic [CSR_ADDR_W - 1:0] MEDELEG_CSR_ADDR   = 12'h302;
    localparam logic [CSR_ADDR_W - 1:0] MIDELEG_CSR_ADDR   = 12'h303;
    localparam logic [CSR_ADDR_W - 1:0] MIE_CSR_ADDR       = 12'h304;
    localparam logic [CSR_ADDR_W - 1:0] MTVEC_CSR_ADDR     = 12'h305;
    localparam logic [CSR_ADDR_W - 1:0] MSCRATCH_CSR_ADDR  = 12'h340;
    localparam logic [CSR_ADDR_W - 1:0] MEPC_CSR_ADDR      = 12'h341;
    localparam logic [CSR_ADDR_W - 1:0] MCAUSE_CSR_ADDR    = 12'h342;
    localparam logic [CSR_ADDR_W - 1:0] MTVAL_CSR_ADDR     = 12'h343; // Architecture: For now read-only zero.
    localparam logic [CSR_ADDR_W - 1:0] MIP_CSR_ADDR       = 12'h344; // Architecture: MIP is realized as read-only, only SSIP is writable.
    localparam logic [CSR_ADDR_W - 1:0] PMPCFG0_CSR_ADDR   = 12'h3A0; // For now just to avoid exceptions. Not implemented
    localparam logic [CSR_ADDR_W - 1:0] PMPADDR0_CSR_ADDR  = 12'h3B0; // For now just to avoid exceptions. Not implemented
    localparam logic [CSR_ADDR_W - 1:0] MVENDORID_CSR_ADDR = 12'hF11;
    localparam logic [CSR_ADDR_W - 1:0] MARCHID_CSR_ADDR   = 12'hF12;
    localparam logic [CSR_ADDR_W - 1:0] MIMPID_CSR_ADDR    = 12'hF13;
    localparam logic [CSR_ADDR_W - 1:0] MHARTID_CSR_ADDR   = 12'hF14;

    // M-mode CSR addresses.
    localparam logic [CSR_ADDR_W - 1:0] SSTATUS_CSR_ADDR   = 12'h100;
    localparam logic [CSR_ADDR_W - 1:0] SIE_CSR_ADDR       = 12'h104;
    localparam logic [CSR_ADDR_W - 1:0] STVEC_CSR_ADDR     = 12'h105;
    localparam logic [CSR_ADDR_W - 1:0] SSCRATCH_CSR_ADDR  = 12'h140;
    localparam logic [CSR_ADDR_W - 1:0] SEPC_CSR_ADDR      = 12'h141;
    localparam logic [CSR_ADDR_W - 1:0] SCAUSE_CSR_ADDR    = 12'h142;
    localparam logic [CSR_ADDR_W - 1:0] STVAL_CSR_ADDR     = 12'h143; // Architecture: For now read-only zero.
    localparam logic [CSR_ADDR_W - 1:0] SIP_CSR_ADDR       = 12'h144; // Architecture: SIP is realized as read-only, only SSIP is writable.
    localparam logic [CSR_ADDR_W - 1:0] STIMECMP_CSR_ADDR  = 12'h14D;
    localparam logic [CSR_ADDR_W - 1:0] SATP_CSR_ADDR      = 12'h180; // For now just to avoid exceptions. Not implemented

    // CSR addresses.
    localparam logic [CSR_ADDR_W - 1:0] TIME_CSR_ADDR = 12'hC01;


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
    logic mscratch_we;
    logic mepc_we;
    logic mcause_we;
    logic stvec_we;
    logic sscratch_we;
    logic sepc_we;
    logic scause_we;
    logic stimecmp_we;

    logic [CSR_DATA_W - 1:0] mstatus_wdata_d;
    logic [CSR_DATA_W - 1:0] medeleg_wdata_d;
    logic [CSR_DATA_W - 1:0] mideleg_wdata_d;
    logic [CSR_DATA_W - 1:0] mie_wdata_d;
    logic [CSR_DATA_W - 1:0] mtvec_wdata_d;
    logic [CSR_DATA_W - 1:0] mscratch_wdata_d;
    logic [CSR_DATA_W - 1:0] mepc_wdata_d;
    logic [CAUSE_W    - 1:0] mcause_wdata_d;
    logic [CSR_DATA_W - 1:0] mip_data;
    logic [CSR_DATA_W - 1:0] stvec_wdata_d;
    logic [CSR_DATA_W - 1:0] sscratch_wdata_d;
    logic [CSR_DATA_W - 1:0] sepc_wdata_d;
    logic [CAUSE_W    - 1:0] scause_wdata_d;
    logic [CSR_DATA_W - 1:0] stimecmp_wdata_d;

    logic [CSR_DATA_W - 1:0] mstatus_rdata_q;
    logic [CSR_DATA_W - 1:0] medeleg_rdata_q;
    logic [CSR_DATA_W - 1:0] mideleg_rdata_q;
    logic [CSR_DATA_W - 1:0] mie_rdata_q;
    logic [CSR_DATA_W - 1:0] mtvec_rdata_q;
    logic [CSR_DATA_W - 1:0] mscratch_rdata_q;
    logic [CSR_DATA_W - 1:0] mepc_rdata_q;
    logic [CAUSE_W    - 1:0] mcause_rdata_q;
    logic [CSR_DATA_W - 1:0] stvec_rdata_q;
    logic [CSR_DATA_W - 1:0] sscratch_rdata_q;
    logic [CSR_DATA_W - 1:0] sepc_rdata_q;
    logic [CAUSE_W    - 1:0] scause_rdata_q;
    logic [CSR_DATA_W - 1:0] stimecmp_rdata_q;

    logic mcause_legal;
    logic scause_legal;

    logic delegate;

    logic mip_ssip_we;
    logic mip_ssip_wdata_d;
    logic mip_ssip_rdata_q;

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

        case ({wdata_i[CSR_DATA_W - 1], wdata_i[CAUSE_W - 2:0]})
            S_INT_SW,
            S_INT_TIMER,
            S_INT_EXT,
            X_INSTR_ADDR_MA,
            X_INSTR_ACCESS_FAULT,
            X_ILLEGAL_INSTR,
            X_BREAKPOINT,
            X_LOAD_ADDR_MA,
            X_LOAD_ACCESS_FAULT,
            X_STORE_ADDR_MA,
            X_STORE_ACCESS_FAULT,
            U_ENV_CALL,
            S_ENV_CALL,
            X_INSTR_PAGE_FAULT,
            X_LOAD_PAGE_FAULT,
            X_STORE_PAGE_FAULT,
            X_SW_CHECK,
            X_HW_ERROR: begin
                mcause_legal = 1'b1;
                scause_legal = 1'b1;
            end
            M_INT_SW,
            M_INT_TIMER,
            M_INT_EXT,
            M_ENV_CALL,
            X_DOUBLE_TRAP: begin
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

        if (priv_mode_o == M_MODE) begin
            case (raddr_i)
                MSTATUS_CSR_ADDR,
                MISA_CSR_ADDR,
                MEDELEG_CSR_ADDR,
                MIDELEG_CSR_ADDR,
                MIE_CSR_ADDR,
                MTVEC_CSR_ADDR,
                MSCRATCH_CSR_ADDR,
                MEPC_CSR_ADDR,
                MCAUSE_CSR_ADDR,
                MTVAL_CSR_ADDR,
                MIP_CSR_ADDR,
                PMPCFG0_CSR_ADDR,
                PMPADDR0_CSR_ADDR,
                MVENDORID_CSR_ADDR,
                MARCHID_CSR_ADDR,
                MIMPID_CSR_ADDR,
                MHARTID_CSR_ADDR,
                SSTATUS_CSR_ADDR,
                SIE_CSR_ADDR,
                STVEC_CSR_ADDR,
                SSCRATCH_CSR_ADDR,
                SEPC_CSR_ADDR,
                SCAUSE_CSR_ADDR,
                STVAL_CSR_ADDR,
                SIP_CSR_ADDR,
                STIMECMP_CSR_ADDR,
                SATP_CSR_ADDR,
                TIME_CSR_ADDR: begin
                    illegal_instr_o = 1'b0;
                end
                default: begin
                    illegal_instr_o = csr_access_i;
                end
            endcase
        end else if (priv_mode_o == S_MODE) begin
            case (raddr_i)
                SSTATUS_CSR_ADDR,
                SIE_CSR_ADDR,
                STVEC_CSR_ADDR,
                SSCRATCH_CSR_ADDR,
                SEPC_CSR_ADDR,
                SCAUSE_CSR_ADDR,
                STVAL_CSR_ADDR,
                SIP_CSR_ADDR,
                STIMECMP_CSR_ADDR,
                SATP_CSR_ADDR,
                TIME_CSR_ADDR: begin
                    illegal_instr_o = 1'b0;
                end
                default: begin
                    illegal_instr_o = csr_access_i;
                end
            endcase
        end else begin
            illegal_instr_o = csr_access_i;
        end

    end



    //-----------------------------
    // Determine delegation logic.
    //-----------------------------
    assign delegate = (priv_mode_q < M_MODE) & (medeleg_rdata_q[xcause_wdata_i] | mideleg_rdata_q[{1'b0, xcause_wdata_i[CAUSE_W - 2:0]}]);


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

        mstatus_we  = 1'b0;
        medeleg_we  = 1'b0;
        mideleg_we  = 1'b0;
        mie_we      = 1'b0;
        mtvec_we    = 1'b0;
        mscratch_we = 1'b0;
        mepc_we     = 1'b0;
        mcause_we   = 1'b0;
        stvec_we    = 1'b0;
        sscratch_we = 1'b0;
        sepc_we     = 1'b0;
        scause_we   = 1'b0;
        stimecmp_we = 1'b0;

        mstatus_wdata_d  = '0;
        medeleg_wdata_d  = '0;
        mideleg_wdata_d  = '0;
        mie_wdata_d      = '0;
        mtvec_wdata_d    = '0;
        mscratch_wdata_d = '0;
        mepc_wdata_d     = '0;
        mcause_wdata_d   = '0;
        mip_data         = '0;
        stvec_wdata_d    = '0;
        sscratch_wdata_d = '0;
        sepc_wdata_d     = '0;
        scause_wdata_d   = '0;
        stimecmp_wdata_d = '0;

        mip_ssip_we      = '0;
        mip_ssip_wdata_d = '0;

        case (waddr_i)
            // Machine level CSRs.
            MSTATUS_CSR_ADDR: begin
                mstatus_we      = we_i;
                mstatus_wdata_d = {32'b1010, 12'b0, wdata_i[19:17], 4'b0,
                                                    wdata_i[12:11], 2'b0,
                                                    wdata_i[ 8:7 ], 1'b0,
                                                    wdata_i[ 5   ], 1'b0,
                                                    wdata_i[ 3   ], 1'b0,
                                                    wdata_i[ 1   ], 1'b0};
            end
            MEDELEG_CSR_ADDR: begin
                medeleg_we      = we_i;
                medeleg_wdata_d = {44'b0, wdata_i[19:18], 2'b0,
                                          wdata_i[15   ], 1'b0,
                                          wdata_i[13:12], 2'b0,
                                          wdata_i[ 9:0 ]};
            end
            MIDELEG_CSR_ADDR: begin
                mideleg_we      = we_i;
                mideleg_wdata_d = {54'b0, wdata_i[9], 3'b0,
                                          wdata_i[5], 3'b0,
                                          wdata_i[1], 1'b0};
            end
            MIE_CSR_ADDR: begin
                mie_we      = we_i;
                mie_wdata_d = {50'b0, wdata_i[13], 1'b0,
                                      wdata_i[11], 1'b0,
                                      wdata_i[ 9], 1'b0,
                                      wdata_i[ 7], 1'b0,
                                      wdata_i[ 5], 1'b0,
                                      wdata_i[ 3], 1'b0,
                                      wdata_i[ 1], 1'b0};
            end
            MTVEC_CSR_ADDR: begin
                mtvec_we      = we_i;
                mtvec_wdata_d = {wdata_i[CSR_DATA_W - 1:2], 1'b0, wdata_i[0]};
            end
            MSCRATCH_CSR_ADDR: begin
                mscratch_we      = we_i;
                mscratch_wdata_d = wdata_i;
            end
            MEPC_CSR_ADDR: begin
                mepc_we      = we_i;
                mepc_wdata_d = {wdata_i[CSR_DATA_W - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
            end
            MCAUSE_CSR_ADDR: begin
                mcause_we      = we_i && mcause_legal;
                mcause_wdata_d = {wdata_i[CSR_DATA_W - 1], wdata_i[CAUSE_W - 2:0]};
            end
            MIP_CSR_ADDR,
            SIP_CSR_ADDR: begin
                mip_ssip_we      = 1'b1;
                mip_ssip_wdata_d = wdata_i[1];
            end


            // Supervisor level CSRs.
            SSTATUS_CSR_ADDR: begin
                mstatus_we      = we_i;
                mstatus_wdata_d = {mstatus_rdata_q[63:20], wdata_i[19:18], mstatus_rdata_q[17:9],
                                                           wdata_i[    8], mstatus_rdata_q[ 7:6],
                                                           wdata_i[    5], mstatus_rdata_q[ 4:2],
                                                           wdata_i[    1], mstatus_rdata_q[   0]};
            end
            SIE_CSR_ADDR: begin
                mie_we      = we_i;
                mie_wdata_d = {mie_rdata_q[63:14], wdata_i[13], mie_rdata_q[12:10],
                                                   wdata_i[ 9], mie_rdata_q[ 8:6 ],
                                                   wdata_i[ 5], mie_rdata_q[ 4:2 ],
                                                   wdata_i[ 1], mie_rdata_q[ 0   ]};
            end
            STVEC_CSR_ADDR: begin
                stvec_we      = we_i;
                stvec_wdata_d = {wdata_i[CSR_DATA_W - 1:2], 1'b0, wdata_i[0]};
            end
            SSCRATCH_CSR_ADDR: begin
                sscratch_we      = we_i;
                sscratch_wdata_d = wdata_i;
            end
            SEPC_CSR_ADDR: begin
                sepc_we      = we_i;
                sepc_wdata_d = {wdata_i[CSR_DATA_W - 1:2], 2'b0}; // Architecture: Currently IALIGN = 32.
            end
            SCAUSE_CSR_ADDR: begin
                scause_we      = we_i && scause_legal;
                scause_wdata_d = {wdata_i[CSR_DATA_W - 1], wdata_i[CAUSE_W - 2:0]};
            end
            STIMECMP_CSR_ADDR: begin
                stimecmp_we      = we_i;
                stimecmp_wdata_d = wdata_i;
            end
            default: begin
                mstatus_we  = 1'b0;
                medeleg_we  = 1'b0;
                mideleg_we  = 1'b0;
                mie_we      = 1'b0;
                mtvec_we    = 1'b0;
                mscratch_we = 1'b0;
                mepc_we     = 1'b0;
                mcause_we   = 1'b0;
                stvec_we    = 1'b0;
                sscratch_we = 1'b0;
                sepc_we     = 1'b0;
                scause_we   = 1'b0;
                stimecmp_we = 1'b0;

                mstatus_wdata_d  = '0;
                medeleg_wdata_d  = '0;
                mideleg_wdata_d  = '0;
                mie_wdata_d      = '0;
                mtvec_wdata_d    = '0;
                mscratch_wdata_d = '0;
                mepc_wdata_d     = '0;
                mcause_wdata_d   = '0;
                mip_data         = '0;
                stvec_wdata_d    = '0;
                sscratch_wdata_d = '0;
                sepc_wdata_d     = '0;
                scause_wdata_d   = '0;
                stimecmp_wdata_d = '0;

                mip_ssip_we      = '0;
                mip_ssip_wdata_d = '0;
            end
        endcase


        // Trap taken.
        if (trap_taken_i) begin
            if (delegate) begin // Delegated to S-mode.
                csr_xtvec_rdata_o = ((stvec_rdata_q >> 2) << 2) + (64'd4 * {63'b0, stvec_rdata_q[0]});
                priv_mode_we      = 1'b1;
                priv_mode_d       = S_MODE;

                mstatus_we  = 1'b1;
                sepc_we     = 1'b1;
                scause_we   = 1'b1;

                mstatus_wdata_d = {mstatus_rdata_q[63:9], priv_mode_q[0], mstatus_rdata_q[7:6], mstatus_rdata_q[1], mstatus_rdata_q[4:2], 1'b0, mstatus_rdata_q[0]};
                sepc_wdata_d    = xepc_wdata_i;
                scause_wdata_d  = xcause_wdata_i;
            end else begin // Handled by M-mode.
                csr_xtvec_rdata_o = ((mtvec_rdata_q >> 2) << 2) + (64'd4 * {63'b0, mtvec_rdata_q[0]});
                priv_mode_we      = 1'b1;
                priv_mode_d       = M_MODE;

                mstatus_we  = 1'b1;
                mepc_we     = 1'b1;
                mcause_we   = 1'b1;

                mstatus_wdata_d = {mstatus_rdata_q[63:13], priv_mode_q, mstatus_rdata_q[10:8], mstatus_rdata_q[3], mstatus_rdata_q[6:4], 1'b0, mstatus_rdata_q[2:0]};
                mepc_wdata_d    = xepc_wdata_i;
                mcause_wdata_d  = xcause_wdata_i;
            end
        end
        else if (trap_mret_i) begin // MRET.
            csr_xepc_rdata_o  = mepc_rdata_q;
            priv_mode_we      = 1'b1;
            priv_mode_d       = mstatus_rdata_q[12:11];

            mstatus_we = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:13], U_MODE, mstatus_rdata_q[10:8], 1'b1, mstatus_rdata_q[6:4], mstatus_rdata_q[7], mstatus_rdata_q[2:0]};
        end
        else if (trap_sret_i) begin // SRET.
            csr_xepc_rdata_o  = sepc_rdata_q;
            priv_mode_we      = 1'b1;
            priv_mode_d       = {1'b0, mstatus_rdata_q[8]};

            mstatus_we = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:9], U_MODE[0], mstatus_rdata_q[7:6], 1'b1, mstatus_rdata_q[4:2], mstatus_rdata_q[5], mstatus_rdata_q[0]};
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
            MSTATUS_CSR_ADDR : rdata_o = mstatus_rdata_q;
            MISA_CSR_ADDR    : rdata_o = MISA_VALUE;
            MEDELEG_CSR_ADDR : rdata_o = medeleg_rdata_q;
            MIDELEG_CSR_ADDR : rdata_o = mideleg_rdata_q;
            MIE_CSR_ADDR     : rdata_o = mie_rdata_q;
            MTVEC_CSR_ADDR   : rdata_o = mtvec_rdata_q;
            MSCRATCH_CSR_ADDR: rdata_o = mscratch_rdata_q;
            MEPC_CSR_ADDR    : rdata_o = mepc_rdata_q;
            MCAUSE_CSR_ADDR  : rdata_o = {mcause_rdata_q[CAUSE_W - 1], 58'b0, mcause_rdata_q[CAUSE_W - 2:0]};
            MIP_CSR_ADDR     : rdata_o = mip_data;
            TIME_CSR_ADDR    : rdata_o = mtime_val_i;
            MTVAL_CSR_ADDR,
            MVENDORID_CSR_ADDR,
            MARCHID_CSR_ADDR,
            MIMPID_CSR_ADDR,
            MHARTID_CSR_ADDR : rdata_o = '0;

            // Supervisor level CSRs.
            SSTATUS_CSR_ADDR : rdata_o = {30'd0, mstatus_rdata_q[33:32], 7'b0,
                                                 mstatus_rdata_q[24:23], 3'b0,
                                                 mstatus_rdata_q[19:13], 2'b0,
                                                 mstatus_rdata_q[10:8 ], 1'b0,
                                                 mstatus_rdata_q[ 6:5 ], 3'b0,
                                                 mstatus_rdata_q[ 1   ], 1'b0};
            SIE_CSR_ADDR     : rdata_o = {50'd0, mie_rdata_q[13], 3'b0,
                                                 mie_rdata_q[ 9], 3'b0,
                                                 mie_rdata_q[ 5], 3'b0,
                                                 mie_rdata_q[ 1], 1'b0};
            STVEC_CSR_ADDR   : rdata_o = stvec_rdata_q;
            SSCRATCH_CSR_ADDR: rdata_o = sscratch_rdata_q;
            SEPC_CSR_ADDR    : rdata_o = sepc_rdata_q;
            SCAUSE_CSR_ADDR  : rdata_o = {scause_rdata_q[CAUSE_W - 1], 58'b0, scause_rdata_q[CAUSE_W - 2:0]};
            SIP_CSR_ADDR     : rdata_o = {50'd0, mip_data[13], 3'b0,
                                                 mip_data[ 9], 3'b0,
                                                 mip_data[ 5], 3'b0,
                                                 mip_data[ 1], 1'b0};
            STIMECMP_CSR_ADDR: rdata_o = stimecmp_rdata_q;
            STVAL_CSR_ADDR   : rdata_o = '0;

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
        .RESET_VAL  (M_MODE) // M-mode.
    ) PRIV_mode_REG0 (
        .clk_i   (clk_i      ),
        .arst_i  (arst_i     ),
        .we_i    (priv_mode_we),
        .wdata_i (priv_mode_d ),
        .rdata_o (priv_mode_q )
    );
    assign priv_mode_o = priv_mode_we ? priv_mode_d : priv_mode_q;

    //----------------------------
    // Machine level CSRs.
    //----------------------------

    // mstatus.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W   ),
        .RESET_VAL  (64'ha00000000)
    ) MSTATUS_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (mstatus_we     ),
        .wdata_i (mstatus_wdata_d),
        .rdata_o (mstatus_rdata_q)
    );
    assign mstatus_rdata_o = mstatus_we ? mstatus_wdata_d : mstatus_rdata_q;

    // medeleg.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MEDELEG_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (medeleg_we     ),
        .wdata_i (medeleg_wdata_d),
        .rdata_o (medeleg_rdata_q)
    );

    // mideleg.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MIDELEG_CSR0 (
        .clk_i   (clk_i          ),
        .arst_i  (arst_i         ),
        .we_i    (mideleg_we     ),
        .wdata_i (mideleg_wdata_d),
        .rdata_o (mideleg_rdata_q)
    );

    // mie.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MIE_CSR0 (
        .clk_i   (clk_i      ),
        .arst_i  (arst_i     ),
        .we_i    (mie_we     ),
        .wdata_i (mie_wdata_d),
        .rdata_o (mie_rdata_q)
    );

    // mtvec.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MTVEC_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (mtvec_we     ),
        .wdata_i (mtvec_wdata_d),
        .rdata_o (mtvec_rdata_q)
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MSCRATCH_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (mscratch_we     ),
        .wdata_i (mscratch_wdata_d),
        .rdata_o (mscratch_rdata_q)
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MEPC_CSR0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (mepc_we     ),
        .wdata_i (mepc_wdata_d),
        .rdata_o (mepc_rdata_q)
    );

    // mcause.
    register_en # (
        .DATA_WIDTH (CAUSE_W ),
        .RESET_VAL  (RESET_VAL)
    ) MCAUSE_CSR0 (
        .clk_i   (clk_i         ),
        .arst_i  (arst_i        ),
        .we_i    (mcause_we     ),
        .wdata_i (mcause_wdata_d),
        .rdata_o (mcause_rdata_q)
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




    //----------------------------
    // Supervisor level CSRs.
    //----------------------------

    // stvec.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) STVEC_CSR0 (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    (stvec_we     ),
        .wdata_i (stvec_wdata_d),
        .rdata_o (stvec_rdata_q)
    );

    // sscratch.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) SSCRATCH_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (sscratch_we     ),
        .wdata_i (sscratch_wdata_d),
        .rdata_o (sscratch_rdata_q)
    );

    // sepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) SEPC_CSR0 (
        .clk_i   (clk_i       ),
        .arst_i  (arst_i      ),
        .we_i    (sepc_we     ),
        .wdata_i (sepc_wdata_d),
        .rdata_o (sepc_rdata_q)
    );

    // scause.
    register_en # (
        .DATA_WIDTH (CAUSE_W ),
        .RESET_VAL  (RESET_VAL)
    ) SCAUSE_CSR0 (
        .clk_i   (clk_i         ),
        .arst_i  (arst_i        ),
        .we_i    (scause_we     ),
        .wdata_i (scause_wdata_d),
        .rdata_o (scause_rdata_q)
    );

    // stimecmp.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W          ),
        .RESET_VAL  (64'hFFFFFFFFFFFFFFFF)
    ) STIMECMP_CSR0 (
        .clk_i   (clk_i           ),
        .arst_i  (arst_i          ),
        .we_i    (stimecmp_we     ),
        .wdata_i (stimecmp_wdata_d),
        .rdata_o (stimecmp_rdata_q)
    );




    //----------------------------
    // Output logic.
    //----------------------------

    //----------------------------
    // Detect interrupts.
    //----------------------------
    assign m_mode_timer_irq    = (mip_data[7] & mie_rdata_q[7]);
    assign m_mode_software_irq = (mip_data[3] & mie_rdata_q[3]);
    assign m_mode_irq          = m_mode_timer_irq | m_mode_software_irq;
    assign m_mode_irq_cause    = m_mode_software_irq ? {1'b1, 5'd3} : {1'b1, 5'd7}; // Software interrupt has higher priority than timer interrupt.

    assign s_mode_timer_irq    = (mip_data[5] & mie_rdata_q[5]);
    assign s_mode_software_irq = (mip_data[1] & mie_rdata_q[1]);
    assign s_mode_irq          = s_mode_timer_irq | s_mode_software_irq;
    assign s_mode_irq_cause    = s_mode_software_irq ? {1'b1, 5'd1} : {1'b1, 5'd5}; // Software interrupt has higher priority than timer interrupt.

    always_comb begin
        iqr_detected_o = 1'b0;
        trap_cause_o   = '0;

        case (priv_mode_q)
            M_MODE: begin
                iqr_detected_o = mstatus_rdata_q[3] & (m_mode_irq | (s_mode_irq & (~mideleg_rdata_q[{1'b0, s_mode_irq_cause[CAUSE_W - 2:0]}])));
                trap_cause_o   = m_mode_irq_cause;
            end
            S_MODE: begin
                iqr_detected_o = m_mode_irq | (mstatus_rdata_q[1] & s_mode_irq);
                trap_cause_o   = m_mode_irq ? m_mode_irq_cause : s_mode_irq_cause;
            end
            U_MODE: begin
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
