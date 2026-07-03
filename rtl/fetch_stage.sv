/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 30/06/2026
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the fetch stage.
// ----------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"
`include "maveric_pkg.sv"

module fetch_stage
// Parameters.
#(
    parameter XLEN        = maveric_pkg::XLEN,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic [XLEN        - 1:0] pc_target_addr_i,
    input  logic                     branch_mispred_i,
    input  logic                     stall_if_i,
    input  logic                     instr_we_i,
    input  logic                     invalidate_cache_mem_i,
    input  logic [BLOCK_WIDTH - 1:0] instr_block_i,
    input  logic                     branch_instr_ex_i,
    input  logic                     branch_taken_ex_i,
    input  logic [              1:0] btb_way_ex_i,
    input  logic [XLEN        - 1:0] pc_ex_i,
    input  logic [XLEN        - 1:0] pc_fencei_mem_i,
    input  logic [XLEN        - 1:0] csr_xtvec_rdata_ex_i,
    input  logic                     trap_detected_wb_i,
    input  logic [XLEN        - 1:0] csr_xepc_rdata_ex_i,
    input  logic                     trap_return_wb_i,

    // Output interface.
    output pipeline_stage_pkg::if_id_t if_id_o,
    output logic [XLEN          - 1:0] axi_raddr_o,
    output logic                       icache_hit_o
);

    //-----------------------------
    // Internal nets.
    //-----------------------------
    logic [XLEN - 1:0] pc_plus4;
    logic [XLEN - 1:0] pc_if;
    logic [XLEN - 1:0] pc_regular_flow;
    logic [XLEN - 1:0] pc;
    logic [XLEN - 1:0] pc_d;
    logic [XLEN - 1:0] pc_q;


    // Branch Prediction.
    logic                    branch_taken_pred;
    logic [XLEN       - 1:0] pc_target_addr_pred;



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

    mux2to1 MUX3 (
        .control_signal_i (invalidate_cache_mem_i),
        .mux_0_i          (pc_regular_flow       ),
        .mux_1_i          (pc_fencei_mem_i       ),
        .mux_o            (pc                    )
    );

    // 2-to-1 MUX module to choose between
    // - PC from branch
    // - EXC PC from xtvec.
    // - MRET PC from xepc.
    mux3to1 MUX2 (
        .control_signal_i ({trap_return_wb_i, trap_detected_wb_i}),
        .mux_0_i          (pc                                    ),
        .mux_1_i          (csr_xtvec_rdata_ex_i                  ),
        .mux_2_i          (csr_xepc_rdata_ex_i                   ),
        .mux_o            (pc_d                                  )
    );

    // PC register.
    register_en # (
        .DATA_WIDTH (XLEN        ),
        .RESET_VAL  (64'h80000000)
    ) PC_REG (
        .clk_i   (clk_i        ),
        .arst_i  (arst_i       ),
        .we_i    ((~stall_if_i)),
        .wdata_i (pc_d         ),
        .rdata_o (pc_q         )
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
        .clk_i         (clk_i                 ),
        .arst_i        (arst_i                ),
        .we_i          (instr_we_i            ),
        .invalidate_i  (invalidate_cache_mem_i),
        .addr_i        (pc_q                  ),
        .instr_block_i (instr_block_i         ),
        .instruction_o (if_id_o.instruction   ),
        .hit_o         (icache_hit_o          )
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
        .way_write_o           (if_id_o.btb_way    ),
        .pc_target_addr_pred_o (pc_target_addr_pred)
    );

    //------------------------------------------
    // Output signals.
    //------------------------------------------
    assign if_id_o.valid               = icache_hit_o;
    assign if_id_o.pc_target_addr_pred = pc_target_addr_pred;
    assign if_id_o.branch_pred_taken   = branch_taken_pred;
    assign if_id_o.pc                  = pc_q;
    assign if_id_o.pc_plus4            = pc_plus4;

    assign axi_raddr_o = pc_q;

    // Log trace.
    assign if_id_o.log_trace = 1'b1;

endmodule
