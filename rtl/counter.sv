/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------------------------
// This is a counter module that counts the number of transferred data bursts through AXI4-Lite interface.
// --------------------------------------------------------------------------------------------------------

module counter
// Parameters.
#(
    parameter LIMIT = 4'b1111,
    parameter SIZE  = 16
)
(
    // Countrol logic
    input  logic clk_i,
    input  logic arst_i,
    input  logic enable_i,
    input  logic axi_free_i,

    // Output interface.
    output logic done_o
);
    localparam WIDTH = $clog2(SIZE);

    logic [WIDTH - 1:0] count_s;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) count_s <= '0;
        else if (axi_free_i) count_s <= '0;
        else if (enable_i  ) count_s <= count_s + {{(WIDTH - 1){1'b0}}, 1'b1};
    end

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i                                     ) done_o <= 1'b0;
        else if ((count_s == LIMIT [WIDTH - 1:0]) & enable_i) done_o <= 1'b1;
        else                                                  done_o <= 1'b0;
    end

endmodule
