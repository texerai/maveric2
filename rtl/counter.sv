/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------------------------
// This is a counter module that counts the number of transferred data bursts through AXI4-Lite interface.
// --------------------------------------------------------------------------------------------------------

module counter 
#(
    parameter LIMIT = 4'b1111,
              SIZE  = 16 
) 
(   
    // Countrol logic
    input  logic i_clk,
    input  logic i_arst,
    input  logic i_enable,
    input  logic i_axi_free,

    // Output interface.
    output logic o_done
);
    localparam WIDTH = $clog2(SIZE);

    logic [WIDTH - 1:0] s_count;

    always_ff @(posedge i_clk, posedge i_arst) begin
        if      (i_arst    ) s_count <= '0;
        else if (i_axi_free) s_count <= '0;
        else if (i_enable  ) s_count <= s_count + { { (WIDTH - 1){1'b0} }, 1'b1 }; 
    end

    always_ff @(posedge i_clk, posedge i_arst) begin
        if      (i_arst                                        ) o_done <= 1'b0;
        else if ((s_count == LIMIT [ WIDTH - 1:0 ] ) & i_enable) o_done <= 1'b1;
        else                                                     o_done <= 1'b0;
    end
    
endmodule