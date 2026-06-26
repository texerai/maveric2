/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/06/2026
//------------------------------

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file for memory stage pipelining.
// ------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module pipeline_reg_write_back
// Port decleration.
(
    //Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        stall_wb_i,
    input  pipeline_stage_pkg::mem_wb_t mem_wb_i,

    // Output interface.
    output pipeline_stage_pkg::mem_wb_t mem_wb_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            mem_wb_o <= '0;
        end else if (~stall_wb_i) begin
            mem_wb_o <= mem_wb_i;
        end else begin
            mem_wb_o.log_trace <= '0;
        end
    end

endmodule
