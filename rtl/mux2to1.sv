/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 20/01/2025
//------------------------------

// ------------------------------------------------------
// This is a 2-to-1 mux module to choose Memory address.
// It can choose either PCNext or calculated result.
// ------------------------------------------------------

module mux2to1
#(
    parameter WIDTH = 64
)
(
    input  logic               control_signal_i,
    input  logic [WIDTH - 1:0] mux_0_i,
    input  logic [WIDTH - 1:0] mux_1_i,
    output logic [WIDTH - 1:0] mux_o
);
    assign mux_o = control_signal_i ? mux_1_i : mux_0_i;
endmodule
