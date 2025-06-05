/* Copyright (c) 2024 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 10/2024
// Last Revision: 29/05/2025
//------------------------------

// To-do:
// 2. Reorder signals.

// ------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units in all stages of the pipeline
// ------------------------------------------------------------------------------------------

module datapath
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter BLOCK_WIDTH = 512,
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5,
    parameter INSTR_WIDTH = 32
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_fetch_i,
    input  logic                     stall_dec_i,
    input  logic                     stall_exec_i,
    input  logic                     stall_mem_i,
    input  logic                     flush_dec_i,
    input  logic                     flush_exec_i,
    input  logic [              1:0] forward_rs1_i,
    input  logic [              1:0] forward_rs2_i,
    input  logic                     instr_we_i,
    input  logic                     dcache_we_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,

    // Output interface.
    output logic [REG_ADDR_W  - 1:0] rs1_addr_dec_o,
    output logic [REG_ADDR_W  - 1:0] rs1_addr_exec_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_dec_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_exec_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_exec_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_mem_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_wb_o,
    output logic                     reg_we_mem_o,
    output logic                     reg_we_wb_o,
    output logic                     branch_mispred_exec_o,
    output logic                     icache_hit_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_instr_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_data_o,
    output logic                     dcache_hit_o,
    output logic                     dcache_dirty_o,
    output logic [ADDR_WIDTH  - 1:0] axi_addr_wb_o,
    output logic [BLOCK_WIDTH - 1:0] data_block_o,
    output logic                     mem_access_o,
    output logic                     load_instr_exec_o
);

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------
    
    // Fetch stage signals: Input interface.
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_fetch_in_s;
    logic                     branch_mispred_fetch_in_s;
    logic                     branch_fetch_in_s;
    logic                     branch_taken_fetch_in_s;
    logic [              1:0] btb_way_fetch_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_fetch_in_s;

    // Fetch stage signals: Output interface.
    logic [INSTR_WIDTH - 1:0] instruction_fetch_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_fetch_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_fetch_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_fetch_out_s;
    logic [              1:0] btb_way_fetch_out_s;
    logic                     branch_taken_pred_fetch_out_s;
    logic                     log_trace_fetch_out_s;


    // Decode stage signals: Input interface.
    logic [INSTR_WIDTH - 1:0] instruction_dec_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_dec_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_dec_in_s;
    logic [REG_ADDR_W  - 1:0] rd_addr_dec_in_s;
    logic [DATA_WIDTH  - 1:0] result_dec_in_s;
    logic                     reg_we_dec_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_dec_in_s;
    logic [              1:0] btb_way_dec_in_s;
    logic                     branch_taken_pred_dec_in_s;
    logic                     log_trace_dec_in_s;

    // Decode stage signals: Output interface.
    logic [              2:0] result_src_dec_out_s;
    logic [              4:0] alu_control_dec_out_s;
    logic                     mem_we_dec_out_s;
    logic                     reg_we_dec_out_s;
    logic                     alu_src_dec_out_s;
    logic                     branch_dec_out_s;
    logic                     jump_dec_out_s;
    logic                     pc_target_src_dec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_dec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_dec_out_s;
    logic [DATA_WIDTH  - 1:0] imm_ext_dec_out_s;
    logic [DATA_WIDTH  - 1:0] rs1_data_dec_out_s;
    logic [DATA_WIDTH  - 1:0] rs2_data_dec_out_s;
    logic [REG_ADDR_W  - 1:0] rs1_addr_dec_out_s;
    logic [REG_ADDR_W  - 1:0] rs2_addr_dec_out_s;
    logic [REG_ADDR_W  - 1:0] rd_addr_dec_out_s;
    logic [              2:0] func3_dec_out_s;
    logic [              1:0] forward_src_dec_out_s;
    logic                     mem_access_dec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_dec_out_s;
    logic [              1:0] btb_way_dec_out_s;
    logic                     branch_taken_pred_dec_out_s;
    logic                     log_trace_dec_out_s;
    logic [INSTR_WIDTH - 1:0] instruction_log_dec_out_s;
    logic                     ecall_instr_dec_out_s;
    logic [              3:0] cause_dec_out_s;
    logic                     load_instr_dec_out_s;


    // Execute stage signals: Input interface.
    logic [             2:0] func3_exec_in_s;
    logic [ADDR_WIDTH - 1:0] pc_exec_in_s;
    logic [ADDR_WIDTH - 1:0] pc_plus4_exec_in_s;
    logic [DATA_WIDTH - 1:0] rs1_data_exec_in_s;
    logic [DATA_WIDTH - 1:0] rs2_data_exec_in_s;
    logic [REG_ADDR_W - 1:0] rs1_addr_exec_in_s;
    logic [REG_ADDR_W - 1:0] rs2_addr_exec_in_s;
    logic [REG_ADDR_W - 1:0] rd_addr_exec_in_s;
    logic [DATA_WIDTH - 1:0] result_exec_in_s;
    logic [DATA_WIDTH - 1:0] imm_ext_exec_in_s;
    logic [             2:0] result_src_exec_in_s;
    logic [             4:0] alu_control_exec_in_s;
    logic                    mem_we_exec_in_s;
    logic                    reg_we_exec_in_s;
    logic                    alu_src_exec_in_s;
    logic                    branch_exec_in_s;
    logic                    jump_exec_in_s;
    logic                    pc_target_src_exec_in_s;
    logic [             1:0] forward_src_exec_in_s;
    logic [DATA_WIDTH - 1:0] forward_value_exec_in_s;
    logic                    mem_access_exec_in_s;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_pred_exec_in_s;
    logic [             1:0] btb_way_exec_in_s;
    logic                    branch_taken_pred_exec_in_s;
    logic                    log_trace_exec_in_s;
    logic                    ecall_instr_exec_in_s;
    logic [             3:0] cause_exec_in_s;
    logic                    load_instr_exec_in_s;

    // Execute stage signals: Output interface.
    logic [ADDR_WIDTH  - 1:0] pc_log_exec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_exec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_new_exec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_exec_out_s;
    logic [DATA_WIDTH  - 1:0] alu_result_exec_out_s;
    logic [DATA_WIDTH  - 1:0] write_data_exec_out_s;
    logic [REG_ADDR_W  - 1:0] rd_addr_exec_out_s;
    logic [DATA_WIDTH  - 1:0] imm_ext_exec_out_s;
    logic [              2:0] result_src_exec_out_s;
    logic [              1:0] forward_src_exec_out_s;
    logic                     mem_we_exec_out_s;
    logic                     reg_we_exec_out_s;
    logic                     branch_mispred_exec_out_s;
    logic [              2:0] func3_exec_out_s;
    logic                     mem_access_exec_out_s;
    logic                     branch_exec_out_s;
    logic                     branch_taken_exec_out_s;
    logic [              1:0] btb_way_exec_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_exec_out_s;
    logic                     ecall_instr_exec_out_s;
    logic [              3:0] cause_exec_out_s;
    logic                     log_trace_exec_out_s;
    logic [INSTR_WIDTH - 1:0] instruction_log_exec_out_s;


    // Memory stage signals: Input interface.
    logic [ADDR_WIDTH - 1:0] pc_plus4_mem_in_s;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_mem_in_s;
    logic [DATA_WIDTH - 1:0] alu_result_mem_in_s;
    logic [DATA_WIDTH - 1:0] write_data_mem_in_s;
    logic [REG_ADDR_W - 1:0] rd_addr_mem_in_s;
    logic [DATA_WIDTH - 1:0] imm_ext_mem_in_s;
    logic [             2:0] result_src_mem_in_s;
    logic                    mem_we_mem_in_s;
    logic                    reg_we_mem_in_s;
    logic [             2:0] func3_mem_in_s;
    logic [             1:0] forward_src_mem_in_s;
    logic                    mem_access_mem_in_s;
    logic                    ecall_instr_mem_in_s;
    logic [             3:0] cause_mem_in_s;
    logic                    log_trace_mem_in_s;
    logic [ADDR_WIDTH - 1:0] pc_log_mem_in_s;

    // Memory stage signals: Output interface.
    logic [DATA_WIDTH  - 1:0] forward_value_mem_out_s;
    logic [              2:0] result_src_mem_out_s;
    logic                     reg_we_mem_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_mem_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_mem_out_s;
    logic [DATA_WIDTH  - 1:0] imm_ext_mem_out_s;
    logic [DATA_WIDTH  - 1:0] alu_result_mem_out_s;
    logic [DATA_WIDTH  - 1:0] read_data_mem_out_s;
    logic                     ecall_instr_mem_out_s;
    logic [              3:0] cause_mem_out_s;
    logic                     log_trace_mem_out_s;
    logic [ADDR_WIDTH  - 1:0] pc_log_mem_out_s;
    logic [INSTR_WIDTH - 1:0] instruction_log_mem_out_s;
    logic [ADDR_WIDTH  - 1:0] mem_addr_log_mem_out_s;
    logic [ADDR_WIDTH  - 1:0] mem_write_data_log_mem_out_s;
    logic                     mem_we_log_mem_out_s;
    logic                     mem_access_log_mem_out_s;
    logic [REG_ADDR_W  - 1:0] rd_addr_mem_out_s;


    // Write-back stage signals: Input interface.
    logic [ADDR_WIDTH  - 1:0] pc_plus4_wb_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_wb_in_s;
    logic [DATA_WIDTH  - 1:0] alu_result_wb_in_s;
    logic [DATA_WIDTH  - 1:0] read_data_wb_in_s;
    logic [REG_ADDR_W  - 1:0] rd_addr_wb_in_s;
    logic [DATA_WIDTH  - 1:0] imm_ext_wb_in_s;
    logic [              2:0] result_src_wb_in_s;
    logic                     reg_we_wb_in_s;
    logic                     ecall_instr_wb_in_s;
    logic [              3:0] cause_wb_in_s;
    logic                     a0_reg_lsb_s;
    logic                     log_trace_wb_in_s;
    logic [ADDR_WIDTH  - 1:0] pc_log_wb_in_s;
    logic [INSTR_WIDTH - 1:0] instruction_log_wb_in_s;
    logic [ADDR_WIDTH  - 1:0] mem_addr_log_wb_in_s;
    logic [ADDR_WIDTH  - 1:0] mem_write_data_log_wb_in_s;
    logic                     mem_we_log_wb_in_s;
    logic                     mem_access_log_wb_in_s;

    // Write-back stage signals: Input interface.
    logic [DATA_WIDTH - 1:0] result_wb_out_s;
    logic [REG_ADDR_W - 1:0] rd_addr_wb_out_s;
    logic                    reg_we_wb_out_s;


    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Fetch stage module.
    //-------------------------------------
    fetch_stage # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) STAGE1_FETCH (
        .clk_i                 (clk_i                          ),
        .arst_i                (arst_i                         ),
        .pc_target_addr_i      (pc_target_addr_fetch_in_s      ),
        .branch_mispred_i      (branch_mispred_fetch_in_s      ),
        .stall_fetch_i         (stall_fetch_i                  ),
        .instr_we_i            (instr_we_i                     ),
        .instr_block_i         (data_block_i                   ),
        .branch_exec_i         (branch_fetch_in_s              ),
        .branch_taken_exec_i   (branch_taken_fetch_in_s        ),
        .btb_way_exec_i        (btb_way_fetch_in_s             ),
        .pc_exec_i             (pc_fetch_in_s                  ),
        .instruction_o         (instruction_fetch_out_s        ),
        .pc_plus4_o            (pc_plus4_fetch_out_s           ),
        .pc_o                  (pc_fetch_out_s                 ),
        .axi_read_addr_o       (axi_read_addr_instr_o          ),
        .pc_target_addr_pred_o (pc_target_addr_pred_fetch_out_s),
        .btb_way_o             (btb_way_fetch_out_s            ),
        .branch_taken_pred_o   (branch_taken_pred_fetch_out_s  ),
        .log_trace_o           (log_trace_fetch_out_s          ),
        .icache_hit_o          (icache_hit_o                   )
    );

    //------------------------------------------------------------------------------
    // Decode Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_decode PIPE_DEC (
        .clk_i                 (clk_i                          ),
        .arst_i                (arst_i                         ),
        .flush_dec_i           (flush_dec_i                    ),
        .stall_dec_i           (stall_dec_i                    ),
        .log_trace_i           (log_trace_fetch_out_s          ),
        .pc_target_addr_pred_i (pc_target_addr_pred_fetch_out_s),
        .btb_way_i             (btb_way_fetch_out_s            ),
        .branch_pred_taken_i   (branch_taken_pred_fetch_out_s  ),
        .instr_i               (instruction_fetch_out_s        ),
        .pc_i                  (pc_fetch_out_s                 ),
        .pc_plus4_i            (pc_plus4_fetch_out_s           ),
        .log_trace_o           (log_trace_dec_in_s             ),
        .pc_target_addr_pred_o (pc_target_addr_pred_dec_in_s   ),
        .btb_way_o             (btb_way_dec_in_s               ),
        .branch_pred_taken_o   (branch_taken_pred_dec_in_s     ),
        .instr_o               (instruction_dec_in_s           ),
        .pc_o                  (pc_dec_in_s                    ),
        .pc_plus4_o            (pc_plus4_dec_in_s              )
    );

    //-------------------------------------
    // Decode stage module.
    //-------------------------------------
    decode_stage STAGE2_DEC (
        .clk_i                 (clk_i                        ),
        .arst_i                (arst_i                       ),
        .instruction_i         (instruction_dec_in_s         ),
        .pc_plus4_i            (pc_plus4_dec_in_s            ),
        .pc_i                  (pc_dec_in_s                  ),
        .rd_write_data_i       (result_dec_in_s              ),
        .rd_addr_i             (rd_addr_dec_in_s             ),
        .reg_we_i              (reg_we_dec_in_s              ),
        .pc_target_addr_pred_i (pc_target_addr_pred_dec_in_s ),
        .btb_way_i             (btb_way_dec_in_s             ),
        .branch_pred_taken_i   (branch_taken_pred_dec_in_s   ),
        .log_trace_i           (log_trace_dec_in_s           ),
        .func3_o               (func3_dec_out_s              ),
        .pc_o                  (pc_dec_out_s                 ),
        .pc_plus4_o            (pc_plus4_dec_out_s           ),
        .rs1_data_o            (rs1_data_dec_out_s           ),
        .rs2_data_o            (rs2_data_dec_out_s           ),
        .rs1_addr_o            (rs1_addr_dec_out_s           ),
        .rs2_addr_o            (rs2_addr_dec_out_s           ),
        .rd_addr_o             (rd_addr_dec_out_s            ),
        .imm_ext_o             (imm_ext_dec_out_s            ),
        .result_src_o          (result_src_dec_out_s         ),
        .alu_control_o         (alu_control_dec_out_s        ),
        .mem_we_o              (mem_we_dec_out_s             ),
        .reg_we_o              (reg_we_dec_out_s             ),
        .alu_src_o             (alu_src_dec_out_s            ),
        .branch_o              (branch_dec_out_s             ),
        .jump_o                (jump_dec_out_s               ),
        .pc_target_src_o       (pc_target_src_dec_out_s      ),
        .forward_src_o         (forward_src_dec_out_s        ),
        .mem_access_o          (mem_access_dec_out_s         ),
        .pc_target_addr_pred_o (pc_target_addr_pred_dec_out_s),
        .btb_way_o             (btb_way_dec_out_s            ),
        .branch_pred_taken_o   (branch_taken_pred_dec_out_s  ),
        .log_trace_o           (log_trace_dec_out_s          ),
        .instruction_log_o     (instruction_log_dec_out_s    ),
        .ecall_instr_o         (ecall_instr_dec_out_s        ),
        .cause_o               (cause_dec_out_s              ),
        .a0_reg_lsb_o          (a0_reg_lsb_s                 ),
        .load_instr_o          (load_instr_dec_out_s         )
    );

    //-------------------------------------------------------------------------------
    // Execute Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_execute PIPE_EXEC (
        .clk_i                 (clk_i                        ),
        .arst_i                (arst_i                       ),
        .stall_exec_i          (stall_exec_i                 ),
        .flush_exec_i          (flush_exec_i                 ),
        .instruction_log_i     (instruction_log_dec_out_s    ),
        .log_trace_i           (log_trace_dec_out_s          ),
        .result_src_i          (result_src_dec_out_s         ),
        .alu_control_i         (alu_control_dec_out_s        ),
        .mem_we_i              (mem_we_dec_out_s             ),
        .reg_we_i              (reg_we_dec_out_s             ),
        .alu_src_i             (alu_src_dec_out_s            ),
        .branch_i              (branch_dec_out_s             ),
        .jump_i                (jump_dec_out_s               ),
        .pc_target_src_i       (pc_target_src_dec_out_s      ),
        .pc_plus4_i            (pc_plus4_dec_out_s           ),
        .pc_i                  (pc_dec_out_s                 ),
        .imm_ext_i             (imm_ext_dec_out_s            ),
        .rs1_data_i            (rs1_data_dec_out_s           ),
        .rs2_data_i            (rs2_data_dec_out_s           ),
        .rs1_addr_i            (rs1_addr_dec_out_s           ),
        .rs2_addr_i            (rs2_addr_dec_out_s           ),
        .rd_addr_i             (rd_addr_dec_out_s            ),
        .func3_i               (func3_dec_out_s              ),
        .forward_src_i         (forward_src_dec_out_s        ),
        .mem_access_i          (mem_access_dec_out_s         ),
        .pc_target_addr_pred_i (pc_target_addr_pred_dec_out_s),
        .btb_way_i             (btb_way_dec_out_s            ),
        .branch_pred_taken_i   (branch_taken_pred_dec_out_s  ),
        .ecall_instr_i         (ecall_instr_dec_out_s        ),
        .cause_i               (cause_dec_out_s              ),
        .load_instr_i          (load_instr_dec_out_s         ),
        .instruction_log_o     (instruction_log_exec_out_s   ),
        .log_trace_o           (log_trace_exec_in_s          ),
        .result_src_o          (result_src_exec_in_s         ),
        .alu_control_o         (alu_control_exec_in_s        ),
        .mem_we_o              (mem_we_exec_in_s             ),
        .reg_we_o              (reg_we_exec_in_s             ),
        .alu_src_o             (alu_src_exec_in_s            ),
        .branch_o              (branch_exec_in_s             ),
        .jump_o                (jump_exec_in_s               ),
        .pc_target_src_o       (pc_target_src_exec_in_s      ),
        .pc_plus4_o            (pc_plus4_exec_in_s           ),
        .pc_o                  (pc_exec_in_s                 ),
        .imm_ext_o             (imm_ext_exec_in_s            ),
        .rs1_data_o            (rs1_data_exec_in_s           ),
        .rs2_data_o            (rs2_data_exec_in_s           ),
        .rs1_addr_o            (rs1_addr_exec_in_s           ),
        .rs2_addr_o            (rs2_addr_exec_in_s           ),
        .rd_addr_o             (rd_addr_exec_in_s            ),
        .func3_o               (func3_exec_in_s              ),
        .forward_src_o         (forward_src_exec_in_s        ),
        .mem_access_o          (mem_access_exec_in_s         ),
        .pc_target_addr_pred_o (pc_target_addr_pred_exec_in_s),
        .btb_way_o             (btb_way_exec_in_s            ),
        .branch_pred_taken_o   (branch_taken_pred_exec_in_s  ),
        .ecall_instr_o         (ecall_instr_exec_in_s        ),
        .cause_o               (cause_exec_in_s              ),
        .load_instr_o          (load_instr_exec_in_s         )
    );

    //-------------------------------------
    // Execute stage module.
    //-------------------------------------
    execute_stage STAGE3_EXEC (
        .pc_i                  (pc_exec_in_s                 ),
        .pc_plus4_i            (pc_plus4_exec_in_s           ),
        .rs1_data_i            (rs1_data_exec_in_s           ),
        .rs2_data_i            (rs2_data_exec_in_s           ),
        .rs1_addr_i            (rs1_addr_exec_in_s           ),
        .rs2_addr_i            (rs2_addr_exec_in_s           ),
        .rd_addr_i             (rd_addr_exec_in_s            ),
        .imm_ext_i             (imm_ext_exec_in_s            ),
        .func3_i               (func3_exec_in_s              ),
        .result_src_i          (result_src_exec_in_s         ),
        .alu_control_i         (alu_control_exec_in_s        ),
        .mem_we_i              (mem_we_exec_in_s             ),
        .reg_we_i              (reg_we_exec_in_s             ),
        .alu_src_i             (alu_src_exec_in_s            ),
        .branch_i              (branch_exec_in_s             ),
        .jump_i                (jump_exec_in_s               ),
        .pc_target_src_i       (pc_target_src_exec_in_s      ),
        .result_i              (result_exec_in_s             ),
        .forward_value_i       (forward_value_exec_in_s      ),
        .forward_src_i         (forward_src_exec_in_s        ),
        .mem_access_i          (mem_access_exec_in_s         ),
        .load_instr_i          (load_instr_exec_in_s         ),
        .forward_rs1_exec_i    (forward_rs1_i                ),
        .forward_rs2_exec_i    (forward_rs2_i                ),
        .pc_target_addr_pred_i (pc_target_addr_pred_exec_in_s),
        .btb_way_i             (btb_way_exec_in_s            ),
        .ecall_instr_i         (ecall_instr_exec_in_s        ),
        .cause_i               (cause_exec_in_s              ),
        .branch_pred_taken_i   (branch_taken_pred_exec_in_s  ),
        .log_trace_i           (log_trace_exec_in_s          ),
        .pc_log_o              (pc_log_exec_out_s            ),
        .pc_plus4_o            (pc_plus4_exec_out_s          ),
        .pc_new_o              (pc_new_exec_out_s            ),
        .pc_target_addr_o      (pc_target_addr_exec_out_s    ),
        .alu_result_o          (alu_result_exec_out_s        ),
        .write_data_o          (write_data_exec_out_s        ),
        .rs1_addr_o            (rs1_addr_exec_o              ),
        .rs2_addr_o            (rs2_addr_exec_o              ),
        .rd_addr_o             (rd_addr_exec_out_s           ),
        .imm_ext_o             (imm_ext_exec_out_s           ),
        .result_src_o          (result_src_exec_out_s        ),
        .forward_src_o         (forward_src_exec_out_s       ),
        .mem_we_o              (mem_we_exec_out_s            ),
        .reg_we_o              (reg_we_exec_out_s            ),
        .branch_mispred_o      (branch_mispred_exec_out_s    ),
        .func3_o               (func3_exec_out_s             ),
        .mem_access_o          (mem_access_exec_out_s        ),
        .branch_exec_o         (branch_exec_out_s            ),
        .branch_taken_exec_o   (branch_taken_exec_out_s      ),
        .btb_way_exec_o        (btb_way_exec_out_s           ),
        .pc_exec_o             (pc_exec_out_s                ),
        .ecall_instr_o         (ecall_instr_exec_out_s       ),
        .cause_o               (cause_exec_out_s             ),
        .log_trace_o           (log_trace_exec_out_s         ),
        .load_instr_o          (load_instr_exec_o            )
    );

    assign pc_target_addr_fetch_in_s = pc_new_exec_out_s;
    assign branch_mispred_fetch_in_s = branch_mispred_exec_out_s;
    assign branch_fetch_in_s         = branch_exec_out_s;
    assign branch_taken_fetch_in_s   = branch_taken_exec_out_s;
    assign btb_way_fetch_in_s        = btb_way_exec_out_s;
    assign pc_fetch_in_s             = pc_exec_out_s;

    //-----------------------------------------------------------------
    // Memory Pipeline Register. With additional signals for stalling.
    //-----------------------------------------------------------------
    pipeline_reg_memory PIPE_MEM (
        .clk_i             (clk_i                     ),
        .arst_i            (arst_i                    ),
        .stall_mem_i       (stall_mem_i               ),
        .instruction_log_i (instruction_log_exec_out_s),
        .pc_log_i          (pc_log_exec_out_s         ),
        .log_trace_i       (log_trace_exec_out_s      ),
        .result_src_i      (result_src_exec_out_s     ),
        .mem_we_i          (mem_we_exec_out_s         ),
        .reg_we_i          (reg_we_exec_out_s         ),
        .pc_plus4_i        (pc_plus4_exec_out_s       ),
        .pc_target_addr_i  (pc_target_addr_exec_out_s ),
        .imm_ext_i         (imm_ext_exec_out_s        ),
        .alu_result_i      (alu_result_exec_out_s     ),
        .write_data_i      (write_data_exec_out_s     ),
        .forward_src_i     (forward_src_exec_out_s    ),
        .func3_i           (func3_exec_out_s          ),
        .mem_access_i      (mem_access_exec_out_s     ),
        .ecall_instr_i     (ecall_instr_exec_out_s    ),
        .cause_i           (cause_exec_out_s          ),
        .rd_addr_i         (rd_addr_exec_out_s        ),
        .instruction_log_o (instruction_log_mem_out_s ),
        .pc_log_o          (pc_log_mem_in_s           ),
        .log_trace_o       (log_trace_mem_in_s        ),
        .result_src_o      (result_src_mem_in_s       ),
        .mem_we_o          (mem_we_mem_in_s           ),
        .reg_we_o          (reg_we_mem_in_s           ),
        .pc_plus4_o        (pc_plus4_mem_in_s         ),
        .pc_target_addr_o  (pc_target_addr_mem_in_s   ),
        .imm_ext_o         (imm_ext_mem_in_s          ),
        .alu_result_o      (alu_result_mem_in_s       ),
        .write_data_o      (write_data_mem_in_s       ),
        .forward_src_o     (forward_src_mem_in_s      ),
        .func3_o           (func3_mem_in_s            ),
        .mem_access_o      (mem_access_mem_in_s       ),
        .ecall_instr_o     (ecall_instr_mem_in_s      ),
        .cause_o           (cause_mem_in_s            ),
        .rd_addr_o         (rd_addr_mem_in_s          )
    );

    assign axi_read_addr_data_o = alu_result_mem_in_s;
    assign mem_access_o         = mem_access_mem_in_s;

    //--------------------------------------------
    // For checking branch prediction accuracy.
    //--------------------------------------------
    logic [ 15:0 ] branch_count_s;
    logic [ 15:0 ] branch_mispred_count_s;

    always_ff @(posedge clk_i, posedge arst_i) begin : BRANCH_ACCURACY_CHECK
        if      (arst_i                             ) branch_count_s <= '0;
        else if (~ stall_fetch_i & branch_fetch_in_s) branch_count_s <= branch_count_s + 15'b1;

        if      (arst_i                                     ) branch_mispred_count_s <= '0;
        else if (~ stall_fetch_i & branch_mispred_fetch_in_s) branch_mispred_count_s <= branch_mispred_count_s + 15'b1;
    end


    //-------------------------------------
    // Memory stage module.
    //-------------------------------------
    memory_stage #(
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) STAGE4_MEM (
        .clk_i                (clk_i                       ),
        .arst_i               (arst_i                      ),
        .pc_plus4_i           (pc_plus4_mem_in_s           ),
        .pc_target_addr_i     (pc_target_addr_mem_in_s     ),
        .alu_result_i         (alu_result_mem_in_s         ),
        .write_data_i         (write_data_mem_in_s         ),
        .rd_addr_i            (rd_addr_mem_in_s            ),
        .imm_ext_i            (imm_ext_mem_in_s            ),
        .result_src_i         (result_src_mem_in_s         ),
        .mem_we_i             (mem_we_mem_in_s             ),
        .forward_src_i        (forward_src_mem_in_s        ),
        .func3_i              (func3_mem_in_s              ),
        .reg_we_i             (reg_we_mem_in_s             ),
        .mem_block_we_i       (dcache_we_i                 ),
        .data_block_i         (data_block_i                ),
        .ecall_instr_i        (ecall_instr_mem_in_s        ),
        .cause_i              (cause_mem_in_s              ),
        .log_trace_i          (log_trace_mem_in_s          ),
        .pc_log_i             (pc_log_mem_in_s             ),
        .mem_access_i         (mem_access_mem_in_s         ),
        .pc_plus4_o           (pc_plus4_mem_out_s          ),
        .pc_target_addr_o     (pc_target_addr_mem_out_s    ),
        .forward_value_o      (forward_value_mem_out_s     ),
        .alu_result_o         (alu_result_mem_out_s        ),
        .read_data_o          (read_data_mem_out_s         ),
        .rd_addr_o            (rd_addr_mem_out_s           ),
        .imm_ext_o            (imm_ext_mem_out_s           ),
        .result_src_o         (result_src_mem_out_s        ),
        .dcache_hit_o         (dcache_hit_o                ),
        .dcache_dirty_o       (dcache_dirty_o              ),
        .axi_addr_wb_o        (axi_addr_wb_o               ),
        .data_block_o         (data_block_o                ),
        .ecall_instr_o        (ecall_instr_mem_out_s       ),
        .cause_o              (cause_mem_out_s             ),
        .log_trace_o          (log_trace_mem_out_s         ),
        .pc_log_o             (pc_log_mem_out_s            ),
        .mem_addr_log_o       (mem_addr_log_mem_out_s      ),
        .mem_write_data_log_o (mem_write_data_log_mem_out_s),
        .mem_we_log_o         (mem_we_log_mem_out_s        ),
        .mem_access_log_o     (mem_access_log_mem_out_s    ),
        .reg_we_o             (reg_we_mem_out_s            )
    );

    assign forward_value_exec_in_s = forward_value_mem_out_s;

    //-------------------------------------------
    // Pipeline register for memory stage.
    //-------------------------------------------
    pipeline_reg_write_back PIPE_WB (
        .clk_i                (clk_i                       ),
        .arst_i               (arst_i                      ),
        .stall_wb_i           (stall_mem_i                 ),
        .mem_addr_log_i       (mem_addr_log_mem_out_s      ),
        .mem_write_data_log_i (mem_write_data_log_mem_out_s),
        .mem_we_log_i         (mem_we_log_mem_out_s        ),
        .mem_access_log_i     (mem_access_log_mem_out_s    ),
        .instruction_log_i    (instruction_log_mem_out_s   ),
        .pc_log_i             (pc_log_mem_out_s            ),
        .log_trace_i          (log_trace_mem_out_s         ),
        .result_src_i         (result_src_mem_out_s        ),
        .reg_we_i             (reg_we_mem_out_s            ),
        .pc_plus4_i           (pc_plus4_mem_out_s          ),
        .pc_target_addr_i     (pc_target_addr_mem_out_s    ),
        .imm_ext_i            (imm_ext_mem_out_s           ),
        .alu_result_i         (alu_result_mem_out_s        ),
        .read_data_i          (read_data_mem_out_s         ),
        .ecall_instr_i        (ecall_instr_mem_out_s       ),
        .cause_i              (cause_mem_out_s             ),
        .rd_addr_i            (rd_addr_mem_out_s           ),
        .mem_addr_log_o       (mem_addr_log_wb_in_s        ),
        .mem_write_data_log_o (mem_write_data_log_wb_in_s  ),
        .mem_we_log_o         (mem_we_log_wb_in_s          ),
		.mem_access_log_o     (mem_access_log_wb_in_s      ),
        .instruction_log_o    (instruction_log_wb_in_s     ),
        .pc_log_o             (pc_log_wb_in_s              ),
        .log_trace_o          (log_trace_wb_in_s           ),
        .result_src_o         (result_src_wb_in_s          ),
        .reg_we_o             (reg_we_wb_in_s              ),
        .pc_plus4_o           (pc_plus4_wb_in_s            ),
        .pc_target_addr_o     (pc_target_addr_wb_in_s      ),
        .imm_ext_o            (imm_ext_wb_in_s             ),
        .alu_result_o         (alu_result_wb_in_s          ),
        .read_data_o          (read_data_wb_in_s           ),
        .ecall_instr_o        (ecall_instr_wb_in_s         ),
        .cause_o              (cause_wb_in_s               ),
        .rd_addr_o            (rd_addr_wb_in_s             )
    );

    //-------------------------------------
    // Write-back stage module.
    //-------------------------------------
    write_back_stage STAGE5_WB (
        .pc_plus4_i           (pc_plus4_wb_in_s          ),
        .pc_target_addr_i     (pc_target_addr_wb_in_s    ),
        .alu_result_i         (alu_result_wb_in_s        ),
        .read_data_i          (read_data_wb_in_s         ),
        .rd_addr_i            (rd_addr_wb_in_s           ),
        .imm_ext_i            (imm_ext_wb_in_s           ),
        .result_src_i         (result_src_wb_in_s        ),
        .ecall_instr_i        (ecall_instr_wb_in_s       ),
        .cause_i              (cause_wb_in_s             ),
        .branch_total_i       (branch_count_s            ),
        .branch_mispred_i     (branch_mispred_count_s    ),
        .a0_reg_lsb_i         (a0_reg_lsb_s              ),
        .log_trace_i          (log_trace_wb_in_s         ),
        .pc_log_i             (pc_log_wb_in_s            ),
        .instruction_log_i    (instruction_log_wb_in_s   ),
        .mem_addr_log_i       (mem_addr_log_wb_in_s      ),
        .mem_write_data_log_i (mem_write_data_log_wb_in_s),
        .mem_we_log_i         (mem_we_log_wb_in_s        ),
		.mem_access_log_i     (mem_access_log_wb_in_s    ),
        .reg_we_i             (reg_we_wb_in_s            ),
        .result_o             (result_wb_out_s           ),
        .rd_addr_o            (rd_addr_wb_out_s          ),
        .reg_we_o             (reg_we_wb_out_s           )
    );

    assign rd_addr_dec_in_s = rd_addr_wb_out_s;
    assign reg_we_dec_in_s  = reg_we_wb_out_s;
    assign result_dec_in_s  = result_wb_out_s;
    assign result_exec_in_s = result_wb_out_s;


    //-------------------------------------------------------------
    // Continious assignment of outputs.
    //-------------------------------------------------------------
    assign rd_addr_wb_o          = rd_addr_wb_out_s;
    assign branch_mispred_exec_o = branch_mispred_fetch_in_s;

    // Pipeline between Dec & Exec.
    assign rs1_addr_dec_o = rs1_addr_dec_out_s;
    assign rs2_addr_dec_o = rs2_addr_dec_out_s;

    // Pipeline reg between Exec & Mem.
    assign rd_addr_exec_o = rd_addr_exec_out_s;
    assign reg_we_mem_o   = reg_we_mem_in_s;

    // Pipeline reg between Mem & WB.
    assign rd_addr_mem_o = rd_addr_mem_out_s;
    assign reg_we_wb_o   = reg_we_wb_in_s;

endmodule
