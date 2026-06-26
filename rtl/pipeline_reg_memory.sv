/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/06/2026
//------------------------------

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file for execute stage pipelining.
// ------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module pipeline_reg_memory
// Port decleration.
(
    //Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        stall_mem_i,
    input  logic                        flush_mem_i,
    input  pipeline_stage_pkg::ex_mem_t ex_mem_i,

    // Output interface.
    output pipeline_stage_pkg::ex_mem_t ex_mem_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i      ) ex_mem_o <= '0;
        else if (flush_mem_i ) ex_mem_o <= '0;
        else if (~stall_mem_i) ex_mem_o <= ex_mem_i;
    end

endmodule
