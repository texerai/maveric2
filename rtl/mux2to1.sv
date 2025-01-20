/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------
// This is a 2-to-1 mux module to choose Memory address.
// It can choose either PCNext or calculated result.
// ------------------------------------------------------

module mux2to1
// Parameters. 
#(
    parameter WIDTH = 64
) 
// Port decleration.
(
    // Input interface.
    input  logic                 i_control_signal,
    input  logic [ WIDTH - 1:0 ] i_mux_0,
    input  logic [ WIDTH - 1:0 ] i_mux_1,

    // Output interface.
    output logic [ WIDTH - 1:0 ] o_mux
);

    // MUX logic.
    assign o_mux = i_control_signal ? i_mux_1 : i_mux_0;
    
endmodule