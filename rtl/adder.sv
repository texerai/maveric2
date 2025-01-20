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
    input  logic [ DATA_WIDTH - 1:0 ] i_input1,
    input  logic [ DATA_WIDTH - 1:0 ] i_input2,

    // Output interface.
    output logic [ DATA_WIDTH - 1:0 ] o_sum
);

    assign o_sum = i_input1 + i_input2;

endmodule