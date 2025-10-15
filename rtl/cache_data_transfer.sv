/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------
// This module facilitates the data transfer between cache and AXI interfaces.
// -----------------------------------------------------------------------------

module cache_data_transfer
// Parameters.
#(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 64,
    parameter BLOCK_WIDTH    = 512,
    parameter WORD_WIDTH     = 32,
    parameter ADDR_INCR_VAL  = 64'd4
)
(
    // Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        start_read_i,
    input  logic                        start_write_i,
    input  logic                        axi_done_i,
    input  logic [BLOCK_WIDTH    - 1:0] data_block_cache_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_axi_i,
    input  logic [AXI_ADDR_WIDTH - 1:0] addr_cache_i,

    // Output interface.
    output logic                        count_done_o,
    output logic [BLOCK_WIDTH    - 1:0] data_block_cache_o,
    output logic [AXI_DATA_WIDTH - 1:0] data_axi_o,
    output logic [AXI_ADDR_WIDTH - 1:0] addr_axi_o
);
    localparam COUNT_LIMIT = BLOCK_WIDTH/WORD_WIDTH;

    //------------------------
    // INTERNAL NETS.
    //------------------------
    logic axi_free_s;

    assign axi_free_s = ~ (start_read_i | start_write_i);

    //-----------------------------------
    // Lower-level module instantiations.
    //-----------------------------------

    // Counter module instance.
    counter # (
        .LIMIT (COUNT_LIMIT - 1),
        .SIZE  (COUNT_LIMIT    )
    ) COUNT0 (
        .clk_i      (clk_i       ),
        .arst_i     (arst_i      ),
        .enable_i   (axi_done_i  ),
        .axi_free_i (axi_free_s  ),
        .done_o     (count_done_o)
    );

    // Address increment module instance.
    addr_increment # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .INCR_VAL       (ADDR_INCR_VAL )
    ) ADDR_INC0 (
        .clk_i      (clk_i       ),
        .arst_i     (arst_i      ),
        .axi_free_i (axi_free_s  ),
        .enable_i   (axi_done_i  ),
        .addr_i     (addr_cache_i),
        .addr_o     (addr_axi_o  )
    );

    // Shift register module instance.
    shift_reg # (
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .BLOCK_WIDTH    (BLOCK_WIDTH   )
    ) SREG0 (
        .clk_i        (clk_i             ),
        .arst_i       (arst_i            ),
        .write_en_i   (axi_done_i        ),
        .axi_free_i   (axi_free_s        ),
        .data_i       (data_axi_i        ),
        .data_block_i (data_block_cache_i),
        .data_o       (data_axi_o        ),
        .data_block_o (data_block_cache_o)
    );

endmodule
