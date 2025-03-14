/* Copyright (c) 2024 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Version      : 2.0.0 
// Create Date  : 10/2024
// Last Revision: 14/03/2025
//------------------------------

// To-do:
// 1. Change target to target addr.
// 2. Reorder signals.

// ------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units in all stages of the pipeline
// ------------------------------------------------------------------------------------------

module datapath
#(
    parameter ADDR_WIDTH  = 64,
              BLOCK_WIDTH = 512,
              DATA_WIDTH  = 64,
              REG_ADDR_W  = 5,
              INSTR_WIDTH = 32
) 
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic                       i_stall_fetch,
    input  logic                       i_stall_dec,
    input  logic                       i_stall_exec,
    input  logic                       i_stall_mem,
    input  logic                       i_flush_dec,
    input  logic                       i_flush_exec,
    input  logic [               1:0 ] i_forward_rs1, 
    input  logic [               1:0 ] i_forward_rs2, 
    input  logic                       i_instr_we,
    input  logic                       i_dcache_we,
    input  logic [ BLOCK_WIDTH - 1:0 ] i_data_block,

    // Output interface.
    output logic [ REG_ADDR_W  - 1:0 ] o_rs1_addr_dec,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs1_addr_exec,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs2_addr_dec,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs2_addr_exec,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr_exec,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr_mem,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr_wb,
    output logic                       o_reg_we_mem,
    output logic                       o_reg_we_wb,
    output logic                       o_branch_mispred_exec,
    output logic                       o_icache_hit,
    output logic [ ADDR_WIDTH  - 1:0 ] o_axi_read_addr_i,
    output logic [ ADDR_WIDTH  - 1:0 ] o_axi_read_addr_d,
    output logic                       o_dcache_hit,
    output logic                       o_dcache_dirty,
    output logic [ ADDR_WIDTH  - 1:0 ] o_axi_addr_wb,
    output logic [ BLOCK_WIDTH - 1:0 ] o_data_block,
    output logic                       o_mem_access,
    output logic                       o_load_instr_exec
);

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------
    
    // Fetch stage signals: Input interface.
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_target_fetch_i;
    logic                       s_branch_mispred_fetch_i;
    logic                       s_branch_fetch_i;
    logic                       s_branch_taken_fetch_i;
    logic [               1:0 ] s_btb_way_fetch_i;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_fetch_i;

    // Fetch stage signals: Output interface.
    logic [ INSTR_WIDTH - 1:0 ] s_instruction_fetch_o;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_plus4_fetch_o;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_fetch_o;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_target_pred_fetch_o;
    logic [               1:0 ] s_btb_way_fetch_o;
    logic                       s_branch_taken_pred_fetch_o;


    // Decode stage signals: Input interface.
    logic [ INSTR_WIDTH - 1:0 ] s_instruction_dec_i;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_plus4_dec_i;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_dec_i;
    logic [ REG_ADDR_W  - 1:0 ] s_rd_addr_dec_i;
    logic [ DATA_WIDTH  - 1:0 ] s_result_dec_i;
    logic                       s_reg_we_dec_i;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_target_pred_dec_i;
    logic [               1:0 ] s_btb_way_dec_i;
    logic                       s_branch_taken_pred_dec_i;

    // Decode stage signals: Output interface.
    logic [              2:0 ] s_result_src_dec_o;
    logic [              4:0 ] s_alu_control_dec_o;
    logic                      s_mem_we_dec_o;
    logic                      s_reg_we_dec_o;
    logic                      s_alu_src_dec_o;
    logic                      s_branch_dec_o;
    logic                      s_jump_dec_o;
    logic                      s_pc_target_src_dec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_dec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_dec_o;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_dec_o;
    logic [ DATA_WIDTH - 1:0 ] s_rs1_data_dec_o;
    logic [ DATA_WIDTH - 1:0 ] s_rs2_data_dec_o;
    logic [ REG_ADDR_W - 1:0 ] s_rs1_addr_dec_o;
    logic [ REG_ADDR_W - 1:0 ] s_rs2_addr_dec_o;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_dec_o;
    logic [              2:0 ] s_func3_dec_o;
    logic [              1:0 ] s_forward_src_dec_o;
    logic                      s_mem_access_dec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_pred_dec_o;
    logic [              1:0 ] s_btb_way_dec_o;
    logic                      s_branch_taken_pred_dec_o;
    logic                      s_ecall_instr_dec_o;
    logic [              3:0 ] s_cause_dec_o;
    logic                      s_load_instr_dec_o;


    // Execute stage signals: Input interface.
    logic [              2:0 ] s_func3_exec_i;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_exec_i;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_exec_i;
    logic [ DATA_WIDTH - 1:0 ] s_rs1_data_exec_i;
    logic [ DATA_WIDTH - 1:0 ] s_rs2_data_exec_i;
    logic [ REG_ADDR_W - 1:0 ] s_rs1_addr_exec_i;
    logic [ REG_ADDR_W - 1:0 ] s_rs2_addr_exec_i;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_exec_i;
    logic [ DATA_WIDTH - 1:0 ] s_result_exec_i;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_exec_i;
    logic [              2:0 ] s_result_src_exec_i;
    logic [              4:0 ] s_alu_control_exec_i;
    logic                      s_mem_we_exec_i;
    logic                      s_reg_we_exec_i;
    logic                      s_alu_src_exec_i;
    logic                      s_branch_exec_i;
    logic                      s_jump_exec_i;
    logic                      s_pc_target_src_exec_i;
    logic [              1:0 ] s_forward_src_exec_i;
    logic [ DATA_WIDTH - 1:0 ] s_forward_value_exec_i;
    logic                      s_mem_access_exec_i;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_pred_exec_i;
    logic [              1:0 ] s_btb_way_exec_i;
    logic                      s_branch_taken_pred_exec_i;
    logic                      s_ecall_instr_exec_i;
    logic [              3:0 ] s_cause_exec_i;
    logic                      s_load_instr_exec_i;

    // Execute stage signals: Output interface.
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_exec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_new_exec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_exec_o;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_exec_o;
    logic [ DATA_WIDTH - 1:0 ] s_write_data_exec_o;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_exec_o;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_exec_o;
    logic [              2:0 ] s_result_src_exec_o;
    logic [              1:0 ] s_forward_src_exec_o;
    logic                      s_mem_we_exec_o;
    logic                      s_reg_we_exec_o;
    logic                      s_branch_mispred_exec_o;
    logic [              2:0 ] s_func3_exec_o;
    logic                      s_mem_access_exec_o;
    logic                      s_branch_exec_o;
    logic                      s_branch_taken_exec_o;
    logic [              1:0 ] s_btb_way_exec_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_exec_o;
    logic                      s_ecall_instr_exec_o;
    logic [              3:0 ] s_cause_exec_o;


    // Memory stage signals: Input interface.
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_mem_i;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_mem_i;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_mem_i;
    logic [ DATA_WIDTH - 1:0 ] s_write_data_mem_i;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_mem_i;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_mem_i;
    logic [              2:0 ] s_result_src_mem_i;
    logic                      s_mem_we_mem_i;
    logic                      s_reg_we_mem_i;
    logic [              2:0 ] s_func3_mem_i;
    logic [              1:0 ] s_forward_src_mem_i;
    logic                      s_mem_access_mem_i;
    logic                      s_ecall_instr_mem_i;
    logic [              3:0 ] s_cause_mem_i;

    // Memory stage signals: Output interface.
    logic [ DATA_WIDTH - 1:0 ] s_forward_value_mem_o;
    logic [              2:0 ] s_result_src_mem_o;
    logic                      s_reg_we_mem_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_mem_o;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_mem_o;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_mem_o;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_mem_o;
    logic [ DATA_WIDTH - 1:0 ] s_read_data_mem_o;
    logic s_ecall_instr_mem_o;
    logic [              3:0 ] s_cause_mem_o;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_mem_o;


    // Write-back stage signals: Input interface.
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_wb_i;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_wb_i;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_wb_i;
    logic [ DATA_WIDTH - 1:0 ] s_read_data_wb_i;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_wb_i;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_wb_i;
    logic [              2:0 ] s_result_src_wb_i;
    logic                      s_reg_we_wb_i;
    logic                      s_ecall_instr_wb_i;
    logic [              3:0 ] s_cause_wb_i;
    logic                      s_a0_reg_lsb;

    // Write-back stage signals: Input interface.
    logic [ DATA_WIDTH - 1:0 ] s_result_wb_o;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_wb_o;
    logic                      s_reg_we_wb_o;


    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Fetch stage module.
    //-------------------------------------
    fetch_stage # (
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) STAGE1_FETCH (
        .i_clk               ( i_clk                       ),
        .i_arst              ( i_arst                      ),
        .i_pc_target         ( s_pc_target_fetch_i         ),
        .i_branch_mispred    ( s_branch_mispred_fetch_i    ),
        .i_stall_fetch       ( i_stall_fetch               ),
        .i_instr_we          ( i_instr_we                  ),
        .i_instr_block       ( i_data_block                ),
        .i_branch_exec       ( s_branch_fetch_i            ),
        .i_branch_taken_exec ( s_branch_taken_fetch_i      ),
        .i_btb_way_exec      ( s_btb_way_fetch_i           ),
        .i_pc_exec           ( s_pc_fetch_i                ),
        .o_instruction       ( s_instruction_fetch_o       ),
        .o_pc_plus4          ( s_pc_plus4_fetch_o          ),
        .o_pc                ( s_pc_fetch_o                ),
        .o_axi_read_addr     ( o_axi_read_addr_i           ),
        .o_pc_target_pred    ( s_pc_target_pred_fetch_o    ),
        .o_btb_way           ( s_btb_way_fetch_o           ),
        .o_branch_taken_pred ( s_branch_taken_pred_fetch_o ),
        .o_icache_hit        ( o_icache_hit                )
    );

    //------------------------------------------------------------------------------
    // Decode Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    preg_fetch PIPE_DEC ( // RENAME.
        .i_clk               ( i_clk                       ),
        .i_arst              ( i_arst                      ),
        .i_flush_dec         ( i_flush_dec                 ),
        .i_stall_dec         ( i_stall_dec                 ),
        .i_pc_target_pred    ( s_pc_target_pred_fetch_o    ),
        .i_btb_way           ( s_btb_way_fetch_o           ),
        .i_branch_pred_taken ( s_branch_taken_pred_fetch_o ),
        .i_instr             ( s_instruction_fetch_o       ),
        .i_pc                ( s_pc_fetch_o                ),
        .i_pc_plus4          ( s_pc_plus4_fetch_o          ),
        .o_pc_target_pred    ( s_pc_target_pred_dec_i      ),
        .o_btb_way           ( s_btb_way_dec_i             ),
        .o_branch_pred_taken ( s_branch_taken_pred_dec_i   ),
        .o_instr             ( s_instruction_dec_i         ),
        .o_pc                ( s_pc_dec_i                  ),
        .o_pc_plus4          ( s_pc_plus4_dec_i            )
    );

    //-------------------------------------
    // Decode stage module.
    //-------------------------------------
    decode_stage STAGE2_DEC (
        .i_clk               ( i_clk                     ),
        .i_arst              ( i_arst                    ),
        .i_instruction       ( s_instruction_dec_i       ),
        .i_pc_plus4          ( s_pc_plus4_dec_i          ),
        .i_pc                ( s_pc_dec_i                ),
        .i_rd_write_data     ( s_result_dec_i            ),
        .i_rd_addr           ( s_rd_addr_dec_i           ),
        .i_reg_we            ( s_reg_we_dec_i            ),
        .i_pc_target_pred    ( s_pc_target_pred_dec_i    ),
        .i_btb_way           ( s_btb_way_dec_i           ),
        .i_branch_pred_taken ( s_branch_taken_pred_dec_i ),
        .o_func3             ( s_func3_dec_o             ),
        .o_pc                ( s_pc_dec_o                ),
        .o_pc_plus4          ( s_pc_plus4_dec_o          ),
        .o_rs1_data          ( s_rs1_data_dec_o          ),
        .o_rs2_data          ( s_rs2_data_dec_o          ),
        .o_rs1_addr          ( s_rs1_addr_dec_o          ),
        .o_rs2_addr          ( s_rs2_addr_dec_o          ),
        .o_rd_addr           ( s_rd_addr_dec_o           ),
        .o_imm_ext           ( s_imm_ext_dec_o           ),
        .o_result_src        ( s_result_src_dec_o        ),
        .o_alu_control       ( s_alu_control_dec_o       ),
        .o_mem_we            ( s_mem_we_dec_o            ),
        .o_reg_we            ( s_reg_we_dec_o            ),
        .o_alu_src           ( s_alu_src_dec_o           ),
        .o_branch            ( s_branch_dec_o            ),
        .o_jump              ( s_jump_dec_o              ),
        .o_pc_target_src     ( s_pc_target_src_dec_o     ),
        .o_forward_src       ( s_forward_src_dec_o       ),
        .o_mem_access        ( s_mem_access_dec_o        ),
        .o_pc_target_pred    ( s_pc_target_pred_dec_o    ),
        .o_btb_way           ( s_btb_way_dec_o           ),
        .o_branch_pred_taken ( s_branch_taken_pred_dec_o ),
        .o_ecall_instr       ( s_ecall_instr_dec_o       ),
        .o_cause             ( s_cause_dec_o             ),
        .o_a0_reg_lsb        ( s_a0_reg_lsb              ),
        .o_load_instr        ( s_load_instr_dec_o        )
    );

    //-------------------------------------------------------------------------------
    // Execute Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    preg_decode PIPE_EXEC ( // Rename later.
        .i_clk               ( i_clk                      ),
        .i_arst              ( i_arst                     ),
        .i_stall_exec        ( i_stall_exec               ),
        .i_flush_exec        ( i_flush_exec               ),
        .i_result_src        ( s_result_src_dec_o         ),
        .i_alu_control       ( s_alu_control_dec_o        ),
        .i_mem_we            ( s_mem_we_dec_o             ),
        .i_reg_we            ( s_reg_we_dec_o             ),
        .i_alu_src           ( s_alu_src_dec_o            ),
        .i_branch            ( s_branch_dec_o             ),
        .i_jump              ( s_jump_dec_o               ),
        .i_pc_target_src     ( s_pc_target_src_dec_o      ),
        .i_pc_plus4          ( s_pc_plus4_dec_o           ),
        .i_pc                ( s_pc_dec_o                 ),
        .i_imm_ext           ( s_imm_ext_dec_o            ),
        .i_rs1_data          ( s_rs1_data_dec_o           ),
        .i_rs2_data          ( s_rs2_data_dec_o           ),
        .i_rs1_addr          ( s_rs1_addr_dec_o           ),
        .i_rs2_addr          ( s_rs2_addr_dec_o           ),
        .i_rd_addr           ( s_rd_addr_dec_o            ),
        .i_func3             ( s_func3_dec_o              ),
        .i_forward_src       ( s_forward_src_dec_o        ),
        .i_mem_access        ( s_mem_access_dec_o         ),
        .i_pc_target_pred    ( s_pc_target_pred_dec_o     ),
        .i_btb_way           ( s_btb_way_dec_o            ),
        .i_branch_pred_taken ( s_branch_taken_pred_dec_o  ),
        .i_ecall_instr       ( s_ecall_instr_dec_o        ),
        .i_cause             ( s_cause_dec_o              ),
        .i_load_instr        ( s_load_instr_dec_o         ),
        .o_result_src        ( s_result_src_exec_i        ),
        .o_alu_control       ( s_alu_control_exec_i       ),
        .o_mem_we            ( s_mem_we_exec_i            ),
        .o_reg_we            ( s_reg_we_exec_i            ),
        .o_alu_src           ( s_alu_src_exec_i           ),
        .o_branch            ( s_branch_exec_i            ),
        .o_jump              ( s_jump_exec_i              ),
        .o_pc_target_src     ( s_pc_target_src_exec_i     ),
        .o_pc_plus4          ( s_pc_plus4_exec_i          ),
        .o_pc                ( s_pc_exec_i                ),
        .o_imm_ext           ( s_imm_ext_exec_i           ),
        .o_rs1_data          ( s_rs1_data_exec_i          ),
        .o_rs2_data          ( s_rs2_data_exec_i          ),
        .o_rs1_addr          ( s_rs1_addr_exec_i          ),
        .o_rs2_addr          ( s_rs2_addr_exec_i          ),
        .o_rd_addr           ( s_rd_addr_exec_i           ),
        .o_func3             ( s_func3_exec_i             ),
        .o_forward_src       ( s_forward_src_exec_i       ), 
        .o_mem_access        ( s_mem_access_exec_i        ), 
        .o_pc_target_pred    ( s_pc_target_pred_exec_i    ),
        .o_btb_way           ( s_btb_way_exec_i           ),
        .o_branch_pred_taken ( s_branch_taken_pred_exec_i ),
        .o_ecall_instr       ( s_ecall_instr_exec_i       ),
        .o_cause             ( s_cause_exec_i             ),
        .o_load_instr        ( s_load_instr_exec_i        )
    );

    //-------------------------------------
    // Execute stage module.
    //-------------------------------------
    execute_stage STAGE3_EXEC (
        .i_pc                ( s_pc_exec_i                ),
        .i_pc_plus4          ( s_pc_plus4_exec_i          ),
        .i_rs1_data          ( s_rs1_data_exec_i          ),
        .i_rs2_data          ( s_rs2_data_exec_i          ),
        .i_rs1_addr          ( s_rs1_addr_exec_i          ),
        .i_rs2_addr          ( s_rs2_addr_exec_i          ),
        .i_rd_addr           ( s_rd_addr_exec_i           ),
        .i_imm_ext           ( s_imm_ext_exec_i           ),
        .i_func3             ( s_func3_exec_i             ),
        .i_result_src        ( s_result_src_exec_i        ),
        .i_alu_control       ( s_alu_control_exec_i       ),
        .i_mem_we            ( s_mem_we_exec_i            ),
        .i_reg_we            ( s_reg_we_exec_i            ),
        .i_alu_src           ( s_alu_src_exec_i           ),
        .i_branch            ( s_branch_exec_i            ),
        .i_jump              ( s_jump_exec_i              ),
        .i_pc_target_src     ( s_pc_target_src_exec_i     ),
        .i_result            ( s_result_exec_i            ),
        .i_forward_value     ( s_forward_value_exec_i     ),
        .i_forward_src       ( s_forward_src_exec_i       ),
        .i_mem_access        ( s_mem_access_exec_i        ),
        .i_load_instr        ( s_load_instr_exec_i        ),
        .i_forward_rs1_exec  ( i_forward_rs1              ),
        .i_forward_rs2_exec  ( i_forward_rs2              ),
        .i_pc_target_pred    ( s_pc_target_pred_exec_i    ),
        .i_btb_way           ( s_btb_way_exec_i           ),
        .i_ecall_instr       ( s_ecall_instr_exec_i       ),
        .i_cause             ( s_cause_exec_i             ),
        .i_branch_pred_taken ( s_branch_taken_pred_exec_i ),
        .o_pc_plus4          ( s_pc_plus4_exec_o          ),
        .o_pc_new            ( s_pc_new_exec_o            ),
        .o_pc_target         ( s_pc_target_exec_o         ),
        .o_alu_result        ( s_alu_result_exec_o        ),
        .o_write_data        ( s_write_data_exec_o        ),
        .o_rs1_addr          ( o_rs1_addr_exec            ),
        .o_rs2_addr          ( o_rs2_addr_exec            ),
        .o_rd_addr           ( s_rd_addr_exec_o           ),
        .o_imm_ext           ( s_imm_ext_exec_o           ),
        .o_result_src        ( s_result_src_exec_o        ),
        .o_forward_src       ( s_forward_src_exec_o       ),
        .o_mem_we            ( s_mem_we_exec_o            ),
        .o_reg_we            ( s_reg_we_exec_o            ),
        .o_branch_mispred    ( s_branch_mispred_exec_o    ),
        .o_func3             ( s_func3_exec_o             ),
        .o_mem_access        ( s_mem_access_exec_o        ),
        .o_branch_exec       ( s_branch_exec_o            ),
        .o_branch_taken_exec ( s_branch_taken_exec_o      ),
        .o_btb_way_exec      ( s_btb_way_exec_o           ),
        .o_pc_exec           ( s_pc_exec_o                ),
        .o_ecall_instr       ( s_ecall_instr_exec_o       ),
        .o_cause             ( s_cause_exec_o             ),
        .o_load_instr        ( o_load_instr_exec          )
    );

    assign s_pc_target_fetch_i = s_pc_new_exec_o;
    assign s_branch_mispred_fetch_i = s_branch_mispred_exec_o;
    assign s_branch_fetch_i = s_branch_exec_o;
    assign s_branch_taken_fetch_i = s_branch_taken_exec_o;
    assign s_btb_way_fetch_i = s_btb_way_exec_o;
    assign s_pc_fetch_i = s_pc_exec_o;

    //-----------------------------------------------------------------
    // Memory Pipeline Register. With additional signals for stalling.
    //-----------------------------------------------------------------
    preg_execute PIPE_MEM ( // Rename later.
        .i_clk         ( i_clk                ),
        .i_arst        ( i_arst               ),
        .i_stall_mem   ( i_stall_mem          ),
        .i_result_src  ( s_result_src_exec_o  ),
        .i_mem_we      ( s_mem_we_exec_o      ),
        .i_reg_we      ( s_reg_we_exec_o      ),
        .i_pc_plus4    ( s_pc_plus4_exec_o    ),
        .i_pc_target   ( s_pc_target_exec_o   ),
        .i_imm_ext     ( s_imm_ext_exec_o     ),
        .i_alu_result  ( s_alu_result_exec_o  ),
        .i_write_data  ( s_write_data_exec_o  ),
        .i_forward_src ( s_forward_src_exec_o ),
        .i_func3       ( s_func3_exec_o       ),
        .i_mem_access  ( s_mem_access_exec_o  ),
        .i_ecall_instr ( s_ecall_instr_exec_o ),
        .i_cause       ( s_cause_exec_o       ),
        .i_rd_addr     ( s_rd_addr_exec_o     ),
        .o_result_src  ( s_result_src_mem_i   ),
        .o_mem_we      ( s_mem_we_mem_i       ),
        .o_reg_we      ( s_reg_we_mem_i       ),
        .o_pc_plus4    ( s_pc_plus4_mem_i     ),
        .o_pc_target   ( s_pc_target_mem_i    ),
        .o_imm_ext     ( s_imm_ext_mem_i      ),
        .o_alu_result  ( s_alu_result_mem_i   ),
        .o_write_data  ( s_write_data_mem_i   ),
        .o_forward_src ( s_forward_src_mem_i  ),
        .o_func3       ( s_func3_mem_i        ),
        .o_mem_access  ( s_mem_access_mem_i   ),
        .o_ecall_instr ( s_ecall_instr_mem_i  ),
        .o_cause       ( s_cause_mem_i        ),
        .o_rd_addr     ( s_rd_addr_mem_i      )
    );


    //--------------------------------------------
    // For checking branch prediction accuracy.
    //--------------------------------------------
    logic [ 15:0 ] s_branch_count;
    logic [ 15:0 ] s_branch_mispred_count;

    always_ff @( posedge i_clk, posedge i_arst ) begin : BRANCH_ACCURACY_CHECK
        if      ( i_arst                           ) s_branch_count <= '0;
        else if ( ~ i_stall_fetch & s_branch_fetch_i ) s_branch_count <= s_branch_count + 15'b1; 

        if      ( i_arst                                     ) s_branch_mispred_count <= '0;
        else if ( ~ i_stall_fetch & s_branch_mispred_fetch_i ) s_branch_mispred_count <= s_branch_mispred_count + 15'b1;
    end


    //-------------------------------------
    // Memory stage module.
    //-------------------------------------
    memory_stage #(
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) STAGE4_MEM (
        .i_clk             ( i_clk                 ),
        .i_arst            ( i_arst                ),
        .i_pc_plus4        ( s_pc_plus4_mem_i      ),
        .i_pc_target       ( s_pc_target_mem_i     ),
        .i_alu_result      ( s_alu_result_mem_i    ),
        .i_write_data      ( s_write_data_mem_i    ),
        .i_rd_addr         ( s_rd_addr_mem_i       ),
        .i_imm_ext         ( s_imm_ext_mem_i       ),
        .i_result_src      ( s_result_src_mem_i    ),
        .i_mem_we          ( s_mem_we_mem_i        ),
        .i_forward_src     ( s_forward_src_mem_i   ),
        .i_func3           ( s_func3_mem_i         ),
        .i_reg_we          ( s_reg_we_mem_i        ),
        .i_mem_block_we    ( i_dcache_we           ),
        .i_data_block      ( i_data_block          ),
        .i_ecall_instr     ( s_ecall_instr_mem_i   ),
        .i_cause           ( s_cause_mem_i         ),
        .i_mem_access      ( s_mem_access_mem_i    ),
        .o_pc_plus4        ( s_pc_plus4_mem_o      ),
        .o_pc_target       ( s_pc_target_mem_o     ),
        .o_forward_value   ( s_forward_value_mem_o ),
        .o_alu_result      ( s_alu_result_mem_o    ),
        .o_read_data       ( s_read_data_mem_o     ),
        .o_rd_addr         ( s_rd_addr_mem_o       ),
        .o_imm_ext         ( s_imm_ext_mem_o       ),
        .o_result_src      ( s_result_src_mem_o    ),
        .o_dcache_hit      ( o_dcache_hit          ),
        .o_dcache_dirty    ( o_dcache_dirty        ),
        .o_axi_addr_wb     ( o_axi_addr_wb         ),
        .o_data_block      ( o_data_block          ),
        .o_ecall_instr     ( s_ecall_instr_mem_o   ),
        .o_cause           ( s_cause_mem_o         ),
        .o_reg_we          ( s_reg_we_mem_o        )
    );

    assign o_axi_read_addr_d     = s_alu_result_mem_i;
    assign o_mem_access          = s_mem_access_mem_i;
    assign s_forward_value_exec_i = s_forward_value_mem_o;


    //-------------------------------------------
    // Pipeline register for memory stage.
    //-------------------------------------------
    preg_memory PIPE_WB ( //Rename later.
        .i_clk         ( i_clk               ),
        .i_arst        ( i_arst              ),
        .i_stall_wb    ( i_stall_mem         ),
        .i_result_src  ( s_result_src_mem_o  ),
        .i_reg_we      ( s_reg_we_mem_o      ),
        .i_pc_plus4    ( s_pc_plus4_mem_o    ),
        .i_pc_target   ( s_pc_target_mem_o   ),
        .i_imm_ext     ( s_imm_ext_mem_o     ),
        .i_alu_result  ( s_alu_result_mem_o  ),
        .i_read_data   ( s_read_data_mem_o   ),
        .i_ecall_instr ( s_ecall_instr_mem_o ),
        .i_cause       ( s_cause_mem_o       ),
        .i_rd_addr     ( s_rd_addr_mem_o     ),
        .o_result_src  ( s_result_src_wb_i   ),
        .o_reg_we      ( s_reg_we_wb_i       ),
        .o_pc_plus4    ( s_pc_plus4_wb_i     ),
        .o_pc_target   ( s_pc_target_wb_i    ),
        .o_imm_ext     ( s_imm_ext_wb_i      ),
        .o_alu_result  ( s_alu_result_wb_i   ),
        .o_read_data   ( s_read_data_wb_i    ),
        .o_ecall_instr ( s_ecall_instr_wb_i  ),
        .o_cause       ( s_cause_wb_i        ),
        .o_rd_addr     ( s_rd_addr_wb_i      )
    );

    //-------------------------------------
    // Write-back stage module.
    //-------------------------------------
    write_back_stage STAGE5_WB (
        .i_pc_plus4       ( s_pc_plus4_wb_i        ),
        .i_pc_target      ( s_pc_target_wb_i       ),
        .i_alu_result     ( s_alu_result_wb_i      ),
        .i_read_data      ( s_read_data_wb_i       ),
        .i_rd_addr        ( s_rd_addr_wb_i         ),
        .i_imm_ext        ( s_imm_ext_wb_i         ),
        .i_result_src     ( s_result_src_wb_i      ),
        .i_ecall_instr    ( s_ecall_instr_wb_i     ),
        .i_cause          ( s_cause_wb_i           ),
        .i_branch_total   ( s_branch_count         ),
        .i_branch_mispred ( s_branch_mispred_count ), 
        .i_a0_reg_lsb     ( s_a0_reg_lsb           ),
        .i_reg_we         ( s_reg_we_wb_i          ),
        .o_result         ( s_result_wb_o          ),
        .o_rd_addr        ( s_rd_addr_wb_o         ),
        .o_reg_we         ( s_reg_we_wb_o          )
    );

    assign s_rd_addr_dec_i = s_rd_addr_wb_o;
    assign s_reg_we_dec_i  = s_reg_we_wb_o;
    assign s_result_dec_i  = s_result_wb_o;
    assign s_result_exec_i = s_result_wb_o; 


    //-------------------------------------------------------------
    // Continious assignment of outputs.
    //-------------------------------------------------------------
    assign o_rd_addr_wb          = s_rd_addr_wb_o;
    assign o_reg_we_mem          = s_reg_we_mem_i;
    assign o_reg_we_wb           = s_reg_we_wb_i;
    assign o_branch_mispred_exec = s_branch_mispred_fetch_i;

    // Dec2Exec.
    assign o_rs1_addr_dec = s_rs1_addr_dec_o;
    assign o_rs2_addr_dec = s_rs2_addr_dec_o;

    // Exec2Mem.
    assign o_rd_addr_exec = s_rd_addr_exec_o;

    // Mem2WB.
    assign o_rd_addr_mem = s_rd_addr_mem_o;

endmodule