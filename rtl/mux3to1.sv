/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------
// This is a 3-to-1 mux module.
// ------------------------------------------------------

module mux3to1
// Parameters. 
#(
    parameter DATA_WIDTH = 64
) 
// Port decleration.
(
    // Input interface.
    input  logic [              1:0 ] i_control_signal,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_0,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_1,
    input  logic [ DATA_WIDTH - 1:0 ] i_mux_2,

    // Output interface.
    output logic [ DATA_WIDTH - 1:0 ] o_mux
);

    // MUX logic.
    always_comb begin
        case ( i_control_signal )
            2'd0   : o_mux = i_mux_0;
            2'd1   : o_mux = i_mux_1;
            2'd2   : o_mux = i_mux_2;
            default: o_mux = '0;
        endcase
    end
    
endmodule