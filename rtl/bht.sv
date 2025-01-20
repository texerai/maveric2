/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------
// This module implements a 2-bit saturation counter-based BHT (Branch History Table).
// ------------------------------------------------------------------------------------

module bht 
#(
    parameter SET_COUNT     = 32,
              INDEX_WIDTH   = 5,
              SATUR_COUNT_W = 2
)
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic                       i_stall_fetch,
    input  logic                       i_bht_update,
    input  logic                       i_branch_taken,
    input  logic [ INDEX_WIDTH - 1:0 ] i_set_index,
    input  logic [ INDEX_WIDTH - 1:0 ] i_set_index_exec,

    // Output interface.
    output logic                       o_bht_pred_taken
);

    //---------------------------------
    // Internal nets.
    //---------------------------------
    logic s_carry_t;
    logic s_carry_n;
    logic [ SATUR_COUNT_W - 1:0 ] s_bht_t; // Taken.
    logic [ SATUR_COUNT_W - 1:0 ] s_bht_n; // Not taken.

    logic s_bht_update;

    assign { s_carry_t, s_bht_t } = bht_mem [ i_set_index_exec ] + 2'b1;
    assign { s_carry_n, s_bht_n } = bht_mem [ i_set_index_exec ] - 2'b1;

    assign s_bht_update = i_bht_update & ( ~ i_stall_fetch );

    //-----------------
    // Memory blocks.
    //-----------------
    logic [ SATUR_COUNT_W - 1:0 ] bht_mem [ SET_COUNT - 1:0 ];

    // 2-bit saturation counter table.
    // 00 - Strongly not taken.
    // 01 - Weakly not taken.
    // 10 - Weakly taken.
    // 11 - Strongly taken.


    //-----------------
    // BHT update.
    //-----------------
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst ) begin
            for ( int i  = 0; i < SET_COUNT - 1 ; i++) begin
                bht_mem [ i ] <= 2'b10; // Reset to "weakly taken".
            end
        end
        else if ( s_bht_update ) begin
                 if (   i_branch_taken & ( ~ s_carry_t ) ) bht_mem [ i_set_index_exec ] <= s_bht_t;
            else if ( ~ i_branch_taken & ( ~ s_carry_n ) ) bht_mem [ i_set_index_exec ] <= s_bht_n;
        end
    end

    // Output logic.
    assign o_bht_pred_taken = bht_mem [ i_set_index ][ 1 ]; 

endmodule