/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 09/06/2026
//------------------------------

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

    localparam CSRRW = 5'b10000;
    localparam CSRRS = 5'b10001;
    localparam CSRRC = 5'b10010;

    //-------------------------
    // Internal nets.
    //-------------------------

    // ALU regular & immediate operation outputs.
    logic [DATA_WIDTH - 1:0] add_out;
    logic [DATA_WIDTH - 1:0] sub_out;
    logic [DATA_WIDTH - 1:0] and_out;
    logic [DATA_WIDTH - 1:0] or_out;
    logic [DATA_WIDTH - 1:0] xor_out;
    logic [DATA_WIDTH - 1:0] sll_out;
    logic [DATA_WIDTH - 1:0] srl_out;
    logic [DATA_WIDTH - 1:0] sra_out;

    logic less_than;
    logic less_than_u;

    // ALU word operation outputs.
    logic [WORD_WIDTH - 1:0] sllw_out;
    logic [WORD_WIDTH - 1:0] srlw_out;
    logic [WORD_WIDTH - 1:0] sraw_out;

    //---------------------------------
    // Arithmetic & Logic Operations.
    //---------------------------------

    // ALU regular & immediate operations.
    assign add_out = src_1_i + src_2_i;
    assign sub_out = $unsigned($signed(src_1_i) - $signed(src_2_i));
    assign and_out = src_1_i & src_2_i;
    assign or_out  = src_1_i | src_2_i;
    assign xor_out = src_1_i ^ src_2_i;
    assign sll_out = src_1_i << src_2_i [5:0];
    assign srl_out = src_1_i >> src_2_i [5:0];
    assign sra_out = $unsigned($signed(src_1_i) >>> src_2_i [5:0]);

    assign less_than   = $signed(src_1_i) < $signed(src_2_i);
    assign less_than_u = src_1_i < src_2_i;

    // ALU word operations.
    assign sllw_out = src_1_i [31:0] << src_2_i [4:0];
    assign srlw_out = src_1_i [31:0] >> src_2_i [4:0];
    assign sraw_out = $unsigned($signed(src_1_i [31:0]) >>> src_2_i [4:0]);

    // Flags.
    assign zero_flag_o = ~ (| alu_result_o);
    assign lt_flag_o   = less_than;
    assign ltu_flag_o  = less_than_u;

    // ---------------------------
    // Output MUX.
    // ---------------------------
    always_comb begin
        // Default values.
        alu_result_o = '0;

        case (alu_control_i)
            ADD   : alu_result_o = add_out;
            SUB   : alu_result_o = sub_out;
            AND   : alu_result_o = and_out;
            OR    : alu_result_o = or_out;
            XOR   : alu_result_o = xor_out;
            SLL   : alu_result_o = sll_out;
            SLT   : alu_result_o = {{(DATA_WIDTH - 1) {1'b0}}, less_than  };
            SLTU  : alu_result_o = {{(DATA_WIDTH - 1) {1'b0}}, less_than_u};
            SRL   : alu_result_o = srl_out;
            SRA   : alu_result_o = sra_out;

            ADDW  : alu_result_o = {{32 {add_out  [31]}}, add_out [31:0]};
            SUBW  : alu_result_o = {{32 {sub_out  [31]}}, sub_out [31:0]};
            SLLW  : alu_result_o = {{32 {sllw_out [31]}}, sllw_out      };
            SRLW  : alu_result_o = {{32 {srlw_out [31]}}, srlw_out      };
            SRAW  : alu_result_o = {{32 {sraw_out [31]}}, sraw_out      };

            CSRRW: alu_result_o = src_1_i;
            CSRRS: alu_result_o = or_out;
            CSRRC: alu_result_o = (~ src_1_i) & src_2_i;
            default: begin
                alu_result_o = 'b0;
            end
        endcase

    end
endmodule
