/* Copyright (c) 2024 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 10/2024
// Last Revision: 29/05/2025
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the fetch stage.
// ----------------------------------------------------------------------------------------

module fetch_stage
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_i,
    input  logic                     branch_mispred_i,
    input  logic                     stall_fetch_i,
    input  logic                     instr_we_i,
    input  logic [BLOCK_WIDTH - 1:0] instr_block_i,
    input  logic                     branch_exec_i,
    input  logic                     branch_taken_exec_i,
    input  logic [              1:0] btb_way_exec_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_exec_i,

    // Output interface.
    output logic [INSTR_WIDTH - 1:0] instruction_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_o,
    output logic [              1:0] btb_way_o,
    output logic                     branch_taken_pred_o,
    output logic                     log_trace_o,
    output logic                     icache_hit_o
);

    //-----------------------------
    // Internal nets.
    //-----------------------------
    logic [ADDR_WIDTH - 1:0] pc_plus4_s;
    logic [ADDR_WIDTH - 1:0] pc_fetch_s;
    logic [ADDR_WIDTH - 1:0] pc_next_s;
    logic [ADDR_WIDTH - 1:0] pc_reg_s;


    // Branch Prediction.
    logic                    branch_taken_pred_s;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_pred_s;



    //------------------------------------
    // Lower level modules.
    //------------------------------------
    // 2-to-1 MUX module to choose between PC_PLUS4 & Predicted TA.
    mux2to1 MUX0 (
        .control_signal_i (branch_taken_pred_s  ),
        .mux_0_i          (pc_plus4_s           ),
        .mux_1_i          (pc_target_addr_pred_s),
        .mux_o            (pc_fetch_s           )
    );


    // 2-to-1 MUX module to choose between PC from fetch and TA from exec.
    mux2to1 MUX1 (
        .control_signal_i (branch_mispred_i),
        .mux_0_i          (pc_fetch_s      ),
        .mux_1_i          (pc_target_addr_i),
        .mux_o            (pc_next_s       )
    );

    // PC register.
    register_en # (
        .DATA_WIDTH (ADDR_WIDTH  ),
        .RESET_VAL  (64'h80000000)
    ) PC_REG (
        .clk_i        (clk_i          ),
        .write_en_i   (~ stall_fetch_i),
        .arst_i       (arst_i         ),
        .write_data_i (pc_next_s      ),
        .read_data_o  (pc_reg_s       )
    );

    // Adder to calculate next PC value.
    adder ADD4 (
        .input1_i (pc_reg_s  ),
        .input2_i (64'd4     ),
        .sum_o    (pc_plus4_s)
    );

    // Instruction cache.
    icache # (
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    )I_CACHE (
        .clk_i         (clk_i        ),
        .arst_i        (arst_i       ),
        .write_en_i    (instr_we_i   ),
        .addr_i        (pc_reg_s     ),
        .instr_block_i (instr_block_i),
        .instruction_o (instruction_o),
        .hit_o         (icache_hit_o )
    );


    //------------------------------------------
    // Branch prediction unit.
    //------------------------------------------
    branch_pred_unit BRANCH_PRED (
        .clk_i                 (clk_i                ),
        .arst_i                (arst_i               ),
        .stall_fetch_i         (stall_fetch_i        ),
        .branch_instr_i        (branch_exec_i        ),
        .branch_taken_i        (branch_taken_exec_i  ),
        .way_write_i           (btb_way_exec_i       ),
        .pc_i                  (pc_reg_s             ),
        .pc_exec_i             (pc_exec_i            ),
        .pc_target_addr_exec_i (pc_target_addr_i     ),
        .branch_pred_taken_o   (branch_taken_pred_s  ),
        .way_write_o           (btb_way_o            ),
        .pc_target_addr_pred_o (pc_target_addr_pred_s)
    );

    //------------------------------------------
    // Output signals.
    //------------------------------------------
    assign pc_target_addr_pred_o = pc_target_addr_pred_s;
    assign branch_taken_pred_o   = branch_taken_pred_s;
    assign pc_o                  = pc_reg_s;
    assign pc_plus4_o            = pc_plus4_s;

    assign axi_read_addr_o  = pc_reg_s;

    // Log trace.
    assign log_trace_o = 1'b1;

endmodule
