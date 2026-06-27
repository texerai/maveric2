/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 18/06/2026
//------------------------------

// -------------------------------------------------------------
// This is a csr register file with all the CSRs implemented in
// the design. Currently implemented list of CSRs:
// - mtvec
// - mepc
// - mcause
// -------------------------------------------------------------

module csr_file
// Parameters.
#(
    parameter CSR_DATA_W = 64,
    parameter CSR_ADDR_W = 12,
    parameter MCAUSE_W   = 6,
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
    input  logic [CSR_DATA_W - 1:0] mepc_wdata_i,
    input  logic [MCAUSE_W   - 1:0] mcause_wdata_i,
    input  logic                    trap_taken_i,
    input  logic                    trap_return_i,
    input  logic [CSR_DATA_W - 1:0] mtime_val_i,
    input  logic                    timer_irq_i,
    input  logic                    software_irq_i,

    // Output interface.
    output logic [CSR_DATA_W - 1:0] csr_mtvec_rdata_o,
    output logic [CSR_DATA_W - 1:0] csr_mepc_rdata_o,
    output logic                    iqr_detected_o,
    output logic [MCAUSE_W   - 1:0] trap_cause_o,
    output logic [CSR_DATA_W - 1:0] mstatus_rdata_o,
    output logic [CSR_DATA_W - 1:0] rdata_o
);
    //----------------------------
    // Local parameters.
    //----------------------------

    // Interrupt codes.
    localparam logic [MCAUSE_W - 1:0] S_INT_SW    = {1'b1, 5'd1};
    localparam logic [MCAUSE_W - 1:0] M_INT_SW    = {1'b1, 5'd3};
    localparam logic [MCAUSE_W - 1:0] S_INT_TIMER = {1'b1, 5'd5};
    localparam logic [MCAUSE_W - 1:0] M_INT_TIMER = {1'b1, 5'd7};
    localparam logic [MCAUSE_W - 1:0] S_INT_EXT   = {1'b1, 5'd9};
    localparam logic [MCAUSE_W - 1:0] M_INT_EXT   = {1'b1, 5'd11};

    // Exception codes.
    localparam logic [MCAUSE_W - 1:0] X_INSTR_ADDR_MA      = 6'd0;
    localparam logic [MCAUSE_W - 1:0] X_INSTR_ACCESS_FAULT = 6'd1;
    localparam logic [MCAUSE_W - 1:0] X_ILLEGAL_INSTR      = 6'd2;
    localparam logic [MCAUSE_W - 1:0] X_BREAKPOINT         = 6'd3;
    localparam logic [MCAUSE_W - 1:0] X_LOAD_ADDR_MA       = 6'd4;
    localparam logic [MCAUSE_W - 1:0] X_LOAD_ACCESS_FAULT  = 6'd5;
    localparam logic [MCAUSE_W - 1:0] X_STORE_ADDR_MA      = 6'd6;
    localparam logic [MCAUSE_W - 1:0] X_STORE_ACCESS_FAULT = 6'd7;
    localparam logic [MCAUSE_W - 1:0] U_ENV_CALL           = 6'd8;
    localparam logic [MCAUSE_W - 1:0] S_ENV_CALL           = 6'd9;
    localparam logic [MCAUSE_W - 1:0] M_ENV_CALL           = 6'd11;
    localparam logic [MCAUSE_W - 1:0] X_INSTR_PAGE_FAULT   = 6'd12;
    localparam logic [MCAUSE_W - 1:0] X_LOAD_PAGE_FAULT    = 6'd13;
    localparam logic [MCAUSE_W - 1:0] X_STORE_PAGE_FAULT   = 6'd15;
    localparam logic [MCAUSE_W - 1:0] X_DOUBLE_TRAP        = 6'd16;
    localparam logic [MCAUSE_W - 1:0] X_SW_CHECK           = 6'd18;
    localparam logic [MCAUSE_W - 1:0] X_HW_ERROR           = 6'd19;


    // M-mode CSR addresses.
    localparam logic [CSR_ADDR_W - 1:0] MSTATUS_CSR_ADDR   = 12'h300;
    localparam logic [CSR_ADDR_W - 1:0] MIE_CSR_ADDR       = 12'h304;
    localparam logic [CSR_ADDR_W - 1:0] MTVEC_CSR_ADDR     = 12'h305;
    localparam logic [CSR_ADDR_W - 1:0] MSCRATCH_CSR_ADDR  = 12'h340;
    localparam logic [CSR_ADDR_W - 1:0] MEPC_CSR_ADDR      = 12'h341;
    localparam logic [CSR_ADDR_W - 1:0] MCAUSE_CSR_ADDR    = 12'h342;
    localparam logic [CSR_ADDR_W - 1:0] MIP_CSR_ADDR       = 12'h344; // Architecture: MIP is realized as read-only.
    // localparam logic [CSR_ADDR_W - 1:0] MVENDORID_CSR_ADDR = 12'hF11;
    // localparam logic [CSR_ADDR_W - 1:0] MARCHID_CSR_ADDR   = 12'hF12;
    // localparam logic [CSR_ADDR_W - 1:0] MIMPID_CSR_ADDR    = 12'hF13;
    // localparam logic [CSR_ADDR_W - 1:0] MHARTID_CSR_ADDR   = 12'hF14;

    // CSR addresses.
    localparam logic [CSR_ADDR_W - 1:0] TIME_CSR_ADDR = 12'hC01;


    //----------------------------
    // Internal nets.
    //----------------------------
    logic mstatus_we;
    logic mie_we;
    logic mtvec_we;
    logic mscratch_we;
    logic mepc_we;
    logic mcause_we;

    logic [CSR_DATA_W   - 1:0] mstatus_wdata_d;
    logic [CSR_DATA_W   - 1:0] mie_wdata_d;
    logic [CSR_DATA_W   - 1:0] mtvec_wdata_d;
    logic [CSR_DATA_W   - 1:0] mscratch_wdata_d;
    logic [CSR_DATA_W   - 1:0] mepc_wdata_d;
    logic [MCAUSE_W     - 1:0] mcause_wdata_d;
    logic [CSR_DATA_W   - 1:0] mip_data;

    logic [CSR_DATA_W   - 1:0] mstatus_rdata_q;
    logic [CSR_DATA_W   - 1:0] mie_rdata_q;
    logic [CSR_DATA_W   - 1:0] mtvec_rdata_q;
    logic [CSR_DATA_W   - 1:0] mscratch_rdata_q;
    logic [CSR_DATA_W   - 1:0] mepc_rdata_q;
    logic [MCAUSE_W     - 1:0] mcause_rdata_q;

    logic mcause_legal;


    //----------------------------
    // Determine legal mcause.
    //----------------------------

    always_comb begin
        mcause_legal = 1'b0;

        case ({wdata_i[CSR_DATA_W - 1], wdata_i[MCAUSE_W - 2:0]})
            S_INT_SW,
            M_INT_SW,
            S_INT_TIMER,
            M_INT_TIMER,
            S_INT_EXT,
            M_INT_EXT,
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
            M_ENV_CALL,
            X_INSTR_PAGE_FAULT,
            X_LOAD_PAGE_FAULT,
            X_STORE_PAGE_FAULT,
            X_DOUBLE_TRAP,
            X_SW_CHECK,
            X_HW_ERROR: begin
                mcause_legal = 1'b1;
            end
            default: begin
                mcause_legal = 1'b0;
            end
        endcase
    end


    //----------------------------
    // Write logic decode.
    //----------------------------

    // Write 0.
    always_comb begin
        // Default values.
        mstatus_we  = 1'b0;
        mie_we      = 1'b0;
        mtvec_we    = 1'b0;
        mscratch_we = 1'b0;
        mepc_we     = 1'b0;
        mcause_we   = 1'b0;

        mstatus_wdata_d  = '0;
        mie_wdata_d      = '0;
        mtvec_wdata_d    = '0;
        mscratch_wdata_d = '0;
        mepc_wdata_d     = '0;
        mcause_wdata_d   = '0;

        case (waddr_i)
            MSTATUS_CSR_ADDR: begin
                mstatus_we      = we_i;
                mstatus_wdata_d = {wdata_i[CSR_DATA_W - 1:36], 4'b1010, 9'b0, wdata_i[22:17], 4'b0, 2'b11, wdata_i[10:0]};
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
                mepc_wdata_d = {wdata_i[CSR_DATA_W - 1:2], 2'b0}; // Currently IALIGN = 32.
            end
            MCAUSE_CSR_ADDR: begin
                mcause_we      = we_i && mcause_legal;
                mcause_wdata_d = {wdata_i[CSR_DATA_W - 1], wdata_i[MCAUSE_W - 2:0]};
            end
            default: begin
                mstatus_we  = 1'b0;
                mie_we      = 1'b0;
                mtvec_we    = 1'b0;
                mscratch_we = 1'b0;
                mepc_we     = 1'b0;
                mcause_we   = 1'b0;

                mstatus_wdata_d  = '0;
                mie_wdata_d      = '0;
                mtvec_wdata_d    = '0;
                mscratch_wdata_d = '0;
                mepc_wdata_d     = '0;
                mcause_wdata_d   = '0;
            end
        endcase


        // Trap taken.
        if (trap_taken_i) begin
            mstatus_we = 1'b1;
            mepc_we    = 1'b1;
            mcause_we  = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:8], mstatus_rdata_q[3], mstatus_rdata_q[6:4], 1'b0, mstatus_rdata_q[2:0]};
            mepc_wdata_d    = mepc_wdata_i;
            mcause_wdata_d  = mcause_wdata_i;
        end
        else if (trap_return_i) begin
            mstatus_we = 1'b1;

            mstatus_wdata_d = {mstatus_rdata_q[63:8], 1'b1, mstatus_rdata_q[6:4], mstatus_rdata_q[7], mstatus_rdata_q[2:0]};
        end

        // MIP.
        mip_data = {56'b0, timer_irq_i, 3'b0, software_irq_i, 3'b0};

    end

    //----------------------------
    // Read logic decode.
    //----------------------------

    // Read 0.
    always_comb begin
        // Default values.
        rdata_o = '0;

        case (raddr_i)
            MSTATUS_CSR_ADDR : rdata_o = mstatus_we ? mstatus_wdata_d : mstatus_rdata_q;
            MIE_CSR_ADDR     : rdata_o = mie_we ? mie_wdata_d : mie_rdata_q;
            MTVEC_CSR_ADDR   : rdata_o = mtvec_we ? mtvec_wdata_d : mtvec_rdata_q;
            MSCRATCH_CSR_ADDR: rdata_o = mscratch_we ? mscratch_wdata_d : mscratch_rdata_q;
            MEPC_CSR_ADDR    : rdata_o = mepc_we ? mepc_wdata_d : mepc_rdata_q;
            MCAUSE_CSR_ADDR  : rdata_o = {mcause_rdata_q[MCAUSE_W - 1], 58'b0, mcause_rdata_q[MCAUSE_W - 2:0]};
            MIP_CSR_ADDR     : rdata_o = mip_data;
            TIME_CSR_ADDR    : rdata_o = mtime_val_i;
            default: begin
                rdata_o = '0;
            end
        endcase
    end


    //----------------------------
    // Lower-level modulues:
    // CS registers.
    //----------------------------

    // mstatus.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W   ),
        .RESET_VAL  (64'ha00001800)
    ) MSTATUS_CSR0 (
        .clk_i        (clk_i          ),
        .arst_i       (arst_i         ),
        .we_i   (mstatus_we     ),
        .wdata_i (mstatus_wdata_d),
        .rdata_o  (mstatus_rdata_q)
    );
    assign mstatus_rdata_o = mstatus_we ? mstatus_wdata_d : mstatus_rdata_q;

    // mie.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MIE_CSR0 (
        .clk_i        (clk_i      ),
        .arst_i       (arst_i     ),
        .we_i   (mie_we     ),
        .wdata_i (mie_wdata_d),
        .rdata_o  (mie_rdata_q)
    );

    // mtvec.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MTVEC_CSR0 (
        .clk_i        (clk_i        ),
        .arst_i       (arst_i       ),
        .we_i   (mtvec_we     ),
        .wdata_i (mtvec_wdata_d),
        .rdata_o  (mtvec_rdata_q)
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MSCRATCH_CSR0 (
        .clk_i        (clk_i           ),
        .arst_i       (arst_i          ),
        .we_i   (mscratch_we     ),
        .wdata_i (mscratch_wdata_d),
        .rdata_o  (mscratch_rdata_q)
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_W),
        .RESET_VAL  (RESET_VAL )
    ) MEPC_CSR0 (
        .clk_i        (clk_i       ),
        .arst_i       (arst_i      ),
        .we_i   (mepc_we     ),
        .wdata_i (mepc_wdata_d),
        .rdata_o  (mepc_rdata_q)
    );

    // mcause.
    register_en # (
        .DATA_WIDTH (MCAUSE_W ),
        .RESET_VAL  (RESET_VAL)
    ) MCAUSE_CSR0 (
        .clk_i        (clk_i         ),
        .arst_i       (arst_i        ),
        .we_i   (mcause_we     ),
        .wdata_i (mcause_wdata_d),
        .rdata_o  (mcause_rdata_q)
    );


    //----------------------------
    // Output logic.
    //----------------------------
    assign csr_mtvec_rdata_o = (mtvec_rdata_q >> 2) << 2; // To make sure it is 2-byte aligned.
    assign csr_mepc_rdata_o  = mepc_rdata_q;

    assign iqr_detected_o = mstatus_rdata_q[3] & ((mip_data[3] & mie_rdata_q[3]) | (mip_data[7] & mie_rdata_q[7]));
    assign trap_cause_o   = mip_data[3] ? {1'b1, 5'd3} : {1'b1, 5'd7}; // Software interrupt has higher priority than timer interrupt.


endmodule
