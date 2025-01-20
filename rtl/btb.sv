/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------
// This module implements a branch target buffer (BTB) based on N-way set-associative cache.
// ------------------------------------------------------------------------------------------

module btb 
#(
    parameter SET_COUNT   = 4,
              N           = 4,
              INDEX_WIDTH = 2,
              BIA_WIDTH   = 60, 
              ADDR_WIDTH  = 64
)
(
    // Input interface.
    input  logic                        i_clk,
    input  logic                        i_arst,
    input  logic                        i_stall_fetch,
    input  logic                        i_branch_taken,
    input  logic [ ADDR_WIDTH   - 1:0 ] i_target_addr,
    input  logic [ ADDR_WIDTH   - 1:0 ] i_pc,
    input  logic [ $clog2 ( N ) - 1:0 ] i_way_write,
    input  logic [ BIA_WIDTH    - 1:0 ] i_bia_write,
    input  logic [ INDEX_WIDTH  - 1:0 ] i_index_write,

    // Output interface.
    output logic                        o_hit,
    output logic [ $clog2 ( N ) - 1:0 ] o_way_write,
    output logic [ ADDR_WIDTH   - 1:0 ] o_target_addr
);
    //---------------------------------
    // Localparameters.
    //---------------------------------
    localparam BYTE_OFFSET_WIDTH = 2; // 2 bit. 

    localparam BIA_MSB   = ADDR_WIDTH - 1;              // 63.
    localparam BIA_LSB   = BIA_MSB - BIA_WIDTH + 1;     // 4.
    localparam INDEX_MSB = BIA_LSB - 1;                 // 3.
    localparam INDEX_LSB = INDEX_MSB - INDEX_WIDTH + 1; // 2.


    //---------------------------------
    // Internal nets.
    //---------------------------------
    logic [ BIA_WIDTH   - 1:0 ] s_bia_read;  // Branch instruction address.
    logic [ INDEX_WIDTH - 1:0 ] s_index_read;

    logic                        s_hit;
    logic [ N            - 1:0 ] s_hit_find;
    logic [ $clog2 ( N ) - 1:0 ] s_way_read;
    logic [ $clog2 ( N ) - 1:0 ] s_plru;

    logic s_btb_update;


    //-----------------
    // Memory blocks.
    //-----------------
    logic [ BIA_WIDTH  - 1:0 ] bia_mem   [ SET_COUNT - 1:0 ][ N - 1:0 ]; // Branch Instruction Address = Tag memory.
    logic [ ADDR_WIDTH - 1:0 ] bta_mem   [ SET_COUNT - 1:0 ][ N - 1:0 ]; // Branch Target Addrss memory.
    logic [ N          - 1:0 ] valid_mem [ SET_COUNT - 1:0 ];            // Valid memory. 
    logic [ N          - 1:0 ] plru_mem  [ SET_COUNT - 1:0 ];            // Valid memory. 

    //-----------------------------------
    // Continious assignments.
    //-----------------------------------
    assign s_bia_read   = i_pc [ BIA_MSB   : BIA_LSB   ];
    assign s_index_read = i_pc [ INDEX_MSB : INDEX_LSB ];

    assign s_btb_update = i_branch_taken & ( ~ i_stall_fetch );


    //-------------------------------------
    // Check for hit & plru.
    //-------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        s_hit_find [ 0 ] = valid_mem [ s_index_read ][ 0 ] & ( bia_mem [ s_index_read ][ 0 ] == s_bia_read );
        s_hit_find [ 1 ] = valid_mem [ s_index_read ][ 1 ] & ( bia_mem [ s_index_read ][ 1 ] == s_bia_read );
        s_hit_find [ 2 ] = valid_mem [ s_index_read ][ 2 ] & ( bia_mem [ s_index_read ][ 2 ] == s_bia_read );
        s_hit_find [ 3 ] = valid_mem [ s_index_read ][ 3 ] & ( bia_mem [ s_index_read ][ 3 ] == s_bia_read );

        casez ( s_hit_find )
            4'bzzz1: s_way_read = 2'b00;
            4'bzz10: s_way_read = 2'b01;
            4'bz100: s_way_read = 2'b10;
            4'b1000: s_way_read = 2'b11;
            default: s_way_read = s_plru; // If there is no record of this branch instruction, new_value will be written into place of plru.
        endcase
    end

    assign s_hit = | s_hit_find;

    // Logic for finding the PLRU.
    assign s_plru = { plru_mem [ s_index_read ][ 0 ], ( plru_mem [ s_index_read ][ 0 ] ? plru_mem [ s_index_read ][ 2 ] : plru_mem [ s_index_read ][ 1 ] ) };


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
        else if ( s_btb_update ) valid_mem [ i_index_write ][ i_way_write ] <= 1'b1;
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
        else if ( s_btb_update ) begin
            plru_mem [ i_index_write ][ 0                     ] <= ~ i_way_write [ 1 ];
            plru_mem [ i_index_write ][ 1 + i_way_write [ 1 ] ] <= ~ i_way_write [ 0 ];
        end
    end


    // BIA & BTA memory.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( s_btb_update ) begin
            bia_mem [ i_index_write ][ i_way_write ] <= i_bia_write;
            bta_mem [ i_index_write ][ i_way_write ] <= i_target_addr;
        end
    end

    
    //------------------------------
    // Output logic.
    //------------------------------
    assign o_hit         = s_hit;
    assign o_target_addr = bta_mem [ s_index_read ][ s_way_read ];

    assign o_way_write = s_way_read;

endmodule