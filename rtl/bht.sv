/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 15/05/2025
//------------------------------

// ------------------------------------------------------------------------------------
// This module implements a 2-bit saturation counter-based BHT (Branch History Table).
// ------------------------------------------------------------------------------------

module bht
// Parameters.
#(
    parameter SET_COUNT     = 32,
    parameter INDEX_WIDTH   = 5,
    parameter SATUR_COUNT_W = 2
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_if_i,
    input  logic                     bht_update_i,
    input  logic                     branch_taken_i,
    input  logic [INDEX_WIDTH - 1:0] set_index_i,
    input  logic [INDEX_WIDTH - 1:0] set_index_ex_i,

    // Output interface.
    output logic                     bht_pred_taken_o
);

    //---------------------------------
    // Internal nets.
    //---------------------------------
    logic carry_t;
    logic carry_n;
    logic [SATUR_COUNT_W - 1:0] bht_t; // Taken.
    logic [SATUR_COUNT_W - 1:0] bht_n; // Not taken.

    logic bht_update;

    assign {carry_t, bht_t} = bht_mem[set_index_ex_i] + 2'b1;
    assign {carry_n, bht_n} = bht_mem[set_index_ex_i] - 2'b1;

    assign bht_update = bht_update_i & (~ stall_if_i);

    //-----------------
    // Memory blocks.
    //-----------------
    logic [SATUR_COUNT_W - 1:0] bht_mem [SET_COUNT - 1:0];

    // 2-bit saturation counter table.
    // 00 - Strongly not taken.
    // 01 - Weakly not taken.
    // 10 - Weakly taken.
    // 11 - Strongly taken.


    //-----------------
    // BHT update.
    //-----------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for ( int i  = 0; i < SET_COUNT - 1; i++) begin
                bht_mem[i] <= 2'b01; // Reset to "weakly not taken".
            end
        end else if (bht_update) begin
            if      (  branch_taken_i & (~ carry_t)) bht_mem[set_index_ex_i] <= bht_t;
            else if (~ branch_taken_i & (~ carry_n)) bht_mem[set_index_ex_i] <= bht_n;
        end
    end

    // Output logic.
    assign bht_pred_taken_o = bht_mem[set_index_i][1];

endmodule
