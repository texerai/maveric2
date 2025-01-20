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


    // Flags. 
    assign o_zero_flag = ~ ( | o_alu_result );
    assign o_lt_flag   = less_than;
    assign o_ltu_flag  = less_than_u;
    // assign s_overflow      = (o_alu_result[DATA_WIDTH - 1] ^ i_src_1[DATA_WIDTH - 1]) & 
    //                          (i_src_2[DATA_WIDTH - 1] ~^ i_src_1[DATA_WIDTH - 1] ~^ i_alu_control[0]);


    // ---------------------------
    // Output MUX.
    // ---------------------------
    always_comb begin
        // Default values.
        o_alu_result    = '0;

        case ( i_alu_control )
            ADD  : o_alu_result = s_add_out;
            SUB  : o_alu_result = s_sub_out;
            AND  : o_alu_result = s_and_out;
            OR   : o_alu_result = s_or_out;
            XOR  : o_alu_result = s_xor_out;
            SLL  : o_alu_result = s_sll_out;
            SLT  : o_alu_result = { { ( DATA_WIDTH - 1 ) { 1'b0 } }, less_than   };
            SLTU : o_alu_result = { { ( DATA_WIDTH - 1 ) { 1'b0 } }, less_than_u };
            SRL  : o_alu_result = s_srl_out;
            SRA  : o_alu_result = s_sra_out;

            ADDW : o_alu_result = { { 32 { s_add_out  [ 31 ] } }, s_add_out [ 31:0 ] };
            SUBW : o_alu_result = { { 32 { s_sub_out  [ 31 ] } }, s_sub_out [ 31:0 ] };
            SLLW : o_alu_result = { { 32 { s_sllw_out [ 31 ] } }, s_sllw_out         };
            SRLW : o_alu_result = { { 32 { s_srlw_out [ 31 ] } }, s_srlw_out         };
            SRAW : o_alu_result = { { 32 { s_sraw_out [ 31 ] } }, s_sraw_out         };

            // CSRRW: o_alu_result = i_src_1;
            // CSRRS: o_alu_result = s_or_out;
            // CSRRC: o_alu_result = ( ~ i_src_1) & i_src_2;

            default: begin
                o_alu_result    = 'b0;
            end 
        endcase

    end   
endmodule