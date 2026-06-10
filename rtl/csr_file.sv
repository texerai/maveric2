/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 09/06/2026
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
    parameter CSR_DATA_WIDTH = 64,
    parameter CSR_ADDR_WIDTH = 12,
    parameter RESET_VAL      = '0
)
// Port decleration.
(
    // Common clock & reset signals.
    input  logic                       clk_i,
    input  logic                       arst_i,

    //Input interface.
    input  logic                        write_en_0_i,
    input  logic [CSR_DATA_WIDTH - 1:0] write_data_0_i,
    input  logic [CSR_ADDR_WIDTH - 1:0] read_addr_0_i,
    input  logic [CSR_ADDR_WIDTH - 1:0] write_addr_0_i,

    // Output interface.
    output logic [CSR_DATA_WIDTH - 1:0] read_data_0_o
);
    //----------------------------
    // Local parameters.
    //----------------------------

    localparam MCAUSE_WIDTH = 6;

    // Interrupt codes.
    localparam logic [MCAUSE_WIDTH - 1:0] S_INT_SW    = {1'b1, 5'd1};
    localparam logic [MCAUSE_WIDTH - 1:0] M_INT_SW    = {1'b1, 5'd3};
    localparam logic [MCAUSE_WIDTH - 1:0] S_INT_TIMER = {1'b1, 5'd5};
    localparam logic [MCAUSE_WIDTH - 1:0] M_INT_TIMER = {1'b1, 5'd7};
    localparam logic [MCAUSE_WIDTH - 1:0] S_INT_EXT   = {1'b1, 5'd9};
    localparam logic [MCAUSE_WIDTH - 1:0] M_INT_EXT   = {1'b1, 5'd11};

    // Exception codes.
    localparam logic [MCAUSE_WIDTH - 1:0] X_INSTR_ADDR_MA      = 6'd0;
    localparam logic [MCAUSE_WIDTH - 1:0] X_INSTR_ACCESS_FAULT = 6'd1;
    localparam logic [MCAUSE_WIDTH - 1:0] X_ILLEGAL_INSTR      = 6'd2;
    localparam logic [MCAUSE_WIDTH - 1:0] X_BREAKPOINT         = 6'd3;
    localparam logic [MCAUSE_WIDTH - 1:0] X_LOAD_ADDR_MA       = 6'd4;
    localparam logic [MCAUSE_WIDTH - 1:0] X_LOAD_ACCESS_FAULT  = 6'd5;
    localparam logic [MCAUSE_WIDTH - 1:0] X_STORE_ADDR_MA      = 6'd6;
    localparam logic [MCAUSE_WIDTH - 1:0] X_STORE_ACCESS_FAULT = 6'd7;
    localparam logic [MCAUSE_WIDTH - 1:0] U_ENV_CALL           = 6'd8;
    localparam logic [MCAUSE_WIDTH - 1:0] S_ENV_CALL           = 6'd9;
    localparam logic [MCAUSE_WIDTH - 1:0] M_ENV_CALL           = 6'd11;
    localparam logic [MCAUSE_WIDTH - 1:0] X_INSTR_PAGE_FAULT   = 6'd12;
    localparam logic [MCAUSE_WIDTH - 1:0] X_LOAD_PAGE_FAULT    = 6'd13;
    localparam logic [MCAUSE_WIDTH - 1:0] X_STORE_PAGE_FAULT   = 6'd15;
    localparam logic [MCAUSE_WIDTH - 1:0] X_DOUBLE_TRAP        = 6'd16;
    localparam logic [MCAUSE_WIDTH - 1:0] X_SW_CHECK           = 6'd18;
    localparam logic [MCAUSE_WIDTH - 1:0] X_HW_ERROR           = 6'd19;


    // M-mode CSR addresses.
    localparam logic [CSR_ADDR_WIDTH - 1:0] MTVEC_CSR_ADDR     = 12'h304;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MEPC_CSR_ADDR      = 12'h341;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MCAUSE_CSR_ADDR    = 12'h342;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MVENDORID_CSR_ADDR = 12'hF11;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MARCHID_CSR_ADDR   = 12'hF12;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MIMPID_CSR_ADDR    = 12'hF13;
    localparam logic [CSR_ADDR_WIDTH - 1:0] MHARTID_CSR_ADDR   = 12'hF14;


    //----------------------------
    // Internal nets.
    //----------------------------
    logic mtvec_we;
    logic mepc_we;
    logic mcause_we;

    logic [CSR_DATA_WIDTH   - 1:0] mtvec_write_data_d;
    logic [CSR_DATA_WIDTH   - 1:0] mepc_write_data_d;
    logic [MCAUSE_WIDTH     - 1:0] mcause_write_data_d;

    logic [CSR_DATA_WIDTH   - 1:0] mtvec_read_data_q;
    logic [CSR_DATA_WIDTH   - 1:0] mepc_read_data_q;
    logic [MCAUSE_WIDTH     - 1:0] mcause_read_data_q;

    logic mcause_legal;


    //----------------------------
    // Determine legal mcause.
    //----------------------------

    always_comb begin
        mcause_legal = 1'b0;

        case ({write_data_0_i[CSR_DATA_WIDTH - 1], write_data_0_i[MCAUSE_WIDTH - 2:0]})
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
        mtvec_we  = 1'b0;
        mepc_we   = 1'b0;
        mcause_we = 1'b0;

        mtvec_write_data_d  = '0;
        mepc_write_data_d   = '0;
        mcause_write_data_d = '0;

        case (write_addr_0_i)
            MTVEC_CSR_ADDR: begin
                mtvec_we           = write_en_0_i;
                mtvec_write_data_d = {write_data_0_i[CSR_DATA_WIDTH - 1:2], 1'b0, write_data_0_i[0]};
            end
            MEPC_CSR_ADDR: begin
                mepc_we           = write_en_0_i;
                mepc_write_data_d = {write_data_0_i[CSR_DATA_WIDTH - 1:2], 2'b0}; // Currently IALIGN = 32.
            end
            MCAUSE_CSR_ADDR: begin
                mcause_we           = write_en_0_i && mcause_legal;
                mcause_write_data_d = {write_data_0_i[CSR_DATA_WIDTH - 1], write_data_0_i[MCAUSE_WIDTH - 2:0]};
            end
            default: begin
                mtvec_we  = 1'b0;
                mepc_we   = 1'b0;
                mcause_we = 1'b0;

                mtvec_write_data_d  = '0;
                mepc_write_data_d   = '0;
                mcause_write_data_d = '0;
            end
        endcase
    end

    //----------------------------
    // Read logic decode.
    //----------------------------

    // Read 0.
    always_comb begin
        // Default values.
        read_data_0_o = '0;

        case (read_addr_0_i)
            MTVEC_CSR_ADDR : read_data_0_o = mtvec_read_data_q;
            MEPC_CSR_ADDR  : read_data_0_o = mepc_read_data_q;
            MCAUSE_CSR_ADDR: read_data_0_o = {mcause_read_data_q[MCAUSE_WIDTH - 1], 58'b0, mcause_read_data_q[MCAUSE_WIDTH - 2:0]};
            default: begin
                read_data_0_o = '0;
            end
        endcase
    end


    //----------------------------
    // Lower-level modulues:
    // CS registers.
    //----------------------------

    // mtvec.
    register_en # (
        .DATA_WIDTH (CSR_DATA_WIDTH),
        .RESET_VAL  (RESET_VAL     )
    ) MTVEC_CSR0 (
        .clk_i        (clk_i             ),
        .arst_i       (arst_i            ),
        .write_en_i   (mtvec_we          ),
        .write_data_i (mtvec_write_data_d),
        .read_data_o  (mtvec_read_data_q )
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (CSR_DATA_WIDTH),
        .RESET_VAL  (RESET_VAL     )
    ) MEPC_CSR0 (
        .clk_i        (clk_i            ),
        .arst_i       (arst_i           ),
        .write_en_i   (mepc_we          ),
        .write_data_i (mepc_write_data_d),
        .read_data_o  (mepc_read_data_q )
    );

    // mcause.
    register_en # (
        .DATA_WIDTH (MCAUSE_WIDTH),
        .RESET_VAL  (RESET_VAL   )
    ) MCAUSE_CSR0 (
        .clk_i        (clk_i              ),
        .arst_i       (arst_i             ),
        .write_en_i   (mcause_we          ),
        .write_data_i (mcause_write_data_d),
        .read_data_o  (mcause_read_data_q )
    );

endmodule
