/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------
// This module facilitates the data transfer between cache and AXI interfaces.
// -----------------------------------------------------------------------------

module cache_data_transfer 
#(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 64,
              BLOCK_WIDTH    = 512,
              WORD_WIDTH     = 32,
              ADDR_INCR_VAL  = 64'd4
) 
(
    // Input interface.
    input  logic                        i_clk,
    input  logic                        i_arst,
    input  logic                        i_start_read,
    input  logic                        i_start_write,
    input  logic                        i_axi_done,
    input  logic [BLOCK_WIDTH    - 1:0] i_data_block_cache,
    input  logic [AXI_DATA_WIDTH - 1:0] i_data_axi,
    input  logic [AXI_ADDR_WIDTH - 1:0] i_addr_cache,

    // Output interface.
    output logic                        o_count_done,
    output logic [BLOCK_WIDTH    - 1:0] o_data_block_cache,
    output logic [AXI_DATA_WIDTH - 1:0] o_data_axi,
    output logic [AXI_ADDR_WIDTH - 1:0] o_addr_axi
);
    localparam COUNT_LIMIT = BLOCK_WIDTH/WORD_WIDTH;

    //------------------------
    // INTERNAL NETS.
    //------------------------
    logic s_axi_free;

    assign s_axi_free = ~ (i_start_read | i_start_write);

    //-----------------------------------
    // Lower-level module instantiations.
    //-----------------------------------

    // Counter module instance.
    counter # (
        .LIMIT ( COUNT_LIMIT - 1 ), 
        .SIZE  ( COUNT_LIMIT     )  
    ) COUNT0 (
        .i_clk      ( i_clk        ),
        .i_arst     ( i_arst       ),
        .i_enable   ( i_axi_done   ),
        .i_axi_free ( s_axi_free   ),
        .o_done     ( o_count_done )
    );

    // Address increment module instance.
    addr_increment # (
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .INCR_VAL       ( ADDR_INCR_VAL  )
    ) ADDR_INC0 (
        .i_clk      ( i_clk        ),
        .i_arst     ( i_arst       ),
        .i_axi_free ( s_axi_free   ),
        .i_enable   ( i_axi_done   ),
        .i_addr     ( i_addr_cache ),
        .o_addr     ( o_addr_axi   )
    );

    // FIFO module instance.
    shift_reg # (
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .BLOCK_WIDTH    ( BLOCK_WIDTH    )
    ) SREG0 (
        .i_clk         ( i_clk              ),
        .i_arst        ( i_arst             ),
        .i_write_en    ( i_axi_done         ),
        .i_axi_free    ( s_axi_free         ),
        .i_data        ( i_data_axi         ),
        .i_data_block  ( i_data_block_cache ),
        .o_data        ( o_data_axi         ),
        .o_data_block  ( o_data_block_cache )
    );
    
endmodule