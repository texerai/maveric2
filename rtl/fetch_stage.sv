/* Copyright (c) 2024 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Version      : 2.0.0 
// Create Date  : 10/2024
// Last Revision: 14/03/2025
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the fetch stage.
// ----------------------------------------------------------------------------------------

module fetch_stage 
#(
    parameter ADDR_WIDTH  = 64,
              INSTR_WIDTH = 32,
              BLOCK_WIDTH = 512
) 
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_target,
    input  logic                       i_branch_mispred,
    input  logic                       i_stall_fetch,
    input  logic                       i_instr_we,
    input  logic [ BLOCK_WIDTH - 1:0 ] i_instr_block,
    input  logic                       i_branch_exec,
    input  logic                       i_branch_taken_exec,
    input  logic [               1:0 ] i_btb_way_exec,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_exec,

    // Output interface.
    output logic [ INSTR_WIDTH - 1:0 ] o_instruction,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_plus4,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc,
    output logic [ ADDR_WIDTH  - 1:0 ] o_axi_read_addr,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_target_pred,
    output logic [               1:0 ] o_btb_way,
    output logic                       o_branch_taken_pred,
    output logic                       o_icache_hit
);

    //-----------------------------
    // Internal nets.
    //-----------------------------
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_fetch;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_next;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_reg;


    // Branch Prediction.
    logic                      s_branch_taken_pred;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_pred;



    //------------------------------------
    // Lower level modules.
    //------------------------------------
    // 2-to-1 MUX module to choose between PC_PLUS4 & Predicted TA.
    mux2to1 MUX0 (
        .i_control_signal ( s_branch_taken_pred ),
        .i_mux_0          ( s_pc_plus4          ),
        .i_mux_1          ( s_pc_target_pred    ),
        .o_mux            ( s_pc_fetch          )
    );


    // 2-to-1 MUX module to choose between PC from fetch and TA from exec.
    mux2to1 MUX1 (
        .i_control_signal ( i_branch_mispred ),
        .i_mux_0          ( s_pc_fetch       ),
        .i_mux_1          ( i_pc_target      ),
        .o_mux            ( s_pc_next        )
    );

    // PC register.
    register_en PC_REG (
        .i_clk        ( i_clk            ),
        .i_write_en   ( ~ i_stall_fetch  ),
        .i_arst       ( i_arst           ),
        .i_write_data ( s_pc_next        ),
        .o_read_data  ( s_pc_reg         )
    );

    // Adder to calculate next PC value.
    adder ADD4 (
        .i_input1 ( s_pc_reg   ),
        .i_input2 ( 64'd4      ),
        .o_sum    ( s_pc_plus4 )
    );

    // Instruction cache.
    icache # (
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    )I_CACHE (
        .i_clk         ( i_clk         ),
        .i_arst        ( i_arst        ),
        .i_write_en    ( i_instr_we    ),
        .i_addr        ( s_pc_reg      ),
        .i_instr_block ( i_instr_block ),
        .o_instruction ( o_instruction ),
        .o_hit         ( o_icache_hit  ) 
    );


    //------------------------------------------
    // Branch prediction unit.
    //------------------------------------------
    branch_pred_unit BRANCH_PRED (
        .i_clk               ( i_clk               ),
        .i_arst              ( i_arst              ),
        .i_stall_fetch       ( i_stall_fetch       ),
        .i_branch_instr      ( i_branch_exec       ),
        .i_branch_taken      ( i_branch_taken_exec ),
        .i_way_write         ( i_btb_way_exec      ),
        .i_pc                ( s_pc_reg            ),
        .i_pc_exec           ( i_pc_exec           ),
        .i_pc_target_exec    ( i_pc_target         ),
        .o_branch_pred_taken ( s_branch_taken_pred ),
        .o_way_write         ( o_btb_way           ),
        .o_pc_target_pred    ( s_pc_target_pred    )
    );

    //------------------------------------------
    // Output signals.
    //------------------------------------------
    assign o_pc_target_pred    = s_pc_target_pred;
    assign o_branch_taken_pred = s_branch_taken_pred;
    assign o_pc                = s_pc_reg;
    assign o_pc_plus4          = s_pc_plus4;

    assign o_axi_read_addr  = s_pc_reg;

endmodule