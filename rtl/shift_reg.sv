/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------------------
// This is a shift register module that is used to store and output data as a queue in caching system.
// ---------------------------------------------------------------------------------------------------

module shift_reg
// Parameters.
#(
    parameter AXI_DATA_WIDTH = 32,
    parameter BLOCK_WIDTH    = 512
)
(
    // Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        write_en_i,
    input  logic                        axi_free_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_i,
    input  logic [BLOCK_WIDTH    - 1:0] data_block_i,

    // Output logic.
    output logic [AXI_DATA_WIDTH - 1:0] data_o,
    output logic [BLOCK_WIDTH    - 1:0] data_block_o
);

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) data_block_o <= '0;
        else if (axi_free_i) data_block_o <= data_block_i;
        else if (write_en_i) data_block_o <= {data_i, data_block_o[BLOCK_WIDTH - 1:AXI_DATA_WIDTH]};
    end

    assign data_o = data_block_o [AXI_DATA_WIDTH - 1:0];

endmodule
