// Multi-cycle RISC-V M-extension compliant multiplier
// Supports RV32M and RV64M multiplication operations
// Accepts two parameterizable inputs (A and B) and generates result based on operation

/*

Operations:
- MUL:    C = A * B (lower XLEN bits)
- MULH:   C = (A * B) >> XLEN (upper XLEN bits, signed)
- MULHSU: C = (A * B) >> XLEN (upper XLEN bits, signed A and unsigned B)
- MULHU:  C = (A * B) >> XLEN (upper XLEN bits, unsigned)
- MULW:	  C = (A * B) >> XLEN (lower XLEN/2 bits, signed)
*/

module multiplier #(
	parameter XLEN = 64
) (
	input  logic              clk,
	input  logic              rst,
	input  logic              start,
	input  logic [1:0]        op,       // MUL=00, MULH=01, MULHSU=10, MULHU=11
	input  logic			  is_mdu_word_op,
	input  logic [XLEN-1:0]   A,
	input  logic [XLEN-1:0]   B,
	output logic [XLEN-1:0]   C,
	output logic              done
);

	// Internal registers

	logic [XLEN-1:0]           multiplicand;
	logic [XLEN-1:0]           multiplier;
	// multiplicand and multiplier hold the operand values used by the shift-add loop

	logic [2*XLEN-1:0]         accumulator;
	// 2*XLEN bits to hold the full product

	logic [$clog2(XLEN)+1-1:0] cycle_counter;
	// counts cycles from 0 to XLEN-1

	logic                       busy;
	// indicates an active multiply in progress

	logic [1:0]                op_stored;
	// holds the operation code after start

	logic                       a_sign;  // Sign of A
	logic                       b_sign;  // Sign of B
	// a_sign and b_sign are preserved sign bits for signed calculations

	// Constants
	localparam MAX_CYCLES = XLEN;

	// Handle signed vs unsigned based on operation
	// op[1:0]: 00=MUL, 01=MULH, 10=MULHSU, 11=MULHU
	logic [XLEN-1:0] a_unsigned;
	logic [XLEN-1:0] b_unsigned;

	assign a_unsigned = (op == 2'b01 || op == 2'b10) && A[XLEN-1] ? (~A + 1) : A;
	// if mulh or mulhsu and A is negative, take two's complement to get unsigned magnitude

	assign b_unsigned = (op == 2'b01) && B[XLEN-1] ? (~B + 1) : B;
	// if mulh and B is negative, take two's complement to get unsigned magnitude

	// multiplication is always done on unsigned values,
	// with sign correction applied at the end for signed operations

	// Main multiplication logic
	always_ff @(posedge clk) begin

		if (rst) begin

			multiplicand  <= {XLEN{1'b0}};
			multiplier    <= {XLEN{1'b0}};
			accumulator   <= {2*XLEN{1'b0}};
			cycle_counter <= {$clog2(XLEN)+1{1'b0}};
			busy          <= 1'b0;
			op_stored     <= 2'b0;

		end

		else if (start && !busy) begin

			// Start new multiplication
			multiplicand  <= a_unsigned;
			multiplier    <= b_unsigned;
			accumulator   <= {2*XLEN{1'b0}};
			cycle_counter <= {$clog2(XLEN)+1{1'b0}};
			a_sign        <= (op == 2'b01 || op == 2'b10) ? A[XLEN-1] : 1'b0;
			b_sign        <= (op == 2'b01) ? B[XLEN-1] : 1'b0;
			op_stored     <= op;
			busy          <= 1'b1;

		end

		else if (busy) begin

			// Process one bit of multiplier per cycle (unsigned)
			// Add multiplicand shifted to the correct position based on bit index

			if (multiplier[0]) begin
				accumulator <= accumulator + (multiplicand << cycle_counter);
			end

			multiplier    <= multiplier >> 1;
			cycle_counter <= cycle_counter + 1;

			// Check if multiplication is complete (after XLEN iterations)
			if (cycle_counter == ($clog2(XLEN)+1)'(MAX_CYCLES - 1)) begin
				busy <= 1'b0;
			end

		end

	end

	// Adjust result for signed multiplication
	// Determine if result should be negative
	logic result_negative;
	logic [2*XLEN-1:0] product_corrected;

	always_comb begin

		// Result is negative if signs differ for MULH, or if A is negative for MULHSU

		if (op_stored == 2'b01) begin
			result_negative = a_sign ^ b_sign;  // MULH: negate if signs differ
		end

		else if (op_stored == 2'b10) begin
			result_negative = a_sign;  // MULHSU: negate if A is negative (B is unsigned)
		end

		else begin
			result_negative = 1'b0;  // MUL and MULHU: never negate
		end

		// Negate using two's complement if needed
		if (result_negative) begin
			product_corrected = ~accumulator + 1;
		end

		else begin
			product_corrected = accumulator;
		end

	end

	// Output assignment based on operation
	always_comb begin
		case (op_stored)

			2'b00:   begin

				if (is_mdu_word_op)     C = {{(XLEN/2){product_corrected[XLEN/2-1]}}, product_corrected[XLEN/2-1:0]};
				// MULW: take lower XLEN/2 bits and sign-extend to XLEN bits
				
				else                    C = product_corrected[XLEN-1:0];      // MUL: lower XLEN bits

			end
			
			2'b01:   					C = product_corrected[2*XLEN-1:XLEN]; // MULH: upper XLEN bits
			2'b10:   					C = product_corrected[2*XLEN-1:XLEN]; // MULHSU: upper XLEN bits
			2'b11:   					C = product_corrected[2*XLEN-1:XLEN]; // MULHU: upper XLEN bits
			default: 					C = {XLEN{1'b0}};

		endcase
	end

	assign done = ~busy;

	endmodule
