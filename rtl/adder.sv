/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 20/01/2025
//------------------------------

// --------------------------------------
// This is a simple adder module.
// --------------------------------------

`include "maveric_pkg.sv"

module adder
// Parameters.
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN
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
