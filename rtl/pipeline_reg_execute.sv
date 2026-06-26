/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/06/2026
//------------------------------

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file with a flush signal for decode stage pipelining.
// ------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module pipeline_reg_execute
// Port decleration.
(
    //Input interface.
    input  logic                       clk_i,
    input  logic                       arst_i,
    input  logic                       stall_ex_i,
    input  logic                       flush_ex_i,
    input  pipeline_stage_pkg::id_ex_t id_ex_i,

    // Output interface.
    output pipeline_stage_pkg::id_ex_t id_ex_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i     ) id_ex_o <= '0;
        else if (flush_ex_i ) id_ex_o <= '0;
        else if (~stall_ex_i) id_ex_o <= id_ex_i;
    end

endmodule
