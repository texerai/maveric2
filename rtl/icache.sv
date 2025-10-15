/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module is a direct-mapped instruction cache module.
// ----------------------------------------------------------------------


module icache
// Parameters.
#(
    parameter BLOCK_COUNT = 16,
    parameter INSTR_WIDTH = 32,
    parameter BLOCK_WIDTH = 512,
    parameter ADDR_WIDTH  = 64
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     write_en_i,
    input  logic [ADDR_WIDTH  - 1:0] addr_i,
    input  logic [BLOCK_WIDTH - 1:0] instr_block_i,

    // Output interface.
    output logic [INSTR_WIDTH - 1:0] instruction_o,
    output logic                     hit_o
);

    //-----------------------------------------------------
    // Local parameters for cache size reconfigurability.
    //-----------------------------------------------------
    localparam WORD_COUNT = BLOCK_WIDTH/INSTR_WIDTH; // 16 words.

    localparam BLOCK_INDEX_WIDTH = $clog2(BLOCK_COUNT);   // 4 bit.
    localparam WORD_OFFSET_WIDTH = $clog2(WORD_COUNT);    // 4 bit.
    localparam BYTE_OFFSET_WIDTH = $clog2(INSTR_WIDTH/8); // 2 bit.

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
    logic [TAG_WIDTH         - 1:0] tag_in_s;
    logic [BLOCK_INDEX_WIDTH - 1:0] index_in_s;
    logic [WORD_OFFSET_WIDTH - 1:0] word_offset_in_s;

    logic [TAG_WIDTH - 1:0] tag_s;
    logic                   valid_s;
    logic                   tag_match_s;



    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign tag_in_s         = addr_i[TAG_MSB        :TAG_LSB        ];
    assign index_in_s       = addr_i[INDEX_MSB      :INDEX_LSB      ];
    assign word_offset_in_s = addr_i[WORD_OFFSET_MSB:WORD_OFFSET_LSB];

    assign tag_s   = tag_mem   [index_in_s];
    assign valid_s = valid_mem [index_in_s];

    assign tag_match_s = (tag_s == tag_in_s);
    assign hit_o       = valid_s & tag_match_s;



    //---------------------------------------------------------
    // Memory blocks.
    //---------------------------------------------------------
    logic [TAG_WIDTH - 1:0  ] tag_mem [BLOCK_COUNT - 1:0]; // Tag memory.
    logic [BLOCK_COUNT - 1:0] valid_mem;                   // Valid memory.
    logic [BLOCK_WIDTH - 1:0] i_mem   [BLOCK_COUNT - 1:0]; // Instruction memory.


    //--------------------------------------------------------
    // Memory blocks write logic.
    //--------------------------------------------------------

    // Valid memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) valid_mem <= '0;
        else if (write_en_i) valid_mem [ index_in_s] <= 1'b1;
    end

    // Tag & instruction memory.
    always_ff @(posedge clk_i) begin
        if (write_en_i) begin
            tag_mem [index_in_s] <= tag_in_s;
            i_mem   [index_in_s] <= instr_block_i;
        end
    end


    //-------------------------------------------------------
    // Memory block instruction read logic.
    //-------------------------------------------------------
    /* verilator lint_off WIDTH */
    assign instruction_o = i_mem[index_in_s][((word_offset_in_s + 1) * 32 - 1) -: 32];
    /* verilator lint_off WIDTH */


endmodule
