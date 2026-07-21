/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 27/06/2026
//------------------------------

// ----------------------------------------------------------------------
// This module is a 4-way set-associative data cache module.
// ----------------------------------------------------------------------

`include "maveric_pkg.sv"

// SET_COUNT is swept by run_tests.py -v via +define+MAVERIC_DCACHE_SET_COUNT=...
// (the dcache instance sits too deep for a top-level -G override); the guarded
// default below is the regular configuration.
`ifndef MAVERIC_DCACHE_SET_COUNT
`define MAVERIC_DCACHE_SET_COUNT 4
`endif

module dcache
// Parameters.
#(
    parameter WORD_WIDTH = 32,
    parameter SET_WIDTH  = 512,
    parameter N          = 4, // N-way set-associative. ALWAYS 4.
    parameter ADDR_WIDTH = maveric_pkg::XLEN,
    parameter DATA_WIDTH = maveric_pkg::XLEN,
    parameter SET_COUNT  = `MAVERIC_DCACHE_SET_COUNT
)
(
    // Input interface.
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    we_i,
    input  logic                    block_we_i,
    input  logic                    mem_access_i,
    input  logic [             1:0] store_type_i, // 00 - SB, 01 - SH, 10 - SW, 11 - SD.
    input  logic [ADDR_WIDTH - 1:0] addr_i,
    input  logic [SET_WIDTH  - 1:0] data_block_i,
    input  logic [DATA_WIDTH - 1:0] wdata_i,
    input  logic                    atomic_lr_i,
    input  logic                    atomic_sc_i,
    input  logic                    fencei_i,
    input  logic                    fencei_wb_done_i,

    // Output interface.
    output logic                    hit_o,
    output logic                    dirty_o,
    output logic                    fencei_wb_start_o,
    output logic                    reserve_valid_o,
    output logic [ADDR_WIDTH - 1:0] addr_wb_o,    // write-back address in case of dirty block.
    output logic [SET_WIDTH  - 1:0] data_block_o, // write-back data.
    output logic [DATA_WIDTH - 1:0] rdata_o
);

    //----------------------------------------------------
    // Local param for cache size reconfigurability.
    //----------------------------------------------------
    localparam WORD_COUNT = SET_WIDTH/WORD_WIDTH; // 16 words.

    localparam SET_INDEX_WIDTH   = $clog2(SET_COUNT  );  // 2 bit.
    localparam WORD_OFFSET_WIDTH = $clog2(WORD_COUNT );  // 4 bit.
    localparam BYTE_OFFSET_WIDTH = $clog2(WORD_WIDTH/8); // 2 bit.

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
    logic [TAG_WIDTH         - 1:0] tag_in;
    logic [SET_INDEX_WIDTH   - 1:0] index_in;
    logic [WORD_OFFSET_WIDTH - 1:0] word_offset_in;
    logic [BYTE_OFFSET_WIDTH - 1:0] byte_offset_in;

    logic dirty;

    logic [N          - 1:0] hit_find;
    logic                    hit;
    logic [$clog2 (N) - 1:0] way;
    logic [$clog2 (N) - 1:0] plru;

    logic we;

    //---------------------------------------------------------
    // Memory blocks.
    //---------------------------------------------------------
    logic [TAG_WIDTH - 1:0] tag_mem   [SET_COUNT - 1:0][N - 1:0]; // Tag memory.
    logic [N         - 1:0] valid_mem [SET_COUNT - 1:0];          // Valid memory.
    logic [N         - 1:0] dirty_mem [SET_COUNT - 1:0];          // Dirty memory.
    logic [N         - 2:0] plru_mem  [SET_COUNT - 1:0];          // Tree Pseudo-LRU memory.
    logic [SET_WIDTH - 1:0] d_mem     [SET_COUNT - 1:0][N - 1:0]; // Data memory.



    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign tag_in         = addr_i[TAG_MSB        :TAG_LSB        ];
    assign index_in       = addr_i[INDEX_MSB      :INDEX_LSB      ];
    assign word_offset_in = addr_i[WORD_OFFSET_MSB:WORD_OFFSET_LSB];
    assign byte_offset_in = addr_i[BYTE_OFFSET_MSB:0              ];

    assign dirty = dirty_mem[index_in][plru];

    assign we = (we_i | (reserve_valid & atomic_sc_i)) & hit;


    //---------------------------------------------------
    // Check.
    //---------------------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        hit_find[0] = valid_mem[index_in][0] & (tag_mem[index_in][0] == tag_in);
        hit_find[1] = valid_mem[index_in][1] & (tag_mem[index_in][1] == tag_in);
        hit_find[2] = valid_mem[index_in][2] & (tag_mem[index_in][2] == tag_in);
        hit_find[3] = valid_mem[index_in][3] & (tag_mem[index_in][3] == tag_in);

        casez (hit_find)
            4'bzzz1: way = 2'b00;
            4'bzz10: way = 2'b01;
            4'bz100: way = 2'b10;
            4'b1000: way = 2'b11;
            default: way = plru;
        endcase
    end

    assign hit = | hit_find;

    // Logic for finding the PLRU.
    assign plru = {plru_mem[index_in][0], (plru_mem[index_in][0] ? plru_mem[index_in][2] : plru_mem[index_in][1])};



    //--------------------------------------------------
    // Memory write logic.
    //--------------------------------------------------

    // Valid memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                valid_mem[i] <= '0;
            end
        end else if (block_we_i) valid_mem[index_in][plru] <= 1'b1;
    end

    // Dirty memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                dirty_mem [i] <= '0;
            end
        end else if (block_we_i) begin
            dirty_mem [index_in][plru] <= 1'b0;
        end else if (we) begin
            dirty_mem [index_in][way ] <= 1'b1;
        end else if (fencei_wb_done_i) begin
            dirty_mem[count_wb_walk[COUNT_W - 1:COUNT_W - SET_INDEX_WIDTH]][count_wb_walk[COUNT_W - SET_INDEX_WIDTH - 1:0]] <= 1'b0;
        end
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
        end else if (hit & mem_access_i) begin
            plru_mem [index_in][0          ] <= ~ way [1];
            plru_mem [index_in][1 + way [1]] <= ~ way [0];
        end
    end


    // Data memory.
    always_ff @(posedge clk_i) begin
        // Here it first checks WE which is 1 and ignores block_we.
        if (block_we_i) begin
            d_mem   [index_in][plru] <= data_block_i;
            tag_mem [index_in][plru] <= tag_in;
        end
        else if (we) begin
            case (store_type_i)
            /* verilator lint_off WIDTH */
                2'b11: d_mem [index_in][way][((  word_offset_in [WORD_OFFSET_WIDTH - 1:1] + 1) * 64 - 1) -: 64] <= wdata_i;        // SD Instruction.
                2'b10: d_mem [index_in][way][((  word_offset_in                           + 1) * 32 - 1) -: 32] <= wdata_i [31:0]; // SW Instruction.
                2'b01: d_mem [index_in][way][(({word_offset_in, byte_offset_in [1]}       + 1) * 16 - 1) -: 16] <= wdata_i [15:0]; // SH Instruction.
                2'b00: d_mem [index_in][way][(({word_offset_in, byte_offset_in      }     + 1) * 8  - 1) -: 8 ] <= wdata_i [ 7:0]; // SB Instruction.
            endcase
        end
    end


    //-------------------------------------------
    // LR and SC logic.
    //-------------------------------------------
    logic [ADDR_WIDTH - 1:0] reserve_addr;
    logic                    reserve_type; // 0 - Word, 1 Double word.
    logic                    reserve_active;

    logic reserve_valid;
    logic reserve_valid_interm;

    always_comb begin
        reserve_valid        = 1'b0;
        reserve_valid_interm = reserve_active & hit & (addr_i >= reserve_addr);


        if (reserve_type) begin // Double word.
            reserve_valid = reserve_valid_interm & (addr_i < reserve_addr + 64'd8);
        end else begin
            reserve_valid = reserve_valid_interm & (addr_i < reserve_addr + 64'd4);
        end
    end

    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            reserve_addr   <= '0;
            reserve_type   <= '0;
            reserve_active <= '0;
        end else if (hit & atomic_lr_i) begin
            reserve_addr   <= addr_i;
            reserve_type   <= store_type_i[0];
            reserve_active <= 1'b1;
        end else if (we & reserve_valid) begin
            reserve_addr   <= reserve_addr;
            reserve_type   <= reserve_type;
            reserve_active <= 1'b0;
        end
    end


    //-------------------------------------------
    // Memory read logic.
    //-------------------------------------------
    assign rdata_o = atomic_sc_i ? (reserve_valid ? 64'd0 : 64'd1) : d_mem [index_in][way][((word_offset_in [WORD_OFFSET_WIDTH - 1:1] + 1) * 64 - 1) -: 64];
    /* verilator lint_on WIDTH */


    //--------------------------------------
    // FENCE.I write-back logic.
    //--------------------------------------
    localparam COUNT_W = SET_INDEX_WIDTH + $clog2(N);
    logic [COUNT_W - 1:0] count_wb_walk;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) count_wb_walk <= '0;
        else if (fencei_wb_done_i) begin
            count_wb_walk <= count_wb_walk + {{(COUNT_W - 1){1'b0}}, 1'b1};
        end
    end

    assign fencei_wb_start_o = fencei_i &  (~(fencei_wb_done_i & (&count_wb_walk)));



    //--------------------------------------
    // Output continious assignments.
    //--------------------------------------
    assign hit_o        = hit;
    assign dirty_o      = fencei_i ? dirty_mem[count_wb_walk[COUNT_W - 1:COUNT_W - SET_INDEX_WIDTH]][count_wb_walk[COUNT_W - SET_INDEX_WIDTH - 1:0]] : dirty;
    assign reserve_valid_o = reserve_valid;
    assign addr_wb_o    = fencei_i ? {tag_mem[count_wb_walk[COUNT_W - 1:COUNT_W - SET_INDEX_WIDTH]][count_wb_walk[COUNT_W - SET_INDEX_WIDTH - 1:0]],
                                     count_wb_walk[COUNT_W - 1:COUNT_W - SET_INDEX_WIDTH], {(WORD_OFFSET_WIDTH) {1'b0}}, 2'b0} :
                                     {tag_mem [index_in][plru], index_in, {(WORD_OFFSET_WIDTH) {1'b0}}, 2'b0};
    assign data_block_o = fencei_i ? d_mem[count_wb_walk[COUNT_W - 1:COUNT_W - SET_INDEX_WIDTH]][count_wb_walk[COUNT_W - SET_INDEX_WIDTH - 1:0]] : d_mem[index_in][plru];

endmodule
