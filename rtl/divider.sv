// Multi-cycle RISC-V M-extension compliant divider
// Supports RV32M and RV64M division operations
// Implements DIV, DIVU, REM, REMU with parameterizable width

module divider #(
    parameter XLEN = 64  // 32 or 64 for RV32 or RV64
) (
    input  logic              clk,
    input  logic              rst,
    input  logic              start,
    input  logic [1:0]        op,       // DIV=00, DIVU=01, REM=10, REMU=11
    input  logic              is_mdu_word_op,
    input  logic [XLEN-1:0]   A,        // Dividend
    input  logic [XLEN-1:0]   B,        // Divisor
    output logic [XLEN-1:0]   C,        // Quotient or Remainder
    output logic              done
);

    localparam MAX_CYCLES = XLEN + 1;

    // Internal registers

    // computation registers
    logic [2*XLEN-1:0]          remainder;
    logic [XLEN-1:0]            quotient;
    logic [$clog2(XLEN)-1:0]    cycle_counter;

    // control registers
    logic                       busy;
    logic [1:0]                 op_stored;

    // sign registers (captured at start, used at the end)
    logic                       dividend_negative_stored;
    logic                       divisor_negative_stored;
    logic                       quotient_negative_stored;

    // special case registers
    logic                       special_case_stored;
    logic [XLEN-1:0]            special_result_stored;

    // Combinational signals from live inputs — only sampled at start
    logic                       start_dividend_negative;
    logic                       start_divisor_negative;
    logic [XLEN-1:0]            start_dividend_unsigned;

     // Is dividend A negative for a signed op?
    assign start_dividend_negative  = (op == 2'b00 || op == 2'b10)
                                        ? (is_mdu_word_op ? A[XLEN/2-1] : A[XLEN-1])
                                        : 1'b0;

    // Is divisor B negative for a signed op?
    assign start_divisor_negative   = (op == 2'b00 || op == 2'b10)
                                        ? (is_mdu_word_op ? B[XLEN/2-1] : B[XLEN-1])
                                        : 1'b0;

    assign start_dividend_unsigned  = start_dividend_negative
                                        ? (is_mdu_word_op ? {{(XLEN/2){1'b0}}, (~A[XLEN/2-1:0] + 1)}
                                                          : (~A + 1))
                                        : (is_mdu_word_op ? {{(XLEN/2){1'b0}},   A[XLEN/2-1:0]}
                                                          : A);

    // Divisor unsigned: derived from stored registers — stable during computation
    logic [XLEN-1:0] divisor_unsigned;
    assign divisor_unsigned = divisor_negative_stored
                                ? (is_mdu_word_op ? {{(XLEN/2){1'b0}}, (~B[XLEN/2-1:0] + 1)}
                                                  : (~B + 1))
                                : (is_mdu_word_op ? {{(XLEN/2){1'b0}},   B[XLEN/2-1:0]}
                                                  : B);

    // Iteration combinational logic — avoids blocking assignments inside always_ff
    logic [2*XLEN-1:0] remainder_shifted;
    logic [2*XLEN:0] temp;  // 129-bit: bit [2*XLEN] is the true borrow/underflow flag

    // remainder_shifted is the shifted state before the test, and temp is the outcome of the test.
    // Every iteration the hardware computes both simultaneously (combinationally), then the always_ff block picks
    // which one to keep based on temp[2*XLEN] (the borrow bit).
    // Using 129 bits ensures the borrow is captured correctly even when divisor_unsigned >= 2^(XLEN-1).

    assign remainder_shifted = remainder << 1;
    assign temp = {1'b0, remainder_shifted} - {1'b0, divisor_unsigned, {XLEN{1'b0}}};

    // Main sequential logic
    always_ff @(posedge clk) begin

        if (rst) begin

            remainder                <= '0;
            quotient                 <= '0;
            cycle_counter            <= '0;
            busy                     <= '0;
            op_stored                <= '0;
            dividend_negative_stored <= '0;
            divisor_negative_stored  <= '0;
            quotient_negative_stored <= '0;
            special_case_stored      <= '0;
            special_result_stored    <= '0;
			
        end

        else if (start && !busy) begin

            op_stored <= op;

            if (is_mdu_word_op ? (B[XLEN/2-1:0] == '0) : (B == '0)) begin // division by zero

                // RISC-V spec: DIV by 0 returns -1, REM by 0 returns dividend
                special_case_stored <= 1'b1;

                case (op)

                    2'b00:   special_result_stored <= {XLEN{1'b1}};
                    2'b01:   special_result_stored <= {XLEN{1'b1}};
                    2'b10:   special_result_stored <= A;
                    2'b11:   special_result_stored <= A;
                    default: special_result_stored <= '0;

                endcase

            end

            else if (A == B) begin // dividend == divisor

                // Quotient = 1, Remainder = 0

                special_case_stored <= 1'b1;

                case (op)

                    2'b00:   special_result_stored <= {{(XLEN-1){1'b0}}, 1'b1};
                    2'b01:   special_result_stored <= {{(XLEN-1){1'b0}}, 1'b1};
                    2'b10:   special_result_stored <= '0;
                    2'b11:   special_result_stored <= '0;
                    default: special_result_stored <= '0;

                endcase

            end

            else if ((op == 2'b00) && (
                is_mdu_word_op
                ? (A[XLEN/2-1:0] == {1'b1, {(XLEN/2-1){1'b0}}} && B[XLEN/2-1:0] == {(XLEN/2){1'b1}})
                : (A             == {1'b1, {(XLEN-1)  {1'b0}}} && B             == {XLEN{1'b1}})
            )) begin // signed overflow

                // Signed overflow: INT_MIN / -1 — RISC-V spec: quotient=INT_MIN, remainder=0
                special_case_stored <= 1'b1;
				
                case (op)

                    2'b00:   special_result_stored <= A;   // DIV: INT_MIN
                    2'b10:   special_result_stored <= '0;  // REM: 0
                    default: special_result_stored <= '0;

                endcase

            end

            else begin // normal division

                // Normal division
                special_case_stored      <= 1'b0;
                remainder                <= {{XLEN{1'b0}}, start_dividend_unsigned};
                quotient                 <= '0;
                cycle_counter            <= '0;
                dividend_negative_stored <= start_dividend_negative;
                divisor_negative_stored  <= start_divisor_negative;
                quotient_negative_stored <= start_dividend_negative ^ start_divisor_negative;
                busy                     <= 1'b1;

            end

        end

        else if (busy) begin

            if (temp[2*XLEN]) begin // borrow == 1: divisor doesn't fit → restore

                remainder <= remainder_shifted;
                quotient  <= quotient << 1;

            end

            else begin // borrow == 0: divisor fits → keep

                remainder <= temp[2*XLEN-1:0];
                quotient  <= {quotient[XLEN-2:0], 1'b1};

            end

            cycle_counter <= cycle_counter + 1;

            if (cycle_counter == ($clog2(XLEN))'(MAX_CYCLES - 2))
                busy <= 1'b0;

        end

    end

    // Result computation
    logic [XLEN-1:0] quotient_result;
    logic [XLEN-1:0] remainder_result;

    always_comb begin

        remainder_result = remainder[2*XLEN-1:XLEN];

        if (op_stored == 2'b10 && dividend_negative_stored && remainder_result != 0) // If instr is rem, A is negative, and remainder != 0
            remainder_result = ~remainder_result + 1;

        if (op_stored == 2'b00 && quotient_negative_stored && quotient != 0) // If instr is div, quotient is negative, and quotient != 0
            quotient_result = ~quotient + 1;

        else
            quotient_result = quotient;

    end

    // Output assignment
    always_comb begin

        if (special_case_stored) begin

            C = is_mdu_word_op
                ? {{(XLEN/2){special_result_stored[XLEN/2-1]}}, special_result_stored[XLEN/2-1:0]}
                : special_result_stored;

        end
		
		else begin

            case (op_stored)

                2'b00, 2'b01: begin
                    
                    C = is_mdu_word_op
                        ? {{(XLEN/2){quotient_result[XLEN/2-1]}},  quotient_result[XLEN/2-1:0]}
                        : quotient_result;

                end

                2'b10, 2'b11: begin

                    C = is_mdu_word_op
                        ? {{(XLEN/2){remainder_result[XLEN/2-1]}}, remainder_result[XLEN/2-1:0]}
                        : remainder_result;
                    
                end

                default: C = '0;

            endcase

        end

    end

    assign done = ~busy;

endmodule
