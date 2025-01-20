/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module is a 4-way set-associative data cache module.
// ----------------------------------------------------------------------


module dcache 
#(
    parameter WORD_WIDTH = 32,
              SET_WIDTH  = 512,
              N          = 4, // N-way set-associative.
              ADDR_WIDTH = 64,
              DATA_WIDTH = 64,
              SET_COUNT  = 16
)
(
    // Input interface.
    input  logic                      i_clk,
    input  logic                      i_arst,
    input  logic                      i_write_en,
    input  logic                      i_block_we,
    input  logic                      i_mem_access,
    input  logic [              1:0 ] i_store_type, // 00 - SB, 01 - SH, 10 - SW, 11 - SD.
    input  logic [ ADDR_WIDTH - 1:0 ] i_addr, 
    input  logic [ SET_WIDTH  - 1:0 ] i_data_block,
    input  logic [ DATA_WIDTH - 1:0 ] i_write_data,

    // Output interface.
    output logic                      o_hit,
    output logic                      o_dirty,
    output logic [ ADDR_WIDTH - 1:0 ] o_addr_wb,    // write-back address in case of dirty block.
    output logic [ SET_WIDTH  - 1:0 ] o_data_block, // write-back data.
    output logic                      o_store_addr_ma,
    output logic [ DATA_WIDTH - 1:0 ] o_read_data
);

    //----------------------------------------------------
    // Local param for cache size reconfigurability.
    //----------------------------------------------------
    localparam WORD_COUNT = SET_WIDTH/WORD_WIDTH; // 16 words.

    localparam SET_INDEX_WIDTH   = $clog2 ( SET_COUNT    ); // 2 bit.
    localparam WORD_OFFSET_WIDTH = $clog2 ( WORD_COUNT   ); // 4 bit.
    localparam BYTE_OFFSET_WIDTH = $clog2 ( WORD_WIDTH/8 ); // 2 bit.

    localparam TAG_MSB         = ADDR_WIDTH - 1;                                          // 63.
    localparam TAG_LSB         = SET_INDEX_WIDTH + WORD_OFFSET_WIDTH + BYTE_OFFSET_WIDTH; // 8.
    localparam TAG_WIDTH       = TAG_MSB - TAG_LSB + 1;                                   // 56.
    localparam INDEX_MSB       = TAG_LSB - 1;                                             // 7.
    localparam INDEX_LSB       = INDEX_MSB - SET_INDEX_WIDTH + 1;                         // 6.
    localparam WORD_OFFSET_MSB = INDEX_LSB - 1;                                           // 5.
    localparam WORD_OFFSET_LSB = BYTE_OFFSET_WIDTH;                                       // 2.
    localparam BYTE_OFFSET_MSB = BYTE_OFFSET_WIDTH - 1;                                   // 1.


    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic [ TAG_WIDTH         - 1:0 ] s_tag_in;
    logic [ SET_INDEX_WIDTH   - 1:0 ] s_index_in;
    logic [ WORD_OFFSET_WIDTH - 1:0 ] s_word_offset_in;
    logic [ BYTE_OFFSET_WIDTH - 1:0 ] s_byte_offset_in;

    logic                        s_dirty;

    logic [ N            - 1:0 ] s_hit_find;
    logic                        s_hit;
    logic [ $clog2 ( N ) - 1:0 ] s_way;
    logic [ $clog2 ( N ) - 1:0 ] s_plru;

    logic s_write_en;

    logic s_store_addr_ma_sh;
    logic s_store_addr_ma_sw;
    logic s_store_addr_ma_sd;

    //---------------------------------------------------------
    // Memory blocks.
    //---------------------------------------------------------
    logic [ TAG_WIDTH - 1:0 ] tag_mem   [ SET_COUNT - 1:0 ][ N - 1:0 ]; // Tag memory.
    logic [ N         - 1:0 ] valid_mem [ SET_COUNT - 1:0 ];            // Valid memory.
    logic [ N         - 1:0 ] dirty_mem [ SET_COUNT - 1:0 ];            // Dirty memory.
    logic [ N         - 2:0 ] plru_mem  [ SET_COUNT - 1:0 ];            // Tree Pseudo-LRU memory.
    logic [ SET_WIDTH - 1:0 ] d_mem     [ SET_COUNT - 1:0 ][ N - 1:0 ]; // Data memory.



    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign s_tag_in         = i_addr [ TAG_MSB         : TAG_LSB         ];
    assign s_index_in       = i_addr [ INDEX_MSB       : INDEX_LSB       ];
    assign s_word_offset_in = i_addr [ WORD_OFFSET_MSB : WORD_OFFSET_LSB ];
    assign s_byte_offset_in = i_addr [ BYTE_OFFSET_MSB : 0               ];

    assign s_dirty = dirty_mem [ s_index_in ][ s_plru ];

    assign s_write_en = i_write_en & s_hit;

    assign s_store_addr_ma_sh = i_addr [ 0 ];
    assign s_store_addr_ma_sw = | i_addr [ 1:0 ];
    assign s_store_addr_ma_sd = | i_addr [ 2:0 ];


    //---------------------------------------------------
    // Check.
    //---------------------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        s_hit_find [ 0 ] = valid_mem [ s_index_in ][ 0 ] & ( tag_mem [ s_index_in ][ 0 ] == s_tag_in );
        s_hit_find [ 1 ] = valid_mem [ s_index_in ][ 1 ] & ( tag_mem [ s_index_in ][ 1 ] == s_tag_in );
        s_hit_find [ 2 ] = valid_mem [ s_index_in ][ 2 ] & ( tag_mem [ s_index_in ][ 2 ] == s_tag_in );
        s_hit_find [ 3 ] = valid_mem [ s_index_in ][ 3 ] & ( tag_mem [ s_index_in ][ 3 ] == s_tag_in );

        casez ( s_hit_find )
            4'bzzz1: s_way = 2'b00;
            4'bzz10: s_way = 2'b01;
            4'bz100: s_way = 2'b10;
            4'b1000: s_way = 2'b11;
            default: s_way = s_plru;
        endcase
    end

    assign s_hit = | s_hit_find;

    // Logic for finding the PLRU.
    assign s_plru = { plru_mem [ s_index_in ][ 0 ], ( plru_mem [ s_index_in ][ 0 ] ? plru_mem [ s_index_in ][ 2 ] : plru_mem [ s_index_in ][ 1 ] ) };



    //--------------------------------------------------
    // Memory write logic.
    //--------------------------------------------------

    // Valid memory.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst ) begin
            for ( int i = 0; i < SET_COUNT; i++ ) begin
                valid_mem [ i ] <= '0;
            end
        end
        else if ( i_block_we ) valid_mem [ s_index_in ][ s_plru ] <= 1'b1;
    end

    // Dirty memory.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst ) begin
            for ( int i = 0; i < SET_COUNT; i++ ) begin
                dirty_mem [ i ] <= '0;
            end 
        end
        else if ( i_block_we ) dirty_mem [ s_index_in ][ s_plru ] <= 1'b0;
        else if ( s_write_en ) dirty_mem [ s_index_in ][ s_way  ] <= 1'b1;
    end

    // PLRU memory.
    //-----------------------------------------------------------------------
    // PLRU organization:
    // 0 - left, 1 - right leaf.
    // plru [ 0 ] - parent, plru [ 1 ] = left leaf, plru [ 2 ] - right leaf.
    //-----------------------------------------------------------------------
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst ) begin
            for ( int i = 0; i < SET_COUNT; i++ ) begin
                plru_mem [ i ] <= '0;
            end       
        end
        else if ( s_hit & i_mem_access ) begin
            plru_mem [ s_index_in ][ 0               ] <= ~ s_way [ 1 ];
            plru_mem [ s_index_in ][ 1 + s_way [ 1 ] ] <= ~ s_way [ 0 ];
        end
    end


    // Data memory.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        // Here it first checks WE which is 1 and ignores block_we.
        if ( i_block_we ) begin
            d_mem   [ s_index_in ][ s_plru ] <= i_data_block;
            tag_mem [ s_index_in ][ s_plru ] <= s_tag_in; 
        end
        else if ( s_write_en ) begin
            case ( i_store_type )
            /* verilator lint_off WIDTH */
                2'b11: d_mem [ s_index_in ][ s_way ][ ( (   s_word_offset_in [ WORD_OFFSET_WIDTH - 1:1 ] + 1 ) * 64 - 1 ) -: 64 ] <= i_write_data;          // SD Instruction.
                2'b10: d_mem [ s_index_in ][ s_way ][ ( (   s_word_offset_in                             + 1 ) * 32 - 1 ) -: 32 ] <= i_write_data [ 31:0 ]; // SW Instruction.
                2'b01: d_mem [ s_index_in ][ s_way ][ ( ( { s_word_offset_in, s_byte_offset_in [ 1 ] }   + 1 ) * 16 - 1 ) -: 16 ] <= i_write_data [ 15:0 ]; // SH Instruction.
                2'b00: d_mem [ s_index_in ][ s_way ][ ( ( { s_word_offset_in, s_byte_offset_in       }   + 1 ) * 8  - 1 ) -: 8  ] <= i_write_data [  7:0 ]; // SB Instruction.
            endcase   
        end
    end

    // Store address misalignment detection.
    always_comb begin
        // Default value.
        o_store_addr_ma = 1'b0;

        if ( i_write_en ) begin
            case ( i_store_type )
                2'b11: o_store_addr_ma = s_store_addr_ma_sd;
                2'b10: o_store_addr_ma = s_store_addr_ma_sw;
                2'b01: o_store_addr_ma = s_store_addr_ma_sh;
                default: o_store_addr_ma = 1'b0; 
            endcase
        end
    end


    //-------------------------------------------
    // Memory read logic.
    //-------------------------------------------
    assign o_read_data = d_mem [ s_index_in ][ s_way ][ ( ( s_word_offset_in [ WORD_OFFSET_WIDTH - 1:1 ] + 1 ) * 64 - 1 ) -: 64 ];
    /* verilator lint_off WIDTH */


    //--------------------------------------
    // Output continious assignments.
    //--------------------------------------
    assign o_hit        = s_hit;
    assign o_dirty      = s_dirty; 
    assign o_addr_wb    = { tag_mem [ s_index_in ][ s_plru ], s_index_in, { ( WORD_OFFSET_WIDTH ) {1'b0} }, 2'b0 };
    assign o_data_block = d_mem [ s_index_in ][ s_plru ];

endmodule