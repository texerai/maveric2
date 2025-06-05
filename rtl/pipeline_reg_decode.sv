/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------------------
// This is a nonarchitectural register file with stall and flush signals for fetch stage pipelining.
// --------------------------------------------------------------------------------------------------

module pipeline_reg_decode
// Parameters.
#(
    parameter DATA_WIDTH  = 64,
    parameter ADDR_WIDTH  = 64,
    parameter INSTR_WIDTH = 32
)
// Port decleration.
(
    //Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     flush_dec_i,
    input  logic                     stall_dec_i,
    input  logic                     log_trace_i,
    input  logic                     branch_pred_taken_i,
    input  logic [              1:0] btb_way_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_i,
    input  logic [INSTR_WIDTH - 1:0] instr_i,
    input  logic [DATA_WIDTH  - 1:0] pc_i,
    input  logic [DATA_WIDTH  - 1:0] pc_plus4_i,
    
    // Output interface.
    output logic                     log_trace_o,
    output logic                     branch_pred_taken_o,
    output logic [              1:0] btb_way_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_o,
    output logic [INSTR_WIDTH - 1:0] instr_o,
    output logic [DATA_WIDTH  - 1:0] pc_o,
    output logic [DATA_WIDTH  - 1:0] pc_plus4_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            log_trace_o           <= '0;
            branch_pred_taken_o   <= '0;
            btb_way_o             <= '0;
            pc_target_addr_pred_o <= '0;
            instr_o               <= '0;
            pc_o                  <= '0;
            pc_plus4_o            <= '0;
        end
        else if (flush_dec_i) begin
            log_trace_o           <= '0;
            branch_pred_taken_o   <= '0;
            btb_way_o             <= '0;
            pc_target_addr_pred_o <= '0;
            instr_o               <= '0;
            pc_o                  <= '0;
            pc_plus4_o            <= '0;
        end
        else if (~ stall_dec_i) begin
            log_trace_o           <= log_trace_i;
            branch_pred_taken_o   <= branch_pred_taken_i;
            btb_way_o             <= btb_way_i;
            pc_target_addr_pred_o <= pc_target_addr_pred_i;
            instr_o               <= instr_i;
            pc_o                  <= pc_i;
            pc_plus4_o            <= pc_plus4_i;
        end
    end

endmodule
