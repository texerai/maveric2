/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the memory stage.
// ----------------------------------------------------------------------------------------

module memory_stage
#(
    parameter ADDR_WIDTH  = 64,
              DATA_WIDTH  = 64,
              BLOCK_WIDTH = 512,
              REG_ADDR_W  = 5
) 
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic                       i_stall_wb,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_plus4,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_target,
    input  logic [ DATA_WIDTH  - 1:0 ] i_alu_result,
    input  logic [ DATA_WIDTH  - 1:0 ] i_write_data,
    input  logic [ REG_ADDR_W  - 1:0 ] i_rd_addr,
    input  logic [ DATA_WIDTH  - 1:0 ] i_imm_ext,
    input  logic [               2:0 ] i_result_src,
    input  logic                       i_mem_we,
    input  logic                       i_reg_we,
    input  logic [               2:0 ] i_func3,
    input  logic [               1:0 ] i_forward_src,
    input  logic                       i_mem_block_we,
    input  logic [ BLOCK_WIDTH - 1:0 ] i_data_block,
    input  logic                       i_ecall_instr,
    input  logic [               3:0 ] i_cause,
    input  logic                       i_mem_access,

    // Output interface.
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_plus4,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_target,
    output logic [ DATA_WIDTH  - 1:0 ] o_forward_value,
    output logic [ DATA_WIDTH  - 1:0 ] o_alu_result,
    output logic [ DATA_WIDTH  - 1:0 ] o_read_data,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr_preg,
    output logic [ DATA_WIDTH  - 1:0 ] o_imm_ext,
    output logic [               2:0 ] o_result_src,
    output logic                       o_dcache_hit,
    output logic                       o_dcache_dirty,
    output logic [ ADDR_WIDTH  - 1:0 ] o_axi_addr_wb,
    output logic [ BLOCK_WIDTH - 1:0 ] o_data_block,
    output logic                       o_ecall_instr,
    output logic [               3:0 ] o_cause,
    output logic                       o_reg_we
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [ DATA_WIDTH - 1:0 ] s_read_mem;
    logic [ DATA_WIDTH - 1:0 ] s_read_data;

    logic s_dcache_hit;
    logic s_reg_we;

    logic         s_load_addr_ma;
    logic [ 3:0 ] s_cause;
    logic         s_call_load_addr_ma;
    logic         s_ecall_instr;

    logic s_store_addr_ma;

    assign s_call_load_addr_ma = i_mem_access & s_load_addr_ma;
    assign s_ecall_instr       = i_ecall_instr | s_call_load_addr_ma | s_store_addr_ma;
    assign s_cause             = ( i_ecall_instr ) ? i_cause : ( s_store_addr_ma ) ? 4'd6 : 4'd4; // 6: Store addr misaligned, 4: Load address misaligned.

    assign s_reg_we = ( i_reg_we & s_dcache_hit & i_mem_access ) | ( i_reg_we & ( ~ i_mem_access ) );

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Data memory.
    dcache # (
        .SET_WIDTH ( BLOCK_WIDTH )  
    ) DATA_CACHE (
        .i_clk           ( i_clk           ),
        .i_arst          ( i_arst          ),
        .i_write_en      ( i_mem_we        ),
        .i_block_we      ( i_mem_block_we  ),
        .i_mem_access    ( i_mem_access    ),
        .i_store_type    ( i_func3 [ 1:0 ] ),
        .i_addr          ( i_alu_result    ), 
        .i_data_block    ( i_data_block    ),
        .i_write_data    ( i_write_data    ),
        .o_hit           ( s_dcache_hit    ),
        .o_dirty         ( o_dcache_dirty  ),
        .o_addr_wb       ( o_axi_addr_wb   ),
        .o_data_block    ( o_data_block    ),
        .o_store_addr_ma ( s_store_addr_ma ),
        .o_read_data     ( s_read_mem      )
    );


    // Load MUX.
    load_mux LMUX0 (
        .i_func3        ( i_func3              ),
        .i_data         ( s_read_mem           ),
        .i_addr_offset  ( i_alu_result [ 2:0 ] ),
        .o_load_addr_ma ( s_load_addr_ma       ),
        .o_data         ( s_read_data          )
    );

    // Forwarding value MUX.
    mux3to1 MUX0 (
        .i_control_signal ( i_forward_src   ),
        .i_mux_0          ( i_alu_result    ),
        .i_mux_1          ( i_pc_target     ),
        .i_mux_2          ( i_imm_ext       ),
        .o_mux            ( o_forward_value )
    );


    //-------------------------------------------
    // Pipeline register for memory stage.
    //-------------------------------------------
    preg_memory PREG_M0 (
        .i_clk        ( i_clk          ),
        .i_arst       ( i_arst         ),
        .i_stall_wb   ( i_stall_wb     ),
        .i_result_src ( i_result_src   ),
        .i_reg_we     ( s_reg_we       ),
        .i_pc_plus4   ( i_pc_plus4     ),
        .i_pc_target  ( i_pc_target    ),
        .i_imm_ext    ( i_imm_ext      ),
        .i_alu_result ( i_alu_result   ),
        .i_read_data  ( s_read_data    ),
        .i_ecall_instr ( s_ecall_instr  ),
        .i_cause       ( s_cause        ),
        .i_rd_addr    ( i_rd_addr      ),
        .o_result_src ( o_result_src   ),
        .o_reg_we     ( o_reg_we       ),
        .o_pc_plus4   ( o_pc_plus4     ),
        .o_pc_target  ( o_pc_target    ),
        .o_imm_ext    ( o_imm_ext      ),
        .o_alu_result ( o_alu_result   ),
        .o_read_data  ( o_read_data    ),
        .o_ecall_instr ( o_ecall_instr  ),
        .o_cause       ( o_cause        ),
        .o_rd_addr    ( o_rd_addr_preg )
    );

    //--------------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------------
    assign o_rd_addr    = i_rd_addr;
    assign o_dcache_hit = s_dcache_hit;

endmodule