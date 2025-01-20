/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------
// This is a 5-to-1 mux module.
// ------------------------------------------------------

module mux5to1
// Parameters. 
#(
    parameter DATA_WIDTH = 64
) 
// Port decleration.
(
    // Input interface.
    input  logic [              2:0 ] i_control_signal,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_0,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_1,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_2,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_3,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_4,

    // Output interface.
    output logic [ DATA_WIDTH - 1:0 ] o_mux
);

    // MUX logic.
    always_comb begin
        case ( i_control_signal )
            3'd0   : o_mux = i_mux_0;
            3'd1   : o_mux = i_mux_1;
            3'd2   : o_mux = i_mux_2;
            3'd3   : o_mux = i_mux_3;
            3'd4   : o_mux = i_mux_4;
            default: o_mux = '0;
        endcase
    end
    
endmodule