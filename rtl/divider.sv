/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------
// Multi-cycle RISC-V M-extension compliant divider.
// Supports DIV, DIVU, REM, REMU, and their W-type variants.
// Uses restoring binary division with a 129-bit borrow flag.
// ------------------------------------------------------------------

module divider
// Parameters.
#(
    parameter XLEN = 64
)
// Port decleration.
(
    // Clock & reset.
    input  logic              clk_i,
    input  logic              rst_i,

    // Control signals.
    input  logic              start_i,
    input  logic [1:0]        op_i,            // DIV=00, DIVU=01, REM=10, REMU=11
    input  logic              is_mdu_word_op_i,

    // Data inputs.
    input  logic [XLEN - 1:0] a_i,             // Dividend.
    input  logic [XLEN - 1:0] b_i,             // Divisor.

    // Output interface.
    output logic [XLEN - 1:0] c_o,             // Quotient or Remainder.
    output logic              done_o
);

    localparam MAX_CYCLES = XLEN + 1;

    //-------------------------
    // Internal nets.
    //-------------------------

    // Computation registers.
    logic [2*XLEN - 1:0]        remainder_s;
    logic [XLEN - 1:0]          quotient_s;
    logic [$clog2(XLEN) - 1:0]  cycle_counter_s;

    // Control registers.
    logic                        busy_s;
    logic [1:0]                  op_stored_s;

    // Sign registers (captured at start, used at end).
    logic                        dividend_negative_s;
    logic                        divisor_negative_s;
    logic                        quotient_negative_s;

    // Special-case registers.
    logic                        special_case_s;
    logic [XLEN - 1:0]           special_result_s;

    // Combinational: sign and unsigned magnitude of operands.
    logic                        start_dividend_negative_s;
    logic                        start_divisor_negative_s;
    logic [XLEN - 1:0]           start_dividend_unsigned_s;
    logic [XLEN - 1:0]           divisor_unsigned_s;

    // Is dividend A negative (signed op only)?
    assign start_dividend_negative_s = (op_i == 2'b00 || op_i == 2'b10)
                                       ? (is_mdu_word_op_i ? a_i[XLEN/2 - 1] : a_i[XLEN - 1])
                                       : 1'b0;

    // Is divisor B negative (signed op only)?
    assign start_divisor_negative_s  = (op_i == 2'b00 || op_i == 2'b10)
                                       ? (is_mdu_word_op_i ? b_i[XLEN/2 - 1] : b_i[XLEN - 1])
                                       : 1'b0;

    assign start_dividend_unsigned_s = start_dividend_negative_s
                                       ? (is_mdu_word_op_i ? {{(XLEN/2){1'b0}}, (~a_i[XLEN/2 - 1:0] + 1)}
                                                           :                     (~a_i + 1))
                                       : (is_mdu_word_op_i ? {{(XLEN/2){1'b0}},   a_i[XLEN/2 - 1:0]}
                                                           :                        a_i);

    // Divisor unsigned: derived from stored sign — stable during computation.
    assign divisor_unsigned_s        = divisor_negative_s
                                       ? (is_mdu_word_op_i ? {{(XLEN/2){1'b0}}, (~b_i[XLEN/2 - 1:0] + 1)}
                                                           :                     (~b_i + 1))
                                       : (is_mdu_word_op_i ? {{(XLEN/2){1'b0}},   b_i[XLEN/2 - 1:0]}
                                                           :                        b_i);

    // Iteration combinational logic.
    // temp is 129-bit: bit [2*XLEN] is the true borrow flag, correct even when
    // divisor_unsigned_s >= 2^(XLEN-1) (where a 128-bit MSB check would fail).
    logic [2*XLEN - 1:0] remainder_shifted_s;
    logic [2*XLEN:0]      temp_s;

    assign remainder_shifted_s = remainder_s << 1;
    assign temp_s              = {1'b0, remainder_shifted_s} - {1'b0, divisor_unsigned_s, {XLEN{1'b0}}};


    //-------------------------------------
    // Main sequential logic.
    //-------------------------------------
    always_ff @(posedge clk_i) begin

        if (rst_i) begin

            remainder_s          <= '0;
            quotient_s           <= '0;
            cycle_counter_s      <= '0;
            busy_s               <= '0;
            op_stored_s          <= '0;
            dividend_negative_s  <= '0;
            divisor_negative_s   <= '0;
            quotient_negative_s  <= '0;
            special_case_s       <= '0;
            special_result_s     <= '0;

        end

        else if (start_i && !busy_s) begin

            op_stored_s <= op_i;

            if (is_mdu_word_op_i ? (b_i[XLEN/2 - 1:0] == '0) : (b_i == '0)) begin

                // RISC-V spec: DIV/DIVU by 0 → all-ones; REM/REMU by 0 → dividend.
                special_case_s <= 1'b1;

                case (op_i)
                    2'b00:   special_result_s <= {XLEN{1'b1}};
                    2'b01:   special_result_s <= {XLEN{1'b1}};
                    2'b10:   special_result_s <= a_i;
                    2'b11:   special_result_s <= a_i;
                    default: special_result_s <= '0;
                endcase

            end

            else if (a_i == b_i) begin

                // Quotient = 1, Remainder = 0.
                special_case_s <= 1'b1;

                case (op_i)
                    2'b00:   special_result_s <= {{(XLEN - 1){1'b0}}, 1'b1};
                    2'b01:   special_result_s <= {{(XLEN - 1){1'b0}}, 1'b1};
                    2'b10:   special_result_s <= '0;
                    2'b11:   special_result_s <= '0;
                    default: special_result_s <= '0;
                endcase

            end

            else if ((op_i == 2'b00) && (
                is_mdu_word_op_i
                ? (a_i[XLEN/2 - 1:0] == {1'b1, {(XLEN/2 - 1){1'b0}}} && b_i[XLEN/2 - 1:0] == {(XLEN/2){1'b1}})
                : (a_i               == {1'b1, {(XLEN   - 1){1'b0}}} && b_i               == {XLEN{1'b1}})
            )) begin

                // Signed overflow: INT_MIN / -1 → quotient = INT_MIN, remainder = 0.
                special_case_s <= 1'b1;

                case (op_i)
                    2'b00:   special_result_s <= a_i;
                    2'b10:   special_result_s <= '0;
                    default: special_result_s <= '0;
                endcase

            end

            else begin

                special_case_s       <= 1'b0;
                remainder_s          <= {{XLEN{1'b0}}, start_dividend_unsigned_s};
                quotient_s           <= '0;
                cycle_counter_s      <= '0;
                dividend_negative_s  <= start_dividend_negative_s;
                divisor_negative_s   <= start_divisor_negative_s;
                quotient_negative_s  <= start_dividend_negative_s ^ start_divisor_negative_s;
                busy_s               <= 1'b1;

            end

        end

        else if (busy_s) begin

            if (temp_s[2*XLEN]) begin

                // Borrow set: divisor doesn't fit — restore.
                remainder_s <= remainder_shifted_s;
                quotient_s  <= quotient_s << 1;

            end

            else begin

                // No borrow: divisor fits — keep.
                remainder_s <= temp_s[2*XLEN - 1:0];
                quotient_s  <= {quotient_s[XLEN - 2:0], 1'b1};

            end

            cycle_counter_s <= cycle_counter_s + 1;

            if (cycle_counter_s == ($clog2(XLEN))'(MAX_CYCLES - 2))
                busy_s <= 1'b0;

        end

    end


    //-------------------------------------
    // Result computation.
    //-------------------------------------
    logic [XLEN - 1:0] quotient_result_s;
    logic [XLEN - 1:0] remainder_result_s;

    always_comb begin

        remainder_result_s = remainder_s[2*XLEN - 1:XLEN];

        // Negate remainder if signed REM with negative dividend and non-zero result.
        if (op_stored_s == 2'b10 && dividend_negative_s && remainder_result_s != 0)
            remainder_result_s = ~remainder_result_s + 1;

        // Negate quotient if signed DIV with differing signs and non-zero quotient.
        if (op_stored_s == 2'b00 && quotient_negative_s && quotient_s != 0)
            quotient_result_s = ~quotient_s + 1;
        else
            quotient_result_s = quotient_s;

    end


    //---------------------------------------
    // Continuous assignment of outputs.
    //---------------------------------------
    always_comb begin

        if (special_case_s) begin

            c_o = is_mdu_word_op_i
                ? {{(XLEN/2){special_result_s[XLEN/2 - 1]}}, special_result_s[XLEN/2 - 1:0]}
                : special_result_s;

        end

        else begin

            case (op_stored_s)

                2'b00, 2'b01: begin
                    c_o = is_mdu_word_op_i
                        ? {{(XLEN/2){quotient_result_s[XLEN/2 - 1]}},  quotient_result_s[XLEN/2 - 1:0]}
                        : quotient_result_s;
                end

                2'b10, 2'b11: begin
                    c_o = is_mdu_word_op_i
                        ? {{(XLEN/2){remainder_result_s[XLEN/2 - 1]}}, remainder_result_s[XLEN/2 - 1:0]}
                        : remainder_result_s;
                end

                default: c_o = '0;

            endcase

        end

    end

    assign done_o = ~busy_s;

endmodule
