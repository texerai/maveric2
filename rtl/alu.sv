/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------
// This is a Arithmetic Logic Unit (ALU).
// Copied from season 1.
// --------------------------------------

module alu 
// Parameters.
#(
    parameter DATA_WIDTH    = 64,
              WORD_WIDTH    = 32,
              CONTROL_WIDTH = 5   
) 
// Port decleration.
(
    // ALU control signal.
    input  logic [ CONTROL_WIDTH - 1:0 ] i_alu_control,

    // Input interface.
    input  logic [ DATA_WIDTH    - 1:0 ] i_src_1,
    input  logic [ DATA_WIDTH    - 1:0 ] i_src_2,

    // Output interface.
    output logic [ DATA_WIDTH    - 1:0 ] o_alu_result,
    output logic                         o_zero_flag,
    output logic                         o_lt_flag,
    output logic                         o_ltu_flag
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
    
    // localparam MUL    = 5'b01111;
    // localparam MULH   = 5'b10000;
    // localparam MULHSU = 5'b10001;
    // localparam MULHU  = 5'b10010;
    // localparam DIV    = 5'b10011;
    // localparam DIVU   = 5'b10100;
    // localparam REM    = 5'b10101;
    // localparam REMU   = 5'b10110;

    // localparam MULW  = 5'b10111;
    // localparam DIVW  = 5'b11000;
    // localparam DIVUW = 5'b11001;
    // localparam REMW  = 5'b11010;
    // localparam REMUW = 5'b11011;
    
    // localparam CSRRW = 5'b10000;
    // localparam CSRRS = 5'b10001;
    // localparam CSRRC = 5'b10010;




    //-------------------------
    // Internal nets.
    //-------------------------
    
    // ALU regular & immediate operation outputs.
    logic [ DATA_WIDTH - 1:0 ] s_add_out;
    logic [ DATA_WIDTH - 1:0 ] s_sub_out;
    logic [ DATA_WIDTH - 1:0 ] s_and_out;
    logic [ DATA_WIDTH - 1:0 ] s_or_out;
    logic [ DATA_WIDTH - 1:0 ] s_xor_out;
    logic [ DATA_WIDTH - 1:0 ] s_sll_out;
    logic [ DATA_WIDTH - 1:0 ] s_srl_out;
    logic [ DATA_WIDTH - 1:0 ] s_sra_out;

    logic less_than;
    logic less_than_u;

    // ALU word operation outputs.
    logic [ WORD_WIDTH - 1:0 ] s_sllw_out;
    logic [ WORD_WIDTH - 1:0 ] s_srlw_out;
    logic [ WORD_WIDTH - 1:0 ] s_sraw_out;

    // ALU M extension operation outputs.
    // logic [ 2 * DATA_WIDTH - 1:0 ] s_mul_out;
    // logic [ 2 * DATA_WIDTH - 1:0 ] s_mulsu_out;
    // logic [ 2 * DATA_WIDTH - 1:0 ] s_mulu_out;
    // logic [ DATA_WIDTH     - 1:0 ] s_div_out;
    // logic [ DATA_WIDTH     - 1:0 ] s_divu_out;
    // logic [ DATA_WIDTH     - 1:0 ] s_rem_out;
    // logic [ DATA_WIDTH     - 1:0 ] s_remu_out;

    // // ALU M extension word operation outputs.
    // logic [ WORD_WIDTH     - 1:0 ] s_divw_out;
    // logic [ WORD_WIDTH     - 1:0 ] s_divuw_out;
    // logic [ WORD_WIDTH     - 1:0 ] s_remw_out;
    // logic [ WORD_WIDTH     - 1:0 ] s_remuw_out;

    // Flag signals. 
    // logic s_carry_flag_add;
    // logic s_carry_flag_sub;
    // logic s_overflow;

    // NOTE: REVIEW SLT & SLTU INSTRUCTIONS. ALSO FLAGS.

    //---------------------------------
    // Arithmetic & Logic Operations.
    //---------------------------------
    
    // ALU regular & immediate operations. 
    assign s_add_out = i_src_1 + i_src_2;
    assign s_sub_out = $unsigned ( $signed ( i_src_1 ) - $signed ( i_src_2 ) );
    assign s_and_out = i_src_1 & i_src_2;
    assign s_or_out  = i_src_1 | i_src_2;
    assign s_xor_out = i_src_1 ^ i_src_2;
    assign s_sll_out = i_src_1 << i_src_2 [ 5:0 ];
    assign s_srl_out = i_src_1 >> i_src_2 [ 5:0 ];
    assign s_sra_out = $unsigned( $signed( i_src_1 ) >>> i_src_2 [ 5:0 ] );

    assign less_than   = $signed ( i_src_1 ) < $signed ( i_src_2 );
    assign less_than_u = i_src_1 < i_src_2;

    // ALU word operations.
    assign s_sllw_out = i_src_1 [ 31:0 ] << i_src_2 [ 4:0 ];
    assign s_srlw_out = i_src_1 [ 31:0 ] >> i_src_2 [ 4:0 ];
    assign s_sraw_out = $unsigned( $signed ( i_src_1 [ 31:0 ] ) >>> i_src_2 [ 4:0 ] );

    // ALU M extension operations.
    // assign s_mul_out   = $signed(i_src_1) * $signed(i_src_2);
    // assign s_mulsu_out = $signed(i_src_1) * $unsigned(i_src_2);
    // assign s_mulu_out  = $unsigned(i_src_1) * $unsigned(i_src_2);
    // assign s_div_out   = $signed(i_src_1) / $signed(i_src_2);
    // assign s_divu_out  = $unsigned(i_src_1) / $unsigned(i_src_2);
    // assign s_rem_out   = $signed(i_src_1) % $signed(i_src_2);
    // assign s_remu_out  = $unsigned(i_src_1) % $unsigned(i_src_2);

    // ALU M extension word operations.
    // assign s_divw_out   = $signed(i_src_1[31:0]) / $signed(i_src_2[31:0]);
    // assign s_divuw_out  = $unsigned(i_src_1[31:0]) / $unsigned(i_src_2[31:0]);
    // assign s_remw_out   = $signed(i_src_1[31:0]) % $signed(i_src_2[31:0]);
    // assign s_remuw_out  = $unsigned(i_src_1[31:0]) % $unsigned(i_src_2[31:0]);

    // Flags. 
    assign o_zero_flag = ~ ( | o_alu_result );
    assign o_lt_flag   = less_than;
    assign o_ltu_flag  = less_than_u;
    // assign s_overflow      = (o_alu_result[DATA_WIDTH - 1] ^ i_src_1[DATA_WIDTH - 1]) & 
    //                          (i_src_2[DATA_WIDTH - 1] ~^ i_src_1[DATA_WIDTH - 1] ~^ i_alu_control[0]);


    // NOTE: REVIEW DIV instruction division by 0 case.

    // ---------------------------
    // Output MUX.
    // ---------------------------
    always_comb begin
        // Default values.
        o_alu_result    = '0;

        case ( i_alu_control )
            ADD   : o_alu_result = s_add_out;
            SUB   : o_alu_result = s_sub_out;
            AND   : o_alu_result = s_and_out;
            OR    : o_alu_result = s_or_out;
            XOR   : o_alu_result = s_xor_out;
            SLL   : o_alu_result = s_sll_out;
            SLT   : o_alu_result = { { ( DATA_WIDTH - 1 ) { 1'b0 } }, less_than   };
            SLTU  : o_alu_result = { { ( DATA_WIDTH - 1 ) { 1'b0 } }, less_than_u };
            SRL   : o_alu_result = s_srl_out;
            SRA   : o_alu_result = s_sra_out;

            ADDW  : o_alu_result = { { 32 { s_add_out  [ 31 ] } }, s_add_out [ 31:0 ] };
            SUBW  : o_alu_result = { { 32 { s_sub_out  [ 31 ] } }, s_sub_out [ 31:0 ] };
            SLLW  : o_alu_result = { { 32 { s_sllw_out [ 31 ] } }, s_sllw_out         };
            SRLW  : o_alu_result = { { 32 { s_srlw_out [ 31 ] } }, s_srlw_out         };
            SRAW  : o_alu_result = { { 32 { s_sraw_out [ 31 ] } }, s_sraw_out         };

            // MUL   : o_alu_result = s_mul_out[DATA_WIDTH - 1:0];
            // MULH  : o_alu_result = s_mul_out[2 * DATA_WIDTH - 1:DATA_WIDTH];
            // MULHSU: o_alu_result = s_mulsu_out[2 * DATA_WIDTH - 1:DATA_WIDTH];
            // MULHU : o_alu_result = s_mulu_out[2 * DATA_WIDTH - 1:DATA_WIDTH];
            // DIV   : o_alu_result = s_div_out;
            // DIVU  : o_alu_result = s_divu_out;
            // REM   : o_alu_result = s_rem_out;
            // REMU  : o_alu_result = s_remu_out;
            
            // MULW  : o_alu_result = { { 32 { s_mul_out[31] } }, s_mul_out[31:0] };
            // DIVW  : o_alu_result = { { 32 { s_mul_out[31] } }, s_divw_out[31:0] };
            // DIVUW : o_alu_result = { { 32 { s_mul_out[31] } }, s_divuw_out[31:0] };
            // REMW  : o_alu_result = { { 32 { s_mul_out[31] } }, s_remw_out[31:0] };
            // REMUW : o_alu_result = { { 32 { s_mul_out[31] } }, s_remuw_out[31:0] };

            // CSRRW: o_alu_result = i_src_1;
            // CSRRS: o_alu_result = s_or_out;
            // CSRRC: o_alu_result = ( ~ i_src_1) & i_src_2;

            default: begin
                o_alu_result    = 'b0;
            end 
        endcase

    end   
endmodule