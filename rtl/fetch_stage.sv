/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 30/05/2025
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
    input  logic                     stall_if_i,
    input  logic                     instr_we_i,
    input  logic [BLOCK_WIDTH - 1:0] instr_block_i,
    input  logic                     branch_instr_ex_i,
    input  logic                     branch_taken_ex_i,
    input  logic [              1:0] btb_way_ex_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_ex_i,
    input  logic [ADDR_WIDTH  - 1:0] csr_mtvec_read_ex_i,
    input  logic                     exc_detected_wb_i,

    // Output interface.
    output logic [INSTR_WIDTH - 1:0] instruction_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_o,
    output logic [              1:0] btb_way_o,
    output logic                     branch_taken_pred_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_o,
    output logic                     icache_hit_o,
    output logic                     log_trace_o
);

    //-----------------------------
    // Internal nets.
    //-----------------------------
    logic [ADDR_WIDTH - 1:0] pc_plus4;
    logic [ADDR_WIDTH - 1:0] pc_if;
    logic [ADDR_WIDTH - 1:0] pc_regular_flow;
    logic [ADDR_WIDTH - 1:0] pc_d;
    logic [ADDR_WIDTH - 1:0] pc_q;


    // Branch Prediction.
    logic                    branch_taken_pred;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_pred;



    //------------------------------------
    // Lower level modules.
    //------------------------------------
    // 2-to-1 MUX module to choose between PC_PLUS4 & Predicted TA.
    mux2to1 MUX0 (
        .control_signal_i (branch_taken_pred  ),
        .mux_0_i          (pc_plus4           ),
        .mux_1_i          (pc_target_addr_pred),
        .mux_o            (pc_if              )
    );


    // 2-to-1 MUX module to choose between PC from fetch and TA from exec.
    mux2to1 MUX1 (
        .control_signal_i (branch_mispred_i),
        .mux_0_i          (pc_if           ),
        .mux_1_i          (pc_target_addr_i),
        .mux_o            (pc_regular_flow )
    );

    // 2-to-1 MUX module to choose between PC from branch and EXC PC from wb.
    mux2to1 MUX2 (
        .control_signal_i (exc_detected_wb_i  ),
        .mux_0_i          (pc_regular_flow    ),
        .mux_1_i          (csr_mtvec_read_ex_i),
        .mux_o            (pc_d               )
    );

    // PC register.
    register_en # (
        .DATA_WIDTH (ADDR_WIDTH  ),
        .RESET_VAL  (64'h80000000)
    ) PC_REG (
        .clk_i        (clk_i       ),
        .arst_i       (arst_i      ),
        .write_en_i   (~ stall_if_i),
        .write_data_i (pc_d        ),
        .read_data_o  (pc_q        )
    );

    // Adder to calculate next PC value.
    adder ADD4 (
        .input1_i (pc_q    ),
        .input2_i (64'd4   ),
        .sum_o    (pc_plus4)
    );

    // Instruction cache.
    icache # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    )I_CACHE (
        .clk_i         (clk_i        ),
        .arst_i        (arst_i       ),
        .write_en_i    (instr_we_i   ),
        .addr_i        (pc_q         ),
        .instr_block_i (instr_block_i),
        .instruction_o (instruction_o),
        .hit_o         (icache_hit_o )
    );


    //------------------------------------------
    // Branch prediction unit.
    //------------------------------------------
    branch_pred_unit BRANCH_PRED (
        .clk_i                 (clk_i              ),
        .arst_i                (arst_i             ),
        .stall_if_i            (stall_if_i         ),
        .branch_instr_i        (branch_instr_ex_i  ),
        .branch_taken_i        (branch_taken_ex_i  ),
        .way_write_i           (btb_way_ex_i       ),
        .pc_i                  (pc_q               ),
        .pc_ex_i               (pc_ex_i            ),
        .pc_target_addr_ex_i   (pc_target_addr_i   ),
        .branch_pred_taken_o   (branch_taken_pred  ),
        .way_write_o           (btb_way_o          ),
        .pc_target_addr_pred_o (pc_target_addr_pred)
    );

    //------------------------------------------
    // Output signals.
    //------------------------------------------
    assign pc_target_addr_pred_o = pc_target_addr_pred;
    assign branch_taken_pred_o   = branch_taken_pred;
    assign pc_o                  = pc_q;
    assign pc_plus4_o            = pc_plus4;

    assign axi_read_addr_o = pc_q;

    // Log trace.
    assign log_trace_o = 1'b1;

endmodule
