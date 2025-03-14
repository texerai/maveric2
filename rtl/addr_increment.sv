/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------
// This is a address increment module that increments the address 
// by 4 when seding data in burst using AXI4-Lite protocol.
// ---------------------------------------------------------------

module addr_increment 
#(
    parameter AXI_ADDR_WIDTH = 64,
              INCR_VAL       = 64'd4
) 
(
    // Input interface.
    input  logic                        i_clk,
    input  logic                        i_axi_free,
    input  logic                        i_arst,
    input  logic                        i_enable,
    input  logic [AXI_ADDR_WIDTH - 1:0] i_addr,

    // Output interface. 
    output logic [AXI_ADDR_WIDTH - 1:0] o_addr
);

    logic [AXI_ADDR_WIDTH - 1:0] s_count;

    always_ff @(posedge i_clk, posedge i_arst) begin
        if      (i_arst    ) s_count <= '0;
        else if (i_axi_free) s_count <= '0;
        else if (i_enable  ) s_count <= s_count + INCR_VAL;
    end

    assign o_addr = i_addr + s_count;
    
endmodule