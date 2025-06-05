/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------
// This is a simple adder module.
// --------------------------------------

module adder
// Parameters.
#(
    parameter DATA_WIDTH = 64
)
(
    // Input interface.
    input  logic [DATA_WIDTH - 1:0] input1_i,
    input  logic [DATA_WIDTH - 1:0] input2_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] sum_o
);

    assign sum_o = input1_i + input2_i;

endmodule
