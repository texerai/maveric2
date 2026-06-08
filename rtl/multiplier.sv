/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------
// This is Multi-cycle RISC-V M-extension compliant multiplier.
// Supports MUL, MULH, MULHSU, MULHU, and MULW operations.
// -----------------------------------------------------------

module multiplier
#(
    parameter DATA_WIDTH = 64
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
    logic [DATA_WIDTH 	- 1:0]	multiplicand_s;
    logic [DATA_WIDTH   - 1:0]	multiplier_s;
    logic [2*DATA_WIDTH - 1:0]	accumulator_s;
    logic [MAX_CYCLES : 0 	 ]	cycle_counter_s;
    logic						busy_s;
    logic [1:0]					op_stored_s;
    logic                       a_sign_s;
    logic                       b_sign_s;

    logic [DATA_WIDTH 	- 1:0] a_unsigned_s;
    logic [DATA_WIDTH 	- 1:0] b_unsigned_s;

    // Negate if MULH/MULHSU and A is negative.
    assign a_unsigned_s = (op_i == 2'b01 || op_i == 2'b10) && a_i[DATA_WIDTH - 1] ? (~a_i + 1) : a_i;

    // Negate if MULH and B is negative.
    assign b_unsigned_s = (op_i == 2'b01) && b_i[DATA_WIDTH - 1] ? (~b_i + 1) : b_i;


    //-------------------------------------
    // Main sequential logic.
    //-------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin

        if (arst_i) begin

            multiplicand_s  <= '0;
            multiplier_s    <= '0;
            accumulator_s   <= '0;
            cycle_counter_s <= '0;
            busy_s          <= '0;
            op_stored_s     <= '0;
            a_sign_s        <= '0;
            b_sign_s        <= '0;

        end

        else if (start_i && !busy_s) begin

            multiplicand_s  <= a_unsigned_s;
            multiplier_s    <= b_unsigned_s;
            accumulator_s   <= '0;
            cycle_counter_s <= '0;
            a_sign_s        <= (op_i == 2'b01 || op_i == 2'b10) ? a_i[DATA_WIDTH - 1] : 1'b0;
            b_sign_s        <= (op_i == 2'b01) ? b_i[DATA_WIDTH - 1] : 1'b0;
            op_stored_s     <= op_i;
            busy_s          <= 1'b1;

        end

        else if (busy_s) begin

            if (multiplier_s[0])
                accumulator_s <= accumulator_s + (128'(multiplicand_s) << cycle_counter_s);

            multiplier_s    <= multiplier_s >> 1;
            cycle_counter_s <= cycle_counter_s + 1;

            if (cycle_counter_s == ($clog2(DATA_WIDTH) + 1)'(DATA_WIDTH - 1))
                busy_s <= 1'b0;

        end

    end


    //-------------------------------------
    // Result sign correction.
    //-------------------------------------
    logic                 		result_negative_s;
    logic [2*DATA_WIDTH - 1:0]  product_corrected_s;

    always_comb begin

        if (op_stored_s == 2'b01)
            result_negative_s = a_sign_s ^ b_sign_s;
        else if (op_stored_s == 2'b10)
            result_negative_s = a_sign_s;
        else
            result_negative_s = 1'b0;

        product_corrected_s = result_negative_s ? (~accumulator_s + 1) : accumulator_s;

    end


    //---------------------------------------
    // Continuous assignment of outputs.
    //---------------------------------------
    always_comb begin
        case (op_stored_s)
            2'b00: begin
                c_o = is_mdu_word_op_i
                    ? {{(DATA_WIDTH/2){product_corrected_s[DATA_WIDTH/2 - 1]}}, product_corrected_s[DATA_WIDTH/2 - 1:0]}
                    : product_corrected_s[DATA_WIDTH - 1:0];
            end
            2'b01:   c_o = product_corrected_s[2*DATA_WIDTH - 1:DATA_WIDTH];
            2'b10:   c_o = product_corrected_s[2*DATA_WIDTH - 1:DATA_WIDTH];
            2'b11:   c_o = product_corrected_s[2*DATA_WIDTH - 1:DATA_WIDTH];
            default: c_o = '0;
        endcase
    end

    assign done_o = ~busy_s;

endmodule
