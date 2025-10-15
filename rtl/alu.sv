/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------
// This is a Arithmetic Logic Unit (ALU).
// Copied from season 1.
// --------------------------------------

module alu
// Parameters.
#(
    parameter DATA_WIDTH    = 64,
    parameter WORD_WIDTH    = 32,
    parameter CONTROL_WIDTH = 5
)
// Port decleration.
(
    // ALU control signal.
    input  logic [CONTROL_WIDTH - 1:0] alu_control_i,

    // Input interface.
    input  logic [DATA_WIDTH    - 1:0] src_1_i,
    input  logic [DATA_WIDTH    - 1:0] src_2_i,

    // Output interface.
    output logic [DATA_WIDTH    - 1:0] alu_result_o,
    output logic                       zero_flag_o,
    output logic                       lt_flag_o,
    output logic                       ltu_flag_o
);

    // ---------------
    // Operations.
    // ---------------
    localparam ADD   = 5'b00000;
    localparam SUB   = 5'b00001;
    localparam AND   = 5'b00010;
    localparam OR    = 5'b00011;
    localparam XOR   = 5'b00100;
    localparam SLL   = 5'b00101;
    localparam SLT   = 5'b00110;
    localparam SLTU  = 5'b00111;
    localparam SRL   = 5'b01000;
    localparam SRA   = 5'b01001;

    localparam ADDW  = 5'b01010; // ADDW and ADDIW are the same in terms of ALU usage.
    localparam SUBW  = 5'b01011;
    localparam SLLW  = 5'b01100;
    localparam SRLW  = 5'b01101;
    localparam SRAW  = 5'b01110;

    localparam MUL    = 5'b01111;
    localparam MULH   = 5'b10000;
    localparam MULHSU = 5'b10001;
    localparam MULHU  = 5'b10010;

    localparam MULW  = 5'b10111;

    // localparam CSRRW = 5'b10000;
    // localparam CSRRS = 5'b10001;
    // localparam CSRRC = 5'b10010;




    //-------------------------
    // Internal nets.
    //-------------------------

    // ALU regular & immediate operation outputs.
    logic [DATA_WIDTH - 1:0] add_out_s;
    logic [DATA_WIDTH - 1:0] sub_out_s;
    logic [DATA_WIDTH - 1:0] and_out_s;
    logic [DATA_WIDTH - 1:0] or_out_s;
    logic [DATA_WIDTH - 1:0] xor_out_s;
    logic [DATA_WIDTH - 1:0] sll_out_s;
    logic [DATA_WIDTH - 1:0] srl_out_s;
    logic [DATA_WIDTH - 1:0] sra_out_s;

    logic less_than;
    logic less_than_u;

    // ALU word operation outputs.
    logic [WORD_WIDTH - 1:0] sllw_out_s;
    logic [WORD_WIDTH - 1:0] srlw_out_s;
    logic [WORD_WIDTH - 1:0] sraw_out_s;

    // ALU M extension operation outputs.
    logic signed [DATA_WIDTH        :0] mul_operand_1_s;
    logic signed [DATA_WIDTH        :0] mul_operand_2_s;
    logic signed [2 * DATA_WIDTH + 1:0] mul_out_full_s;
    logic        [2 * DATA_WIDTH - 1:0] mul_out_s;

    //---------------------------------
    // Arithmetic & Logic Operations.
    //---------------------------------
    // Prepare operands for multiplication.
    logic sign_src_1_s;
    logic sign_src_2_s;

    always_comb begin
        case (alu_control_i)
            MULHSU: begin
                sign_src_1_s = src_1_i[DATA_WIDTH - 1]; // Signed.
                sign_src_2_s = 1'b0;                   // Unsigned.
            end
            MULHU: begin
                sign_src_1_s = 1'b0; // Unsigned.
                sign_src_2_s = 1'b0; // Unsigned.
            end
            MUL,
            MULH: begin
                sign_src_1_s = src_1_i[DATA_WIDTH - 1]; // Signed.
                sign_src_2_s = src_2_i[DATA_WIDTH - 1]; // Signed.
            end
            default: begin
                sign_src_1_s = src_1_i[DATA_WIDTH - 1];
                sign_src_2_s = src_2_i[DATA_WIDTH - 1];
            end
        endcase
    end

    assign mul_operand_1_s = {sign_src_1_s, src_1_i};
    assign mul_operand_2_s = {sign_src_2_s, src_2_i};

    // ALU regular & immediate operations.
    assign add_out_s = src_1_i + src_2_i;
    assign sub_out_s = $unsigned($signed(src_1_i) - $signed(src_2_i));
    assign and_out_s = src_1_i & src_2_i;
    assign or_out_s  = src_1_i | src_2_i;
    assign xor_out_s = src_1_i ^ src_2_i;
    assign sll_out_s = src_1_i << src_2_i [5:0];
    assign srl_out_s = src_1_i >> src_2_i [5:0];
    assign sra_out_s = $unsigned($signed(src_1_i) >>> src_2_i [5:0]);

    assign less_than   = $signed(src_1_i) < $signed(src_2_i);
    assign less_than_u = src_1_i < src_2_i;

    // ALU word operations.
    assign sllw_out_s = src_1_i [31:0] << src_2_i [4:0];
    assign srlw_out_s = src_1_i [31:0] >> src_2_i [4:0];
    assign sraw_out_s = $unsigned($signed(src_1_i [31:0]) >>> src_2_i [4:0]);

    // ALU M extension operations.
    assign mul_out_full_s  = mul_operand_1_s * mul_operand_2_s;
    assign mul_out_s       = mul_out_full_s[2 * DATA_WIDTH - 1:0];

    // Flags.
    assign zero_flag_o = ~ (| alu_result_o);
    assign lt_flag_o   = less_than;
    assign ltu_flag_o  = less_than_u;

    // ---------------------------
    // Output MUX.
    // ---------------------------
    always_comb begin
        // Default values.
        alu_result_o    = '0;

        case (alu_control_i)
            ADD   : alu_result_o = add_out_s;
            SUB   : alu_result_o = sub_out_s;
            AND   : alu_result_o = and_out_s;
            OR    : alu_result_o = or_out_s;
            XOR   : alu_result_o = xor_out_s;
            SLL   : alu_result_o = sll_out_s;
            SLT   : alu_result_o = {{(DATA_WIDTH - 1) {1'b0}}, less_than  };
            SLTU  : alu_result_o = {{(DATA_WIDTH - 1) {1'b0}}, less_than_u};
            SRL   : alu_result_o = srl_out_s;
            SRA   : alu_result_o = sra_out_s;

            ADDW  : alu_result_o = {{32 {add_out_s  [31]}}, add_out_s [31:0]};
            SUBW  : alu_result_o = {{32 {sub_out_s  [31]}}, sub_out_s [31:0]};
            SLLW  : alu_result_o = {{32 {sllw_out_s [31]}}, sllw_out_s      };
            SRLW  : alu_result_o = {{32 {srlw_out_s [31]}}, srlw_out_s      };
            SRAW  : alu_result_o = {{32 {sraw_out_s [31]}}, sraw_out_s      };

            MUL   : alu_result_o = mul_out_s[DATA_WIDTH - 1:0];
            MULH  : alu_result_o = mul_out_s[2 * DATA_WIDTH - 1:DATA_WIDTH];
            MULHSU: alu_result_o = mul_out_s[2 * DATA_WIDTH - 1:DATA_WIDTH];
            MULHU : alu_result_o = mul_out_s[2 * DATA_WIDTH - 1:DATA_WIDTH];

            MULW  : alu_result_o = {{32{mul_out_s[31]}}, mul_out_s[31:0]};

            default: begin
                alu_result_o = 'b0;
            end
        endcase

    end
endmodule
