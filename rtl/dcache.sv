/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module is a 4-way set-associative data cache module.
// ----------------------------------------------------------------------


module dcache
// Parameters.
#(
    parameter WORD_WIDTH = 32,
    parameter SET_WIDTH  = 512,
    parameter N          = 4, // N-way set-associative.
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64,
    parameter SET_COUNT  = 4
)
(
    // Input interface.
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    write_en_i,
    input  logic                    block_we_i,
    input  logic                    mem_access_i,
    input  logic [             1:0] store_type_i, // 00 - SB, 01 - SH, 10 - SW, 11 - SD.
    input  logic [ADDR_WIDTH - 1:0] addr_i,
    input  logic [SET_WIDTH  - 1:0] data_block_i,
    input  logic [DATA_WIDTH - 1:0] write_data_i,

    // Output interface.
    output logic                    hit_o,
    output logic                    dirty_o,
    output logic [ADDR_WIDTH - 1:0] addr_wb_o,    // write-back address in case of dirty block.
    output logic [SET_WIDTH  - 1:0] data_block_o, // write-back data.
    output logic                    store_addr_ma_o,
    output logic [DATA_WIDTH - 1:0] read_data_o
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
    logic [TAG_WIDTH         - 1:0] tag_in_s;
    logic [SET_INDEX_WIDTH   - 1:0] index_in_s;
    logic [WORD_OFFSET_WIDTH - 1:0] word_offset_in_s;
    logic [BYTE_OFFSET_WIDTH - 1:0] byte_offset_in_s;

    logic dirty_s;

    logic [N          - 1:0] hit_find_s;
    logic                    hit_s;
    logic [$clog2 (N) - 1:0] way_s;
    logic [$clog2 (N) - 1:0] plru_s;

    logic write_en_s;

    logic store_addr_ma_sh_s;
    logic store_addr_ma_sw_s;
    logic store_addr_ma_sd_s;

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
    assign tag_in_s         = addr_i[TAG_MSB        :TAG_LSB        ];
    assign index_in_s       = addr_i[INDEX_MSB      :INDEX_LSB      ];
    assign word_offset_in_s = addr_i[WORD_OFFSET_MSB:WORD_OFFSET_LSB];
    assign byte_offset_in_s = addr_i[BYTE_OFFSET_MSB:0              ];

    assign dirty_s = dirty_mem[index_in_s][plru_s];

    assign write_en_s = write_en_i & hit_s;

    assign store_addr_ma_sh_s = addr_i[0];
    assign store_addr_ma_sw_s = | addr_i[1:0];
    assign store_addr_ma_sd_s = | addr_i[2:0];


    //---------------------------------------------------
    // Check.
    //---------------------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        hit_find_s[0] = valid_mem[index_in_s][0] & (tag_mem[index_in_s][0] == tag_in_s);
        hit_find_s[1] = valid_mem[index_in_s][1] & (tag_mem[index_in_s][1] == tag_in_s);
        hit_find_s[2] = valid_mem[index_in_s][2] & (tag_mem[index_in_s][2] == tag_in_s);
        hit_find_s[3] = valid_mem[index_in_s][3] & (tag_mem[index_in_s][3] == tag_in_s);

        casez (hit_find_s)
            4'bzzz1: way_s = 2'b00;
            4'bzz10: way_s = 2'b01;
            4'bz100: way_s = 2'b10;
            4'b1000: way_s = 2'b11;
            default: way_s = plru_s;
        endcase
    end

    assign hit_s = | hit_find_s;

    // Logic for finding the PLRU.
    assign plru_s = {plru_mem[index_in_s][0], (plru_mem[index_in_s][0] ? plru_mem[index_in_s][2] : plru_mem[index_in_s][1])};



    //--------------------------------------------------
    // Memory write logic.
    //--------------------------------------------------

    // Valid memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                valid_mem[i] <= '0;
            end
        end
        else if (block_we_i) valid_mem[index_in_s][plru_s] <= 1'b1;
    end

    // Dirty memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < SET_COUNT; i++) begin
                dirty_mem [i] <= '0;
            end
        end
        else if (block_we_i) dirty_mem [index_in_s][plru_s] <= 1'b0;
        else if (write_en_s) dirty_mem [index_in_s][way_s ] <= 1'b1;
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
        else if (hit_s & mem_access_i) begin
            plru_mem [index_in_s][0            ] <= ~ way_s [1];
            plru_mem [index_in_s][1 + way_s [1]] <= ~ way_s [0];
        end
    end


    // Data memory.
    always_ff @(posedge clk_i) begin
        // Here it first checks WE which is 1 and ignores block_we.
        if (block_we_i) begin
            d_mem   [index_in_s][plru_s] <= data_block_i;
            tag_mem [index_in_s][plru_s] <= tag_in_s;
        end
        else if (write_en_s) begin
            case (store_type_i)
            /* verilator lint_off WIDTH */
                2'b11: d_mem [index_in_s][way_s][((  word_offset_in_s [WORD_OFFSET_WIDTH - 1:1] + 1) * 64 - 1) -: 64] <= write_data_i;        // SD Instruction.
                2'b10: d_mem [index_in_s][way_s][((  word_offset_in_s                           + 1) * 32 - 1) -: 32] <= write_data_i [31:0]; // SW Instruction.
                2'b01: d_mem [index_in_s][way_s][(({word_offset_in_s, byte_offset_in_s [1]}     + 1) * 16 - 1) -: 16] <= write_data_i [15:0]; // SH Instruction.
                2'b00: d_mem [index_in_s][way_s][(({word_offset_in_s, byte_offset_in_s      }   + 1) * 8  - 1) -: 8 ] <= write_data_i [ 7:0]; // SB Instruction.
            endcase
        end
    end

    // Store address misalignment detection.
    always_comb begin
        // Default value.
        store_addr_ma_o = 1'b0;

        if (write_en_i) begin
            case (store_type_i)
                2'b11: store_addr_ma_o = store_addr_ma_sd_s;
                2'b10: store_addr_ma_o = store_addr_ma_sw_s;
                2'b01: store_addr_ma_o = store_addr_ma_sh_s;
                default: store_addr_ma_o = 1'b0;
            endcase
        end
    end


    //-------------------------------------------
    // Memory read logic.
    //-------------------------------------------
    assign read_data_o = d_mem [index_in_s][way_s][((word_offset_in_s [WORD_OFFSET_WIDTH - 1:1] + 1) * 64 - 1) -: 64];
    /* verilator lint_off WIDTH */


    //--------------------------------------
    // Output continious assignments.
    //--------------------------------------
    assign hit_o        = hit_s;
    assign dirty_o      = dirty_s;
    assign addr_wb_o    = {tag_mem [index_in_s][plru_s], index_in_s, {(WORD_OFFSET_WIDTH) {1'b0}}, 2'b0};
    assign data_block_o = d_mem [index_in_s][plru_s];

endmodule
