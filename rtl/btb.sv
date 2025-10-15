/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------
// This module implements a branch target buffer (BTB) based on N-way set-associative cache.
// ------------------------------------------------------------------------------------------

module btb
// Parameters.
#(
    parameter SET_COUNT   = 4,
    parameter N           = 4,
    parameter INDEX_WIDTH = 2,
    parameter BIA_WIDTH   = 60,
    parameter ADDR_WIDTH  = 64
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_fetch_i,
    input  logic                     branch_taken_i,
    input  logic [ADDR_WIDTH  - 1:0] target_addr_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_i,
    input  logic [$clog2(N)   - 1:0] way_write_i,
    input  logic [BIA_WIDTH   - 1:0] bia_write_i,
    input  logic [INDEX_WIDTH - 1:0] index_write_i,

    // Output interface.
    output logic                     hit_o,
    output logic [$clog2(N)   - 1:0] way_write_o,
    output logic [ADDR_WIDTH  - 1:0] target_addr_o
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
    logic [BIA_WIDTH   - 1:0] bia_read_s;  // Branch instruction address.
    logic [INDEX_WIDTH - 1:0] index_read_s;

    logic                    hit_s;
    logic [N          - 1:0] hit_find_s;
    logic [$clog2 (N) - 1:0] way_read_s;
    logic [$clog2 (N) - 1:0] plru_s;

    logic btb_update_s;


    //-----------------
    // Memory blocks.
    //-----------------
    logic [BIA_WIDTH  - 1:0] bia_mem   [SET_COUNT - 1:0][N - 1:0]; // Branch Instruction Address = Tag memory.
    logic [ADDR_WIDTH - 1:0] bta_mem   [SET_COUNT - 1:0][N - 1:0]; // Branch Target Addrss memory.
    logic [N          - 1:0] valid_mem [SET_COUNT - 1:0];          // Valid memory.
    logic [N          - 1:0] plru_mem  [SET_COUNT - 1:0];          // Valid memory.

    //-----------------------------------
    // Continious assignments.
    //-----------------------------------
    assign bia_read_s   = pc_i[BIA_MSB  :BIA_LSB  ];
    assign index_read_s = pc_i[INDEX_MSB:INDEX_LSB];

    assign btb_update_s = branch_taken_i & (~ stall_fetch_i);


    //-------------------------------------
    // Check for hit & plru.
    //-------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        hit_find_s[0] = valid_mem[index_read_s][0] & (bia_mem[index_read_s][0] == bia_read_s);
        hit_find_s[1] = valid_mem[index_read_s][1] & (bia_mem[index_read_s][1] == bia_read_s);
        hit_find_s[2] = valid_mem[index_read_s][2] & (bia_mem[index_read_s][2] == bia_read_s);
        hit_find_s[3] = valid_mem[index_read_s][3] & (bia_mem[index_read_s][3] == bia_read_s);

        casez ( hit_find_s )
            4'bzzz1: way_read_s = 2'b00;
            4'bzz10: way_read_s = 2'b01;
            4'bz100: way_read_s = 2'b10;
            4'b1000: way_read_s = 2'b11;
            default: way_read_s = plru_s; // If there is no record of this branch instruction, new_value will be written into place of plru.
        endcase
    end

    assign hit_s = | hit_find_s;

    // Logic for finding the PLRU.
    assign plru_s = {plru_mem[index_read_s][0], (plru_mem[index_read_s][0] ? plru_mem[index_read_s][2] : plru_mem[index_read_s][1])};


    //--------------------------------------------------
    // Memory write logic.
    //--------------------------------------------------

    // Valid memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                valid_mem [i] <= '0;
            end
        end
        else if (btb_update_s) valid_mem[index_write_i][way_write_i] <= 1'b1;
    end

    // PLRU memory.
    //-----------------------------------------------------------------------
    // PLRU organization:
    // 0 - left, 1 - right leaf.
    // plru [0] - parent, plru [1] = left leaf, plru [2] - right leaf.
    //-----------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                plru_mem [i] <= '0;
            end
        end
        else if (btb_update_s) begin
            plru_mem [index_write_i][0                    ] <= ~ way_write_i[1];
            plru_mem [index_write_i][1 + way_write_i [1]] <= ~ way_write_i[0];
        end
    end


    // BIA & BTA memory.
    always_ff @(posedge clk_i) begin
        if (btb_update_s) begin
            bia_mem[index_write_i][way_write_i] <= bia_write_i;
            bta_mem[index_write_i][way_write_i] <= target_addr_i;
        end
    end


    //------------------------------
    // Output logic.
    //------------------------------
    assign hit_o         = hit_s;
    assign target_addr_o = bta_mem[index_read_s][way_read_s];

    assign way_write_o = way_read_s;

endmodule
