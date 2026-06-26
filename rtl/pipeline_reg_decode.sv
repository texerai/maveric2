/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 30/05/2025
//------------------------------

// --------------------------------------------------------------------------------------------------
// This is a nonarchitectural register file with stall and flush signals for fetch stage pipelining.
// --------------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module pipeline_reg_decode
// Port decleration.
(
    //Input interface.
    input  logic                       clk_i,
    input  logic                       arst_i,
    input  logic                       flush_id_i,
    input  logic                       stall_id_i,
    input  pipeline_stage_pkg::if_id_t if_id_i,

    // Output interface.
    output pipeline_stage_pkg::if_id_t if_id_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i     ) if_id_o <= '0;
        else if (flush_id_i ) if_id_o <= '0;
        else if (~stall_id_i) if_id_o <= if_id_i;
    end

endmodule
