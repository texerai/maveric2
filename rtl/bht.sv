/* Copyright (c) 2024 Maveric NU. All rights reserved. */

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
    input  logic                     stall_fetch_i,
    input  logic                     bht_update_i,
    input  logic                     branch_taken_i,
    input  logic [INDEX_WIDTH - 1:0] set_index_i,
    input  logic [INDEX_WIDTH - 1:0] set_index_exec_i,

    // Output interface.
    output logic                     bht_pred_taken_o
);

    //---------------------------------
    // Internal nets.
    //---------------------------------
    logic carry_t_s;
    logic carry_n_s;
    logic [SATUR_COUNT_W - 1:0] bht_t_s; // Taken.
    logic [SATUR_COUNT_W - 1:0] bht_n_s; // Not taken.

    logic bht_update_s;

    assign {carry_t_s, bht_t_s} = bht_mem[set_index_exec_i] + 2'b1;
    assign {carry_n_s, bht_n_s} = bht_mem[set_index_exec_i] - 2'b1;

    assign bht_update_s = bht_update_i & (~ stall_fetch_i);

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
        end
        else if (bht_update_s) begin
            if      (  branch_taken_i & (~ carry_t_s)) bht_mem[set_index_exec_i] <= bht_t_s;
            else if (~ branch_taken_i & (~ carry_n_s)) bht_mem[set_index_exec_i] <= bht_n_s;
        end
    end

    // Output logic.
    assign bht_pred_taken_o = bht_mem[set_index_i][1];

endmodule
