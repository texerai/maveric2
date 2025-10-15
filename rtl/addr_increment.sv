/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------
// This is a address increment module that increments the address
// by 4 when seding data in burst using AXI4-Lite protocol.
// ---------------------------------------------------------------

module addr_increment
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter INCR_VAL       = 64'd4
)
(
    // Input interface.
    input  logic                        clk_i,
    input  logic                        axi_free_i,
    input  logic                        arst_i,
    input  logic                        enable_i,
    input  logic [AXI_ADDR_WIDTH - 1:0] addr_i,

    // Output interface.
    output logic [AXI_ADDR_WIDTH - 1:0] addr_o
);

    logic [AXI_ADDR_WIDTH - 1:0] count_s;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) count_s <= '0;
        else if (axi_free_i) count_s <= '0;
        else if (enable_i  ) count_s <= count_s + INCR_VAL;
    end

    assign addr_o = addr_i + count_s;

endmodule
