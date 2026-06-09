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
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 12,
    parameter RESET_VAL = '0
)
// Port decleration.
(
    // Common clock & reset signals.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic                    write_en_0_i,
    input  logic [DATA_WIDTH - 1:0] write_data_0_i,
    input  logic [ADDR_WIDTH - 1:0] read_addr_0_i,
    input  logic [ADDR_WIDTH - 1:0] write_addr_0_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] read_data_0_o
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


    //----------------------------
    // Internal nets.
    //----------------------------
    logic mtvec_we_s;
    logic mepc_we_s;
    logic mcause_we_s;

    logic [DATA_WIDTH   - 1:0] mtvec_write_data_s;
    logic [DATA_WIDTH   - 1:0] mepc_write_data_s;
    logic [MCAUSE_WIDTH - 1:0] mcause_write_data_s;

    logic [DATA_WIDTH   - 1:0] mtvec_read_data_s;
    logic [DATA_WIDTH   - 1:0] mepc_read_data_s;
    logic [MCAUSE_WIDTH - 1:0] mcause_read_data_s;

    logic mcause_legal_s;


    //----------------------------
    // Determine legal mcause.
    //----------------------------

    always_comb begin
        mcause_legal_s = 1'b0;

        case ({write_data_0_i[DATA_WIDTH - 1], write_data_0_i[MCAUSE_WIDTH - 2:0]})
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
                mcause_legal_s = 1'b1;
            end
            default: begin
                mcause_legal_s = 1'b0;
            end
        endcase
    end


    //----------------------------
    // Write logic decode.
    //----------------------------

    // Write 0.
    always_comb begin
        // Default values.
        mtvec_we_s  = 1'b0;
        mepc_we_s   = 1'b0;
        mcause_we_s = 1'b0;

        mtvec_write_data_s  = '0;
        mepc_write_data_s   = '0;
        mcause_write_data_s = '0;

        case (write_addr_0_i)
            12'h304: begin
                mtvec_we_s         = write_en_0_i;
                mtvec_write_data_s = {write_data_0_i[DATA_WIDTH - 1:2], 1'b0, write_data_0_i[0]};
            end
            12'h341: begin
                mepc_we_s         = write_en_0_i;
                mepc_write_data_s = {write_data_0_i[DATA_WIDTH - 1:2], 2'b0}; // Currently IALIGN = 32.
            end
            12'h342: begin
                mcause_we_s         = write_en_0_i && mcause_legal_s;
                mcause_write_data_s = {write_data_0_i[DATA_WIDTH - 1], write_data_0_i[MCAUSE_WIDTH - 2:0]};
            end
            default: begin
                mtvec_we_s  = 1'b0;
                mepc_we_s   = 1'b0;
                mcause_we_s = 1'b0;

                mtvec_write_data_s  = '0;
                mepc_write_data_s   = '0;
                mcause_write_data_s = '0;
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
            12'h304: read_data_0_o = mtvec_read_data_s;
            12'h341: read_data_0_o = mepc_read_data_s;
            12'h342: read_data_0_o = {mcause_read_data_s[MCAUSE_WIDTH - 1], 58'b0, mcause_read_data_s[MCAUSE_WIDTH - 2:0]};
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
        .DATA_WIDTH (DATA_WIDTH),
        .RESET_VAL  (RESET_VAL )
    ) MTVEC_CSR0 (
        .clk_i        (clk_i             ),
        .arst_i       (arst_i            ),
        .write_en_i   (mtvec_we_s        ),
        .write_data_i (mtvec_write_data_s),
        .read_data_o  (mtvec_read_data_s )
    );

    // mepc.
    register_en # (
        .DATA_WIDTH (DATA_WIDTH),
        .RESET_VAL  (RESET_VAL )
    ) MEPC_CSR0 (
        .clk_i        (clk_i            ),
        .arst_i       (arst_i           ),
        .write_en_i   (mepc_we_s        ),
        .write_data_i (mepc_write_data_s),
        .read_data_o  (mepc_read_data_s )
    );

    // mcause.
    register_en # (
        .DATA_WIDTH (MCAUSE_WIDTH),
        .RESET_VAL  (RESET_VAL   )
    ) MCAUSE_CSR0 (
        .clk_i        (clk_i              ),
        .arst_i       (arst_i             ),
        .write_en_i   (mcause_we_s        ),
        .write_data_i (mcause_write_data_s),
        .read_data_o  (mcause_read_data_s )
    );

endmodule
