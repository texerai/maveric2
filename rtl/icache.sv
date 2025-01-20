/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module is a direct-mapped instruction cache module.
// ----------------------------------------------------------------------


module icache 
#(
    parameter BLOCK_COUNT = 16,
              INSTR_WIDTH = 32,
              BLOCK_WIDTH = 512,
              ADDR_WIDTH  = 64
)
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic                       i_write_en,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_addr,
    input  logic [ BLOCK_WIDTH - 1:0 ] i_instr_block,
    
    // Output interface.
    output logic [ INSTR_WIDTH - 1:0 ] o_instruction,
    output logic                       o_hit 
);

    //-----------------------------------------------------
    // Local parameters for cache size reconfigurability.
    //-----------------------------------------------------
    localparam WORD_COUNT = BLOCK_WIDTH/INSTR_WIDTH; // 16 words.

    localparam BLOCK_INDEX_WIDTH = $clog2 ( BLOCK_COUNT   ); // 4 bit.
    localparam WORD_OFFSET_WIDTH = $clog2 ( WORD_COUNT    ); // 4 bit.
    localparam BYTE_OFFSET_WIDTH = $clog2 ( INSTR_WIDTH/8 ); // 2 bit.

    localparam TAG_MSB         = ADDR_WIDTH - 1;                                            // 63.
    localparam TAG_LSB         = BLOCK_INDEX_WIDTH + WORD_OFFSET_WIDTH + BYTE_OFFSET_WIDTH; // 10.
    localparam TAG_WIDTH       = TAG_MSB - TAG_LSB + 1;                                     // 54.
    localparam INDEX_MSB       = TAG_LSB - 1;                                               // 9.
    localparam INDEX_LSB       = INDEX_MSB - BLOCK_INDEX_WIDTH + 1;                         // 6.
    localparam WORD_OFFSET_MSB = INDEX_LSB - 1;                                             // 5.
    localparam WORD_OFFSET_LSB = BYTE_OFFSET_WIDTH;                                         // 2.


    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic [ TAG_WIDTH         - 1:0 ] s_tag_in;
    logic [ BLOCK_INDEX_WIDTH - 1:0 ] s_index_in;
    logic [ WORD_OFFSET_WIDTH - 1:0 ] s_word_offset_in;

    logic [ TAG_WIDTH - 1:0 ] s_tag;
    logic                     s_valid;
    logic                     s_tag_match;



    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign s_tag_in         = i_addr [ TAG_MSB         : TAG_LSB         ];
    assign s_index_in       = i_addr [ INDEX_MSB       : INDEX_LSB       ];
    assign s_word_offset_in = i_addr [ WORD_OFFSET_MSB : WORD_OFFSET_LSB ];

    assign s_tag   = tag_mem   [ s_index_in ];
    assign s_valid = valid_mem [ s_index_in ];

    assign s_tag_match = ( s_tag == s_tag_in );
    assign o_hit       = s_valid & s_tag_match;



    //---------------------------------------------------------
    // Memory blocks.
    //---------------------------------------------------------
    logic [ TAG_WIDTH - 1:0   ] tag_mem [ BLOCK_COUNT - 1:0 ]; // Tag memory.
    logic [ BLOCK_COUNT - 1:0 ] valid_mem;                     // Valid memory.
    logic [ BLOCK_WIDTH - 1:0 ] i_mem   [ BLOCK_COUNT - 1:0 ]; // Instruction memory.


    //--------------------------------------------------------
    // Memory blocks write logic.
    //--------------------------------------------------------

    // Valid memory.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if      ( i_arst     ) valid_mem <= '0;
        else if ( i_write_en ) valid_mem [ s_index_in ] <= 1'b1;
    end

    // Tag & instruction memory.
    always_ff @( posedge i_clk ) begin
        if ( i_write_en ) begin
            tag_mem [ s_index_in ] <= s_tag_in;
            i_mem   [ s_index_in ] <= i_instr_block;
        end
    end


    //-------------------------------------------------------
    // Memory block instruction read logic.
    //-------------------------------------------------------
    /* verilator lint_off WIDTH */
    assign o_instruction = i_mem [ s_index_in ][ ( ( s_word_offset_in + 1 ) * 32 - 1 ) -: 32 ];
    /* verilator lint_off WIDTH */


endmodule