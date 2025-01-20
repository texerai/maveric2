/* Copyright (c) 2024 Maveric NU. All rights reserved. */

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
    
    // Fetch stage signals.
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_fetch;
    logic                      s_branch_mispred_fetch;
    logic                      s_branch_fetch;
    logic                      s_branch_taken_fetch;
    logic [              1:0 ] s_btb_way_fetch;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_fetch;


    // Decode stage signals.
    logic [ INSTR_WIDTH - 1:0 ] s_instruction_dec;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_plus4_dec;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_dec;
    logic [ REG_ADDR_W  - 1:0 ] s_rd_addr_dec;
    logic                       s_reg_we_dec;
    logic                       s_load_instr_exec;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_target_pred_dec;
    logic [               1:0 ] s_btb_way_dec;
    logic                       s_branch_pred_taken_dec;


    // Execute stage signals.
    logic [              2:0 ] s_func3_exec;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_exec;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_exec;
    logic [ DATA_WIDTH - 1:0 ] s_rs1_data_exec;
    logic [ DATA_WIDTH - 1:0 ] s_rs2_data_exec;
    logic [ REG_ADDR_W - 1:0 ] s_rs1_addr_exec;
    logic [ REG_ADDR_W - 1:0 ] s_rs2_addr_exec;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_exec;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_exec;
    logic [              2:0 ] s_result_src_exec;
    logic [              4:0 ] s_alu_control_exec;
    logic                      s_mem_we_exec;
    logic                      s_reg_we_exec;
    logic                      s_alu_src_exec;
    logic                      s_branch_exec;
    logic                      s_jump_exec;
    logic                      s_pc_target_src_exec;
    logic [              1:0 ] s_forward_src_exec;
    logic [ DATA_WIDTH - 1:0 ] s_forward_value_exec;
    logic                      s_mem_access_exec;
    logic [ ADDR_WIDTH  - 1:0 ] s_pc_target_pred_exec;
    logic [               1:0 ] s_btb_way_exec;
    logic                       s_branch_pred_taken_exec;
    logic                       s_ecall_instr_exec;
    logic [               3:0 ] s_cause_exec;


    // Memory stage signals.
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_mem;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_mem;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_mem;
    logic [ DATA_WIDTH - 1:0 ] s_write_data_mem;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_mem;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_mem;
    logic [              2:0 ] s_result_src_mem;
    logic                      s_mem_we_mem;
    logic                      s_reg_we_mem;
    logic [              2:0 ] s_func3_mem;
    logic [              1:0 ] s_forward_src_mem;
    logic                      s_mem_access_mem;
    logic                      s_ecall_instr_mem;
    logic [              3:0 ] s_cause_mem;


    // Write-back stage signals.
    logic [ DATA_WIDTH - 1:0 ] s_result_wb;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_plus4_wb;
    logic [ ADDR_WIDTH - 1:0 ] s_pc_target_wb;
    logic [ DATA_WIDTH - 1:0 ] s_alu_result_wb;
    logic [ DATA_WIDTH - 1:0 ] s_read_data_wb;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr_wb;
    logic [ DATA_WIDTH - 1:0 ] s_imm_ext_wb;
    logic [              2:0 ] s_result_src_wb;
    logic                      s_reg_we_wb;
    logic                      s_ecall_instr_wb;
    logic [              3:0 ] s_cause_wb;
    logic                      s_a0_reg_lsb_wb;


    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Fetch stage module.
    //-------------------------------------
    fetch_stage # (
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) STAGE1_FETCH (
        .i_clk               ( i_clk                   ),
        .i_arst              ( i_arst                  ),
        .i_pc_target         ( s_pc_target_fetch       ),
        .i_branch_mispred    ( s_branch_mispred_fetch  ),
        .i_stall_fetch       ( i_stall_fetch           ),
        .i_stall_dec         ( i_stall_dec             ),
        .i_flush_dec         ( i_flush_dec             ),
        .i_instr_we          ( i_instr_we              ),
        .i_instr_block       ( i_data_block            ),
        .i_branch_exec       ( s_branch_fetch          ),
        .i_branch_taken_exec ( s_branch_taken_fetch    ),
        .i_btb_way_exec      ( s_btb_way_fetch         ),
        .i_pc_exec           ( s_pc_fetch              ),
        .o_instruction       ( s_instruction_dec       ),
        .o_pc_plus4          ( s_pc_plus4_dec          ),
        .o_pc                ( s_pc_dec                ),
        .o_axi_read_addr     ( o_axi_read_addr_i       ),
        .o_pc_target_pred    ( s_pc_target_pred_dec    ),
        .o_btb_way           ( s_btb_way_dec           ),
        .o_branch_pred_taken ( s_branch_pred_taken_dec ),
        .o_icache_hit        ( o_icache_hit            )
    );


    //-------------------------------------
    // Decode stage module.
    //-------------------------------------
    decode_stage STAGE2_DEC (
        .i_clk               ( i_clk                    ),
        .i_arst              ( i_arst                   ),
        .i_instruction       ( s_instruction_dec        ),
        .i_pc_plus4          ( s_pc_plus4_dec           ),
        .i_pc                ( s_pc_dec                 ),
        .i_rd_write_data     ( s_result_wb              ),
        .i_rd_addr           ( s_rd_addr_dec            ),
        .i_reg_we            ( s_reg_we_dec             ),
        .i_stall_exec        ( i_stall_exec             ),
        .i_flush_exec        ( i_flush_exec             ),
        .i_pc_target_pred    ( s_pc_target_pred_dec     ),
        .i_btb_way           ( s_btb_way_dec            ),
        .i_branch_pred_taken ( s_branch_pred_taken_dec  ),
        .o_func3             ( s_func3_exec             ),
        .o_pc                ( s_pc_exec                ),
        .o_pc_plus4          ( s_pc_plus4_exec          ),
        .o_rs1_data          ( s_rs1_data_exec          ),
        .o_rs2_data          ( s_rs2_data_exec          ),
        .o_rs1_addr          ( o_rs1_addr_dec           ),
        .o_rs2_addr          ( o_rs2_addr_dec           ),
        .o_rs1_addr_preg     ( s_rs1_addr_exec          ),
        .o_rs2_addr_preg     ( s_rs2_addr_exec          ),
        .o_rd_addr           ( s_rd_addr_exec           ),
        .o_imm_ext           ( s_imm_ext_exec           ),
        .o_result_src        ( s_result_src_exec        ),
        .o_alu_control       ( s_alu_control_exec       ),
        .o_mem_we            ( s_mem_we_exec            ),
        .o_reg_we            ( s_reg_we_exec            ),
        .o_alu_src           ( s_alu_src_exec           ),
        .o_branch            ( s_branch_exec            ),
        .o_jump              ( s_jump_exec              ),
        .o_pc_target_src     ( s_pc_target_src_exec     ),
        .o_forward_src       ( s_forward_src_exec       ),
        .o_mem_access        ( s_mem_access_exec        ),
        .o_pc_target_pred    ( s_pc_target_pred_exec    ),
        .o_btb_way           ( s_btb_way_exec           ),
        .o_branch_pred_taken ( s_branch_pred_taken_exec ),
        .o_ecall_instr       ( s_ecall_instr_exec       ),
        .o_cause             ( s_cause_exec             ),
        .o_a0_reg_lsb        ( s_a0_reg_lsb_wb          ),
        .o_load_instr        ( s_load_instr_exec        )
    );

    //-------------------------------------
    // Execute stage module.
    //-------------------------------------
    execute_stage STAGE3_EXEC (
        .i_clk               ( i_clk                    ),
        .i_arst              ( i_arst                   ),
        .i_stall_mem         ( i_stall_mem              ),
        .i_pc                ( s_pc_exec                ),
        .i_pc_plus4          ( s_pc_plus4_exec          ),
        .i_rs1_data          ( s_rs1_data_exec          ),
        .i_rs2_data          ( s_rs2_data_exec          ),
        .i_rs1_addr          ( s_rs1_addr_exec          ),
        .i_rs2_addr          ( s_rs2_addr_exec          ),
        .i_rd_addr           ( s_rd_addr_exec           ),
        .i_imm_ext           ( s_imm_ext_exec           ),
        .i_func3             ( s_func3_exec             ),
        .i_result_src        ( s_result_src_exec        ),
        .i_alu_control       ( s_alu_control_exec       ),
        .i_mem_we            ( s_mem_we_exec            ),
        .i_reg_we            ( s_reg_we_exec            ),
        .i_alu_src           ( s_alu_src_exec           ),
        .i_branch            ( s_branch_exec            ),
        .i_jump              ( s_jump_exec              ),
        .i_pc_target_src     ( s_pc_target_src_exec     ),
        .i_result            ( s_result_wb              ),
        .i_forward_value     ( s_forward_value_exec     ),
        .i_forward_src       ( s_forward_src_exec       ),
        .i_mem_access        ( s_mem_access_exec        ),
        .i_load_instr        ( s_load_instr_exec        ),
        .i_forward_rs1_exec  ( i_forward_rs1            ),
        .i_forward_rs2_exec  ( i_forward_rs2            ),
        .i_pc_target_pred    ( s_pc_target_pred_exec    ),
        .i_btb_way           ( s_btb_way_exec           ),
        .i_ecall_instr       ( s_ecall_instr_exec       ),
        .i_cause             ( s_cause_exec             ),
        .i_branch_pred_taken ( s_branch_pred_taken_exec ),
        .o_pc_plus4          ( s_pc_plus4_mem           ),
        .o_pc_target         ( s_pc_target_fetch        ),
        .o_pc_target_preg    ( s_pc_target_mem          ),
        .o_alu_result        ( s_alu_result_mem         ),
        .o_write_data        ( s_write_data_mem         ),
        .o_rs1_addr          ( o_rs1_addr_exec          ),
        .o_rs2_addr          ( o_rs2_addr_exec          ),
        .o_rd_addr           ( o_rd_addr_exec           ),
        .o_rd_addr_preg      ( s_rd_addr_mem            ),
        .o_imm_ext           ( s_imm_ext_mem            ),
        .o_result_src        ( s_result_src_mem         ),
        .o_forward_src       ( s_forward_src_mem        ),
        .o_mem_we            ( s_mem_we_mem             ),
        .o_reg_we            ( s_reg_we_mem             ),
        .o_branch_mispred    ( s_branch_mispred_fetch   ),
        .o_func3             ( s_func3_mem              ),
        .o_mem_access        ( s_mem_access_mem         ),
        .o_branch_exec       ( s_branch_fetch           ),
        .o_branch_taken_exec ( s_branch_taken_fetch     ),
        .o_btb_way_exec      ( s_btb_way_fetch          ),
        .o_pc_exec           ( s_pc_fetch               ),
        .o_ecall_instr       ( s_ecall_instr_mem        ),
        .o_cause             ( s_cause_mem              ),
        .o_load_instr        ( o_load_instr_exec        )
    );


    //--------------------------------------------
    // For checking branch prediction accuracy.
    //--------------------------------------------
    logic [ 15:0 ] s_branch_count;
    logic [ 15:0 ] s_branch_mispred_count;

    always_ff @( posedge i_clk, posedge i_arst ) begin : BRANCH_ACCURACY_CHECK
        if      ( i_arst                           ) s_branch_count <= '0;
        else if ( ~ i_stall_fetch & s_branch_fetch ) s_branch_count <= s_branch_count + 15'b1; 

        if      ( i_arst                                   ) s_branch_mispred_count <= '0;
        else if ( ~ i_stall_fetch & s_branch_mispred_fetch ) s_branch_mispred_count <= s_branch_mispred_count + 15'b1;
    end


    //-------------------------------------
    // Memory stage module.
    //-------------------------------------
    memory_stage #(
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) STAGE4_MEM (
        .i_clk             ( i_clk                ),
        .i_arst            ( i_arst               ),
        .i_stall_wb        ( i_stall_mem          ),
        .i_pc_plus4        ( s_pc_plus4_mem       ),
        .i_pc_target       ( s_pc_target_mem      ),
        .i_alu_result      ( s_alu_result_mem     ),
        .i_write_data      ( s_write_data_mem     ),
        .i_rd_addr         ( s_rd_addr_mem        ),
        .i_imm_ext         ( s_imm_ext_mem        ),
        .i_result_src      ( s_result_src_mem     ),
        .i_mem_we          ( s_mem_we_mem         ),
        .i_forward_src     ( s_forward_src_mem    ),
        .i_func3           ( s_func3_mem          ),
        .i_reg_we          ( s_reg_we_mem         ),
        .i_mem_block_we    ( i_dcache_we          ),
        .i_data_block      ( i_data_block         ),
        .i_ecall_instr     ( s_ecall_instr_mem    ),
        .i_cause           ( s_cause_mem          ),
        .i_mem_access      ( s_mem_access_mem     ),
        .o_pc_plus4        ( s_pc_plus4_wb        ),
        .o_pc_target       ( s_pc_target_wb       ),
        .o_forward_value   ( s_forward_value_exec ),
        .o_alu_result      ( s_alu_result_wb      ),
        .o_read_data       ( s_read_data_wb       ),
        .o_rd_addr         ( o_rd_addr_mem        ),
        .o_rd_addr_preg    ( s_rd_addr_wb         ),
        .o_imm_ext         ( s_imm_ext_wb         ),
        .o_result_src      ( s_result_src_wb      ),
        .o_dcache_hit      ( o_dcache_hit         ),
        .o_dcache_dirty    ( o_dcache_dirty       ),
        .o_axi_addr_wb     ( o_axi_addr_wb        ),
        .o_data_block      ( o_data_block         ),
        .o_ecall_instr     ( s_ecall_instr_wb     ),
        .o_cause           ( s_cause_wb           ),
        .o_reg_we          ( s_reg_we_wb          )
    );

    assign o_axi_read_addr_d = s_alu_result_mem;
    assign o_mem_access      = s_mem_access_mem;


    //-------------------------------------
    // Write-back stage module.
    //-------------------------------------
    write_back_stage STAGE5_WB (
        .i_pc_plus4   ( s_pc_plus4_wb   ),
        .i_pc_target  ( s_pc_target_wb  ),
        .i_alu_result ( s_alu_result_wb ),
        .i_read_data  ( s_read_data_wb  ),
        .i_rd_addr    ( s_rd_addr_wb    ),
        .i_imm_ext    ( s_imm_ext_wb    ),
        .i_result_src ( s_result_src_wb ),
        .i_ecall_instr ( s_ecall_instr_wb ),
        .i_cause       ( s_cause_wb       ),
        .i_branch_total   ( s_branch_count         ),
        .i_branch_mispred ( s_branch_mispred_count ), 
        .i_a0_reg_lsb  ( s_a0_reg_lsb_wb  ),
        .i_reg_we     ( s_reg_we_wb     ),
        .o_result     ( s_result_wb     ),
        .o_rd_addr    ( s_rd_addr_dec   ),
        .o_reg_we     ( s_reg_we_dec    )
    );


    //-------------------------------------------------------------
    // Continious assignment of outputs.
    //-------------------------------------------------------------
    assign o_rd_addr_wb          = s_rd_addr_dec;
    assign o_reg_we_mem          = s_reg_we_mem;
    assign o_reg_we_wb           = s_reg_we_wb;
    assign o_branch_mispred_exec = s_branch_mispred_fetch;

endmodule