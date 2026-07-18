/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 17/07/2026
// Last Revision: 17/07/2026
//------------------------------

// ----------------------------------------------------------------------
// This module is a fully associative 4 entry ITLB.
// ----------------------------------------------------------------------

`include "maveric_pkg.sv"

module pmp_range
// Parameters.
#(
    parameter PMP_ADDR_W = maveric_pkg::PMP_ADDR_W,
    parameter PA_W       = maveric_pkg::PA_W
)
(
    // Input interface.
    input  logic [             1:0] cfg_a_i,
    input  logic [PMP_ADDR_W - 1:0] addr0_i,
    input  logic [PMP_ADDR_W - 1:0] addr1_i,

    // Output interface.
    output logic                    active_o,
    output logic [PA_W       - 1:0] range_lo_o,
    output logic [PA_W       - 1:0] range_hi_o
);
    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic [PA_W - 1:0] addr0;
    logic [PA_W - 1:0] addr1;

    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign addr0 = {addr0_i, 2'b0};
    assign addr1 = {addr1_i, 2'b0};

    always_comb begin
        range_lo_o = '0;
        range_hi_o = '0;
        active_o   = '0;

        case (cfg_a_i)
            2'b00: begin // OFF.
                range_lo_o = '0;
                range_hi_o = '0;
                active_o   = '0;
            end
            2'b01: begin // TOR.
                range_lo_o = addr0;
                range_hi_o = addr1;
                active_o   = 1'b1;
            end
            2'b10: begin // NA4.
                range_lo_o = addr1;
                range_hi_o = addr1 + {{(PA_W - 3){1'b0}}, 3'b100};
                active_o   = 1'b1;
            end
            2'b11: begin // NAPOT. For now not implemented.
                range_lo_o = '0;
                range_hi_o = '0;
                active_o   = '0;
            end
            default: begin
                range_lo_o = '0;
                range_hi_o = '0;
                active_o   = '0;
            end
        endcase
    end



endmodule
