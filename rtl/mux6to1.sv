/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/06/2026
// Last Revision: 09/06/2026
//------------------------------

// ------------------------------------------------------
// This is a 6-to-1 mux module.
// ------------------------------------------------------

module mux6to1
// Parameters.
#(
    parameter DATA_WIDTH = 64
)
// Port decleration.
(
    // Input interface.
    input  logic [             2:0] control_signal_i,
    input  logic [DATA_WIDTH - 1:0] mux_0_i,
    input  logic [DATA_WIDTH - 1:0] mux_1_i,
    input  logic [DATA_WIDTH - 1:0] mux_2_i,
    input  logic [DATA_WIDTH - 1:0] mux_3_i,
    input  logic [DATA_WIDTH - 1:0] mux_4_i,
    input  logic [DATA_WIDTH - 1:0] mux_5_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] mux_o
);

    // MUX logic.
    always_comb begin
        case (control_signal_i)
            3'd0: mux_o = mux_0_i;
            3'd1: mux_o = mux_1_i;
            3'd2: mux_o = mux_2_i;
            3'd3: mux_o = mux_3_i;
            3'd4: mux_o = mux_4_i;
            3'd5: mux_o = mux_5_i;
            default: mux_o = '0;
        endcase
    end

endmodule
