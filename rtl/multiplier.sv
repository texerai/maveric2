/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------
// This is Multi-cycle RISC-V M-extension compliant multiplier.
// Supports MUL, MULH, MULHSU, MULHU, and MULW operations.
// -----------------------------------------------------------

`include "maveric_pkg.sv"

module multiplier
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN
)
// Port declaration
(
    // Clock & reset.
    input  logic              clk_i,
    input  logic              arst_i,

    // Control signals.
    input  logic              start_i,
    input  logic [1:0]        op_i,            // MUL=00, MULH=01, MULHSU=10, MULHU=11
    input  logic              is_mdu_word_op_i,

    // Data inputs.
    input  logic [DATA_WIDTH - 1:0] a_i,
    input  logic [DATA_WIDTH - 1:0] b_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] c_o,
    output logic              done_o
);

	localparam MAX_CYCLES = $clog2(DATA_WIDTH);

    //-------------------------
    // Internal nets.
    //-------------------------
    logic [DATA_WIDTH 	- 1:0]	multiplicand_q;
    logic [DATA_WIDTH   - 1:0]	multiplier_q;
    logic [2*DATA_WIDTH - 1:0]	accumulator_q;
    logic [MAX_CYCLES : 0 	 ]	cycle_counter_q;
    logic						busy_q;
    logic [1:0]					op_stored_q;
    logic                       a_sign_q;
    logic                       b_sign_q;

    logic [DATA_WIDTH 	- 1:0] a_unsigned;
    logic [DATA_WIDTH 	- 1:0] b_unsigned;

    // Negate if MULH/MULHSU and A is negative.
    assign a_unsigned = (op_i == 2'b01 || op_i == 2'b10) && a_i[DATA_WIDTH - 1] ? (~a_i + 1) : a_i;

    // Negate if MULH and B is negative.
    assign b_unsigned = (op_i == 2'b01) && b_i[DATA_WIDTH - 1] ? (~b_i + 1) : b_i;


    //-------------------------------------
    // Main sequential logic.
    //-------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin

        if (arst_i) begin

            multiplicand_q  <= '0;
            multiplier_q    <= '0;
            accumulator_q   <= '0;
            cycle_counter_q <= '0;
            busy_q          <= '0;
            op_stored_q     <= '0;
            a_sign_q        <= '0;
            b_sign_q        <= '0;

        end

        else if (start_i && !busy_q) begin

            multiplicand_q  <= a_unsigned;
            multiplier_q    <= b_unsigned;
            accumulator_q   <= '0;
            cycle_counter_q <= '0;
            a_sign_q        <= (op_i == 2'b01 || op_i == 2'b10) ? a_i[DATA_WIDTH - 1] : 1'b0;
            b_sign_q        <= (op_i == 2'b01) ? b_i[DATA_WIDTH - 1] : 1'b0;
            op_stored_q     <= op_i;
            busy_q          <= 1'b1;

        end

        else if (busy_q) begin

            if (multiplier_q[0])
                accumulator_q <= accumulator_q + (128'(multiplicand_q) << cycle_counter_q);

            multiplier_q    <= multiplier_q >> 1;
            cycle_counter_q <= cycle_counter_q + 1;

            if (cycle_counter_q == ($clog2(DATA_WIDTH) + 1)'(DATA_WIDTH - 1))
                busy_q <= 1'b0;

        end

    end


    //-------------------------------------
    // Result sign correction.
    //-------------------------------------
    logic                 		result_negative;
    logic [2*DATA_WIDTH - 1:0]  product_corrected;

    always_comb begin

        if (op_stored_q == 2'b01)
            result_negative = a_sign_q ^ b_sign_q;
        else if (op_stored_q == 2'b10)
            result_negative = a_sign_q;
        else
            result_negative = 1'b0;

        product_corrected = result_negative ? (~accumulator_q + 1) : accumulator_q;

    end


    //---------------------------------------
    // Continuous assignment of outputs.
    //---------------------------------------
    always_comb begin
        case (op_stored_q)
            2'b00: begin
                c_o = is_mdu_word_op_i
                    ? {{(DATA_WIDTH/2){product_corrected[DATA_WIDTH/2 - 1]}}, product_corrected[DATA_WIDTH/2 - 1:0]}
                    : product_corrected[DATA_WIDTH - 1:0];
            end
            2'b01:   c_o = product_corrected[2*DATA_WIDTH - 1:DATA_WIDTH];
            2'b10:   c_o = product_corrected[2*DATA_WIDTH - 1:DATA_WIDTH];
            2'b11:   c_o = product_corrected[2*DATA_WIDTH - 1:DATA_WIDTH];
            default: c_o = '0;
        endcase
    end

    assign done_o = ~busy_q;

endmodule
