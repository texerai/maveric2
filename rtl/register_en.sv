/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------
// This is a nonarchitectural register with write enable signal.
// -------------------------------------------------------------

module register_en
// Parameters.
#(
    parameter DATA_WIDTH = 64
)
// Port decleration. 
(   
    // Common clock & enable signal.
    input  logic                      i_clk,
    input  logic                      i_write_en,
    input  logic                      i_arst,

    //Input interface. 
    input  logic [ DATA_WIDTH - 1:0 ] i_write_data,
    
    // Output interface.
    output logic [ DATA_WIDTH - 1:0 ] o_read_data
);

    // Write logic.
    always_ff @( posedge i_clk, posedge i_arst ) begin 
        if      ( i_arst     ) o_read_data <= '0;
        else if ( i_write_en ) o_read_data <= i_write_data;
    end
    
endmodule