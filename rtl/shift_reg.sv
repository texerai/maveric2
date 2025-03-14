/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------------------
// This is fifo module that is used to store and output data as a queue in caching system.
// ----------------------------------------------------------------------------------------

module shift_reg 
#(
    parameter AXI_DATA_WIDTH = 32,
              BLOCK_WIDTH   = 512
) 
(
    // Input interface.
    input  logic                        i_clk,
    input  logic                        i_arst,
    input  logic                        i_write_en,
    input  logic                        i_axi_free,
    input  logic [AXI_DATA_WIDTH - 1:0] i_data,
    input  logic [BLOCK_WIDTH    - 1:0] i_data_block,

    // Output logic.
    output logic [AXI_DATA_WIDTH - 1:0] o_data,
    output logic [BLOCK_WIDTH    - 1:0] o_data_block
);

    always_ff @(posedge i_clk, posedge i_arst) begin
        if      (i_arst    ) o_data_block <= '0;
        else if (i_axi_free) o_data_block <= i_data_block;
        else if (i_write_en) o_data_block <= {i_data, o_data_block[BLOCK_WIDTH - 1:AXI_DATA_WIDTH]}; 
    end

    assign o_data = o_data_block [AXI_DATA_WIDTH - 1:0];
    
endmodule