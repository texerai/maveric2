/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 09/06/2026
//------------------------------


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
    parameter CSR_ADDR_W  = 12,
    parameter INSTR_WIDTH = 32
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_if_i,
    input  logic                     stall_id_i,
    input  logic                     stall_ex_i,
    input  logic                     stall_mem_i,
    input  logic                     flush_id_i,
    input  logic                     flush_ex_i,
    input  logic [              1:0] forward_rs1_i,
    input  logic [              1:0] forward_rs2_i,
    input  logic                     instr_we_i,
    input  logic                     dcache_we_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,
    input  logic [DATA_WIDTH  - 1:0] mmio_rdata_i,

    // Output interface.
    output logic [REG_ADDR_W  - 1:0] rs1_addr_id_o,
    output logic [REG_ADDR_W  - 1:0] rs1_addr_ex_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_id_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_ex_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_ex_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_mem_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_wb_o,
    output logic                     reg_we_mem_o,
    output logic                     reg_we_wb_o,
    output logic                     branch_mispred_ex_o,
    output logic                     icache_hit_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_instr_o,
    output logic [ADDR_WIDTH  - 1:0] axi_read_addr_data_o,
    output logic                     dcache_hit_o,
    output logic                     dcache_dirty_o,
    output logic [ADDR_WIDTH  - 1:0] axi_addr_wb_o,
    output logic [BLOCK_WIDTH - 1:0] data_block_o,
    output logic                     mem_access_o,
    output logic                     load_instr_ex_o,
    output logic                     mdu_busy_ex_o,
    output logic                     csr_stall_o,
    output logic                     exc_stall_o,
    output logic                     mmio_access_o,
    output logic                     mmio_access_type_o,
    output logic [DATA_WIDTH  - 1:0] mmio_wdata_o,
    output logic [              3:0] mmio_wstrb_o,
    output logic                     log_trace_wb_o
);
    //-------------------------------------------------------------
    // Localparams.
    //-------------------------------------------------------------
    /* verilator lint_off UNUSED */
    localparam [ADDR_WIDTH - 1:0] RAM_ADDR    = 64'h80000000;
    localparam [ADDR_WIDTH - 1:0] DEVICE_BASE = 64'ha0000000;
    localparam [ADDR_WIDTH - 1:0] CLINT_MMIO  = 64'h02000000;
    /* verilator lint_on UNUSED */


    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------

    // Fetch stage signals: Input interface.
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_ex_if;
    logic                     branch_mispred_ex_if;
    logic                     branch_instr_ex_if;
    logic                     branch_taken_ex_if;
    logic [              1:0] btb_way_ex_if;
    logic [ADDR_WIDTH  - 1:0] pc_ex_if;
    logic                     exc_detected_wb_if;

    // Fetch stage signals: Output interface.
    logic [INSTR_WIDTH - 1:0] instruction_if_id_d;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_if_id_d;
    logic [ADDR_WIDTH  - 1:0] pc_if_id_d;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_if_id_d;
    logic [              1:0] btb_way_if_id_d;
    logic                     branch_taken_pred_if_id_d;
    logic                     log_trace_if_id_d;


    // Decode stage signals: Input interface.
    logic [INSTR_WIDTH - 1:0] instruction_if_id_q;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_if_id_q;
    logic [ADDR_WIDTH  - 1:0] pc_if_id_q;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_if_id_q;
    logic [              1:0] btb_way_if_id_q;
    logic                     branch_taken_pred_if_id_q;
    logic [DATA_WIDTH  - 1:0] result_wb_id;
    logic [REG_ADDR_W  - 1:0] rd_addr_wb_id;
    logic                     reg_we_wb_id;
    logic                     log_trace_if_id_q;

    // Decode stage signals: Output interface.
    logic [              2:0] result_src_id_ex_d;
    logic [              4:0] alu_control_id_ex_d;
    logic                     mem_we_id_ex_d;
    logic                     reg_we_id_ex_d;
    logic                     csr_we_id_ex_d;
    logic                     alu_srcA_id_ex_d;
    logic [              1:0] alu_srcB_id_ex_d;
    logic                     branch_id_ex_d;
    logic                     jump_id_ex_d;
    logic                     pc_target_src_id_ex_d;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_id_ex_d;
    logic [ADDR_WIDTH  - 1:0] pc_id_ex_d;
    logic [DATA_WIDTH  - 1:0] imm_ext_id_ex_d;
    logic [DATA_WIDTH  - 1:0] rs1_data_id_ex_d;
    logic [DATA_WIDTH  - 1:0] rs2_data_id_ex_d;
    logic [REG_ADDR_W  - 1:0] rs1_addr_id_ex_d;
    logic [REG_ADDR_W  - 1:0] rs2_addr_id_ex_d;
    logic [REG_ADDR_W  - 1:0] rd_addr_id_ex_d;
    logic [CSR_ADDR_W  - 1:0] csr_addr_id_ex_d;
    logic [              2:0] func3_id_ex_d;
    logic [              1:0] forward_src_id_ex_d;
    logic                     mem_access_id_ex_d;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_id_ex_d;
    logic [              1:0] btb_way_id_ex_d;
    logic                     branch_taken_pred_id_ex_d;
    logic [INSTR_WIDTH - 1:0] instruction_log_id_ex_d;
    logic                     exc_detected_id_ex_d;
    logic [              4:0] exc_cause_id_ex_d;
    logic                     load_instr_id_ex_d;
    logic                     is_mdu_op_id_ex_d;
    logic                     is_mdu_word_op_id_ex_d;
    logic                     a0_reg_lsb;
    logic                     log_trace_id_ex_d;


    // Execute stage signals: Input interface.
    logic [              2:0] result_src_id_ex_q;
    logic [              4:0] alu_control_id_ex_q;
    logic                     mem_we_id_ex_q;
    logic                     reg_we_id_ex_q;
    logic                     csr_we_id_ex_q;
    logic                     alu_srcA_id_ex_q;
    logic [              1:0] alu_srcB_id_ex_q;
    logic                     branch_instr_id_ex_q;
    logic                     jump_id_ex_q;
    logic                     pc_target_src_id_ex_q;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_id_ex_q;
    logic [ADDR_WIDTH  - 1:0] pc_id_ex_q;
    logic [DATA_WIDTH  - 1:0] imm_ext_id_ex_q;
    logic [DATA_WIDTH  - 1:0] rs1_data_id_ex_q;
    logic [DATA_WIDTH  - 1:0] rs2_data_id_ex_q;
    logic [REG_ADDR_W  - 1:0] rs1_addr_id_ex_q;
    logic [REG_ADDR_W  - 1:0] rs2_addr_id_ex_q;
    logic [REG_ADDR_W  - 1:0] rd_addr_id_ex_q;
    logic [CSR_ADDR_W  - 1:0] csr_read_addr_id_ex_q;
    logic [              2:0] func3_id_ex_q;
    logic [              1:0] forward_src_id_ex_q;
    logic                     mem_access_id_ex_q;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_id_ex_q;
    logic [              1:0] btb_way_id_ex_q;
    logic                     branch_taken_pred_id_ex_q;
    logic [INSTR_WIDTH - 1:0] instruction_log_ex_mem_d; // Fix alignment.
    logic                     exc_detected_id_ex_q;
    logic [              4:0] exc_cause_id_ex_q;
    logic                     load_instr_id_ex_q;
    logic                     is_mdu_op_id_ex_q;
    logic                     is_mdu_word_op_id_ex_q;
    logic [CSR_ADDR_W  - 1:0] csr_write_addr_wb_ex;
    logic [DATA_WIDTH  - 1:0] csr_write_data_wb_ex;
    logic                     csr_we_wb_ex;
    logic [DATA_WIDTH  - 1:0] result_wb_ex;
    logic [DATA_WIDTH  - 1:0] forward_value_mem_ex;
    logic                     mcause_we_wb_ex;
    logic [              4:0] mcause_write_data_wb_ex;
    logic                     log_trace_id_ex_q;

    // Execute stage signals: Output interface.
    logic [              2:0] result_src_ex_mem_d;
    logic                     mem_we_ex_mem_d;
    logic                     reg_we_ex_mem_d;
    logic                     csr_we_ex_mem_d;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_ex_mem_d;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_ex_mem_d;
    logic [DATA_WIDTH  - 1:0] imm_ext_ex_mem_d;
    logic [DATA_WIDTH  - 1:0] alu_result_ex_mem_d;
    logic [DATA_WIDTH  - 1:0] write_data_ex_mem_d;
    logic [              1:0] forward_src_ex_mem_d;
    logic [              2:0] func3_ex_mem_d;
    logic                     mem_access_ex_mem_d;
    logic                     exc_detected_ex_mem_d;
    logic [              4:0] exc_cause_ex_mem_d;
    logic [REG_ADDR_W  - 1:0] rd_addr_ex_mem_d;
    logic [CSR_ADDR_W  - 1:0] csr_write_addr_ex_mem_d;
    logic [DATA_WIDTH  - 1:0] csr_read_data_ex_mem_d;
    logic [ADDR_WIDTH  - 1:0] pc_log_ex_mem_d;
    logic [ADDR_WIDTH  - 1:0] pc_new_ex_if;
    logic                     mdu_busy_ex;
    logic [ADDR_WIDTH  - 1:0] csr_mtvec_read_ex_if;
    logic                     log_trace_ex_mem_d;


    // Memory stage signals: Input interface.
    logic [             2:0] result_src_ex_mem_q;
    logic                    mem_we_ex_mem_q;
    logic                    reg_we_ex_mem_q;
    logic                    csr_we_ex_mem_q;
    logic [ADDR_WIDTH - 1:0] pc_plus4_ex_mem_q;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_ex_mem_q;
    logic [DATA_WIDTH - 1:0] imm_ext_ex_mem_q;
    logic [DATA_WIDTH - 1:0] alu_result_ex_mem_q;
    logic [DATA_WIDTH - 1:0] write_data_ex_mem_q;
    logic [             1:0] forward_src_ex_mem_q;
    logic [             2:0] func3_ex_mem_q;
    logic                    mem_access_ex_mem_q;
    logic                    exc_detected_ex_mem_q;
    logic [             4:0] exc_cause_ex_mem_q;
    logic [REG_ADDR_W - 1:0] rd_addr_ex_mem_q;
    logic [CSR_ADDR_W - 1:0] csr_write_addr_ex_mem_q;
    logic [DATA_WIDTH - 1:0] csr_read_data_ex_mem_q;
    logic [INSTR_WIDTH - 1:0] instruction_log_ex_mem_q;
    logic [ADDR_WIDTH - 1:0] pc_log_ex_mem_q;
    logic                    log_trace_ex_mem_q;

    // Memory stage signals: Output interface.
    logic [              2:0] result_src_mem_wb_d;
    logic                     reg_we_mem_wb_d;
    logic                     csr_we_mem_wb_d;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_mem_wb_d;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_mem_wb_d;
    logic [DATA_WIDTH  - 1:0] imm_ext_mem_wb_d;
    logic [DATA_WIDTH  - 1:0] alu_result_mem_wb_d;
    logic [DATA_WIDTH  - 1:0] read_data_mem_wb_d;
    logic                     exc_detected_mem_wb_d;
    logic [              4:0] exc_cause_mem_wb_d;
    logic [REG_ADDR_W  - 1:0] rd_addr_mem_wb_d;
    logic [CSR_ADDR_W  - 1:0] csr_write_addr_mem_wb_d;
    logic [DATA_WIDTH  - 1:0] csr_read_data_mem_wb_d;
    logic [INSTR_WIDTH - 1:0] instruction_log_mem_wb_d;
    logic [ADDR_WIDTH  - 1:0] pc_log_mem_wb_d;
    logic [ADDR_WIDTH  - 1:0] mem_addr_log_mem_wb_d;
    logic [ADDR_WIDTH  - 1:0] mem_write_data_log_mem_wb_d;
    logic                     mem_we_log_mem_wb_d;
    logic                     mem_access_log_mem_wb_d;
    logic                     log_trace_mem_wb_d;


    // Write-back stage signals: Input interface.
    logic [              2:0] result_src_mem_wb_q;
    logic                     reg_we_mem_wb_q;
    logic                     csr_we_mem_wb_q;
    logic [ADDR_WIDTH  - 1:0] pc_plus4_mem_wb_q;
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_mem_wb_q;
    logic [DATA_WIDTH  - 1:0] imm_ext_mem_wb_q;
    logic [DATA_WIDTH  - 1:0] alu_result_mem_wb_q;
    logic [DATA_WIDTH  - 1:0] read_data_mem_wb_q;
    logic                     exc_detected_mem_wb_q;
    logic [              4:0] exc_cause_mem_wb_q;
    logic [REG_ADDR_W  - 1:0] rd_addr_mem_wb_q;
    logic [CSR_ADDR_W  - 1:0] csr_write_addr_mem_wb_q;
    logic [DATA_WIDTH  - 1:0] csr_read_data_mem_wb_q;
    logic [INSTR_WIDTH - 1:0] instruction_log_mem_wb_q;
    logic [ADDR_WIDTH  - 1:0] pc_log_mem_wb_q;
    logic [ADDR_WIDTH  - 1:0] mem_addr_log_mem_wb_q;
    logic [ADDR_WIDTH  - 1:0] mem_write_data_log_mem_wb_q;
    logic                     mem_we_log_mem_wb_q;
    logic                     mem_access_log_mem_wb_q;
    logic                     log_trace_mem_wb_q;


    // MMIO management.
    logic mem_addr_cacheable;
    logic mmio_access;

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------
    assign mem_addr_cacheable = (alu_result_ex_mem_q < DEVICE_BASE);
    assign mmio_access        = mem_access_ex_mem_q && (~mem_addr_cacheable);
    assign mmio_access_type_o = mem_we_ex_mem_q; // 0 - read, 1 - write;
    assign mmio_access_o      = mmio_access;

    always_comb begin
        // Default value.
        mmio_wstrb_o = 4'b0;
        mmio_wdata_o = '0;

        case (func3_ex_mem_q[1:0])
            2'b00: begin // Byte access.
                mmio_wstrb_o = 4'b0001 << axi_read_addr_data_o[1:0];
                mmio_wdata_o = {56'b0, write_data_ex_mem_q[7:0]} << axi_read_addr_data_o[1:0];
            end
            2'b01: begin // Half-word access.
                mmio_wstrb_o = 4'b0011 << axi_read_addr_data_o[1];
                mmio_wdata_o = {48'b0, write_data_ex_mem_q[15:0]} << axi_read_addr_data_o[1];
            end
            2'b10: begin // Word accesss.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = write_data_ex_mem_q;
            end
            2'b11: begin // Double-word access: treated as word access.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = write_data_ex_mem_q;
            end
            default: begin
                mmio_wstrb_o = 4'b0;
                mmio_wdata_o = '0;
            end
        endcase
    end


    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Fetch stage module.
    //-------------------------------------
    fetch_stage # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) STAGE1_FETCH (
        .clk_i                 (clk_i                      ),
        .arst_i                (arst_i                     ),
        .pc_target_addr_i      (pc_target_addr_ex_if       ),
        .branch_mispred_i      (branch_mispred_ex_if       ),
        .stall_if_i            (stall_if_i                 ),
        .instr_we_i            (instr_we_i                 ),
        .instr_block_i         (data_block_i               ),
        .branch_instr_ex_i     (branch_instr_ex_if         ),
        .branch_taken_ex_i     (branch_taken_ex_if         ),
        .btb_way_ex_i          (btb_way_ex_if              ),
        .pc_ex_i               (pc_ex_if                   ),
        .csr_mtvec_read_ex_i   (csr_mtvec_read_ex_if       ),
        .exc_detected_wb_i     (exc_detected_wb_if         ),
        .instruction_o         (instruction_if_id_d        ),
        .pc_plus4_o            (pc_plus4_if_id_d           ),
        .pc_o                  (pc_if_id_d                 ),
        .pc_target_addr_pred_o (pc_target_addr_pred_if_id_d),
        .btb_way_o             (btb_way_if_id_d            ),
        .branch_taken_pred_o   (branch_taken_pred_if_id_d  ),
        .axi_read_addr_o       (axi_read_addr_instr_o      ),
        .icache_hit_o          (icache_hit_o               ),
        .log_trace_o           (log_trace_if_id_d          )
    );

    //------------------------------------------------------------------------------
    // Decode Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_decode PIPE_DEC (
        .clk_i                 (clk_i                      ),
        .arst_i                (arst_i                     ),
        .flush_id_i            (flush_id_i                 ),
        .stall_id_i            (stall_id_i                 ),
        .instr_i               (instruction_if_id_d        ),
        .pc_plus4_i            (pc_plus4_if_id_d           ),
        .pc_i                  (pc_if_id_d                 ),
        .pc_target_addr_pred_i (pc_target_addr_pred_if_id_d),
        .btb_way_i             (btb_way_if_id_d            ),
        .branch_pred_taken_i   (branch_taken_pred_if_id_d  ),
        .log_trace_i           (log_trace_if_id_d          ),
        .instr_o               (instruction_if_id_q        ),
        .pc_plus4_o            (pc_plus4_if_id_q           ),
        .pc_o                  (pc_if_id_q                 ),
        .pc_target_addr_pred_o (pc_target_addr_pred_if_id_q),
        .btb_way_o             (btb_way_if_id_q            ),
        .branch_pred_taken_o   (branch_taken_pred_if_id_q  ),
        .log_trace_o           (log_trace_if_id_q          )
    );

    //-------------------------------------
    // Decode stage module.
    //-------------------------------------
    decode_stage STAGE2_DEC (
        .clk_i                 (clk_i                      ),
        .arst_i                (arst_i                     ),
        .instruction_i         (instruction_if_id_q        ),
        .pc_plus4_i            (pc_plus4_if_id_q           ),
        .pc_i                  (pc_if_id_q                 ),
        .pc_target_addr_pred_i (pc_target_addr_pred_if_id_q),
        .btb_way_i             (btb_way_if_id_q            ),
        .branch_pred_taken_i   (branch_taken_pred_if_id_q  ),
        .rd_write_data_i       (result_wb_id               ),
        .rd_addr_i             (rd_addr_wb_id              ),
        .reg_we_i              (reg_we_wb_id               ),
        .log_trace_i           (log_trace_if_id_q          ),
        .result_src_o          (result_src_id_ex_d         ),
        .alu_control_o         (alu_control_id_ex_d        ),
        .mem_we_o              (mem_we_id_ex_d             ),
        .reg_we_o              (reg_we_id_ex_d             ),
        .csr_we_o              (csr_we_id_ex_d             ),
        .alu_srcA_o            (alu_srcA_id_ex_d           ),
        .alu_srcB_o            (alu_srcB_id_ex_d           ),
        .branch_o              (branch_id_ex_d             ),
        .jump_o                (jump_id_ex_d               ),
        .pc_target_src_o       (pc_target_src_id_ex_d      ),
        .pc_plus4_o            (pc_plus4_id_ex_d           ),
        .pc_o                  (pc_id_ex_d                 ),
        .imm_ext_o             (imm_ext_id_ex_d            ),
        .rs1_data_o            (rs1_data_id_ex_d           ),
        .rs2_data_o            (rs2_data_id_ex_d           ),
        .rs1_addr_o            (rs1_addr_id_ex_d           ),
        .rs2_addr_o            (rs2_addr_id_ex_d           ),
        .rd_addr_o             (rd_addr_id_ex_d            ),
        .csr_addr_o            (csr_addr_id_ex_d           ),
        .func3_o               (func3_id_ex_d              ),
        .forward_src_o         (forward_src_id_ex_d        ),
        .mem_access_o          (mem_access_id_ex_d         ),
        .pc_target_addr_pred_o (pc_target_addr_pred_id_ex_d),
        .btb_way_o             (btb_way_id_ex_d            ),
        .branch_pred_taken_o   (branch_taken_pred_id_ex_d  ),
        .instruction_log_o     (instruction_log_id_ex_d    ),
        .exc_detected_o        (exc_detected_id_ex_d       ),
        .exc_cause_o           (exc_cause_id_ex_d          ),
        .load_instr_o          (load_instr_id_ex_d         ),
        .is_mdu_op_o           (is_mdu_op_id_ex_d          ),
        .is_mdu_word_op_o      (is_mdu_word_op_id_ex_d     ),
        .a0_reg_lsb_o          (a0_reg_lsb                 ),
        .log_trace_o           (log_trace_id_ex_d          )
    );

    //-------------------------------------------------------------------------------
    // Execute Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_execute PIPE_EXEC (
        .clk_i                 (clk_i                      ),
        .arst_i                (arst_i                     ),
        .stall_ex_i            (stall_ex_i                 ),
        .flush_ex_i            (flush_ex_i                 ),
        .result_src_i          (result_src_id_ex_d         ),
        .alu_control_i         (alu_control_id_ex_d        ),
        .mem_we_i              (mem_we_id_ex_d             ),
        .reg_we_i              (reg_we_id_ex_d             ),
        .csr_we_i              (csr_we_id_ex_d             ),
        .alu_srcA_i            (alu_srcA_id_ex_d           ),
        .alu_srcB_i            (alu_srcB_id_ex_d           ),
        .branch_i              (branch_id_ex_d             ),
        .jump_i                (jump_id_ex_d               ),
        .pc_target_src_i       (pc_target_src_id_ex_d      ),
        .pc_plus4_i            (pc_plus4_id_ex_d           ),
        .pc_i                  (pc_id_ex_d                 ),
        .imm_ext_i             (imm_ext_id_ex_d            ),
        .rs1_data_i            (rs1_data_id_ex_d           ),
        .rs2_data_i            (rs2_data_id_ex_d           ),
        .rs1_addr_i            (rs1_addr_id_ex_d           ),
        .rs2_addr_i            (rs2_addr_id_ex_d           ),
        .rd_addr_i             (rd_addr_id_ex_d            ),
        .csr_addr_i            (csr_addr_id_ex_d           ),
        .func3_i               (func3_id_ex_d              ),
        .forward_src_i         (forward_src_id_ex_d        ),
        .mem_access_i          (mem_access_id_ex_d         ),
        .pc_target_addr_pred_i (pc_target_addr_pred_id_ex_d),
        .btb_way_i             (btb_way_id_ex_d            ),
        .branch_pred_taken_i   (branch_taken_pred_id_ex_d  ),
        .instruction_log_i     (instruction_log_id_ex_d    ),
        .exc_detected_i        (exc_detected_id_ex_d       ),
        .exc_cause_i           (exc_cause_id_ex_d          ),
        .load_instr_i          (load_instr_id_ex_d         ),
        .is_mdu_op_i           (is_mdu_op_id_ex_d          ),
        .is_mdu_word_op_i      (is_mdu_word_op_id_ex_d     ),
        .log_trace_i           (log_trace_id_ex_d          ),
        .result_src_o          (result_src_id_ex_q         ),
        .alu_control_o         (alu_control_id_ex_q        ),
        .mem_we_o              (mem_we_id_ex_q             ),
        .reg_we_o              (reg_we_id_ex_q             ),
        .csr_we_o              (csr_we_id_ex_q             ),
        .alu_srcA_o            (alu_srcA_id_ex_q           ),
        .alu_srcB_o            (alu_srcB_id_ex_q           ),
        .branch_o              (branch_instr_id_ex_q       ),
        .jump_o                (jump_id_ex_q               ),
        .pc_target_src_o       (pc_target_src_id_ex_q      ),
        .pc_plus4_o            (pc_plus4_id_ex_q           ),
        .pc_o                  (pc_id_ex_q                 ),
        .imm_ext_o             (imm_ext_id_ex_q            ),
        .rs1_data_o            (rs1_data_id_ex_q           ),
        .rs2_data_o            (rs2_data_id_ex_q           ),
        .rs1_addr_o            (rs1_addr_id_ex_q           ),
        .rs2_addr_o            (rs2_addr_id_ex_q           ),
        .rd_addr_o             (rd_addr_id_ex_q            ),
        .csr_addr_o            (csr_read_addr_id_ex_q      ),
        .func3_o               (func3_id_ex_q              ),
        .forward_src_o         (forward_src_id_ex_q        ),
        .mem_access_o          (mem_access_id_ex_q         ),
        .pc_target_addr_pred_o (pc_target_addr_pred_id_ex_q),
        .btb_way_o             (btb_way_id_ex_q            ),
        .branch_pred_taken_o   (branch_taken_pred_id_ex_q  ),
        .instruction_log_o     (instruction_log_ex_mem_d   ),
        .exc_detected_o        (exc_detected_id_ex_q       ),
        .exc_cause_o           (exc_cause_id_ex_q          ),
        .load_instr_o          (load_instr_id_ex_q         ),
        .is_mdu_op_o           (is_mdu_op_id_ex_q          ),
        .is_mdu_word_op_o      (is_mdu_word_op_id_ex_q     ),
        .log_trace_o           (log_trace_id_ex_q          )
    );

    //-------------------------------------
    // Execute stage module.
    //-------------------------------------
    execute_stage STAGE3_EXEC (
        .clk_i                 (clk_i                      ),
        .arst_i                (arst_i                     ),
        .result_src_i          (result_src_id_ex_q         ),
        .alu_control_i         (alu_control_id_ex_q        ),
        .mem_we_i              (mem_we_id_ex_q             ),
        .reg_we_i              (reg_we_id_ex_q             ),
        .csr_we_i              (csr_we_id_ex_q             ),
        .alu_srcA_i            (alu_srcA_id_ex_q           ),
        .alu_srcB_i            (alu_srcB_id_ex_q           ),
        .branch_i              (branch_instr_id_ex_q       ),
        .jump_i                (jump_id_ex_q               ),
        .pc_target_src_i       (pc_target_src_id_ex_q      ),
        .pc_plus4_i            (pc_plus4_id_ex_q           ),
        .pc_i                  (pc_id_ex_q                 ),
        .imm_ext_i             (imm_ext_id_ex_q            ),
        .rs1_data_i            (rs1_data_id_ex_q           ),
        .rs2_data_i            (rs2_data_id_ex_q           ),
        .rs1_addr_i            (rs1_addr_id_ex_q           ),
        .rs2_addr_i            (rs2_addr_id_ex_q           ),
        .rd_addr_i             (rd_addr_id_ex_q            ),
        .csr_read_addr_i       (csr_read_addr_id_ex_q      ),
        .func3_i               (func3_id_ex_q              ),
        .forward_src_i         (forward_src_id_ex_q        ),
        .mem_access_i          (mem_access_id_ex_q         ),
        .pc_target_addr_pred_i (pc_target_addr_pred_id_ex_q),
        .btb_way_i             (btb_way_id_ex_q            ),
        .branch_pred_taken_i   (branch_taken_pred_id_ex_q  ),
        .exc_detected_i        (exc_detected_id_ex_q       ),
        .exc_cause_i           (exc_cause_id_ex_q          ),
        .load_instr_i          (load_instr_id_ex_q         ),
        .is_mdu_op_i           (is_mdu_op_id_ex_q          ),
        .is_mdu_word_op_i      (is_mdu_word_op_id_ex_q     ),
        .csr_write_addr_i      (csr_write_addr_wb_ex       ),
        .csr_write_data_i      (csr_write_data_wb_ex       ),
        .csr_we_wb_i           (csr_we_wb_ex               ),
        .result_i              (result_wb_ex               ),
        .forward_value_i       (forward_value_mem_ex       ),
        .forward_rs1_ex_i      (forward_rs1_i              ),
        .forward_rs2_ex_i      (forward_rs2_i              ),
        .mcause_write_data_i   (mcause_write_data_wb_ex    ),
        .mcause_we_i           (mcause_we_wb_ex            ),
        .log_trace_i           (log_trace_id_ex_q          ),
        .result_src_o          (result_src_ex_mem_d        ),
        .mem_we_o              (mem_we_ex_mem_d            ),
        .reg_we_o              (reg_we_ex_mem_d            ),
        .csr_we_o              (csr_we_ex_mem_d            ),
        .pc_plus4_o            (pc_plus4_ex_mem_d          ),
        .pc_target_addr_o      (pc_target_addr_ex_mem_d    ),
        .imm_ext_o             (imm_ext_ex_mem_d           ),
        .alu_result_o          (alu_result_ex_mem_d        ),
        .write_data_o          (write_data_ex_mem_d        ),
        .forward_src_o         (forward_src_ex_mem_d       ),
        .func3_o               (func3_ex_mem_d             ),
        .mem_access_o          (mem_access_ex_mem_d        ),
        .exc_detected_o        (exc_detected_ex_mem_d      ),
        .exc_cause_o           (exc_cause_ex_mem_d         ),
        .rd_addr_o             (rd_addr_ex_mem_d           ),
        .csr_write_addr_o      (csr_write_addr_ex_mem_d    ),
        .csr_read_data_o       (csr_read_data_ex_mem_d     ),
        .pc_log_o              (pc_log_ex_mem_d            ),
        .pc_new_o              (pc_new_ex_if               ),
        .rs1_addr_o            (rs1_addr_ex_o              ),
        .rs2_addr_o            (rs2_addr_ex_o              ),
        .branch_mispred_o      (branch_mispred_ex_if       ),
        .branch_instr_ex_o     (branch_instr_ex_if         ),
        .branch_taken_ex_o     (branch_taken_ex_if         ),
        .btb_way_ex_o          (btb_way_ex_if              ),
        .pc_ex_o               (pc_ex_if                   ),
        .load_instr_o          (load_instr_ex_o            ),
        .mdu_busy_o            (mdu_busy_ex                ),
        .csr_mtvec_read_o      (csr_mtvec_read_ex_if       ),
        .log_trace_o           (log_trace_ex_mem_d         )
    );

    assign pc_target_addr_ex_if = pc_new_ex_if;

    //-----------------------------------------------------------------
    // Memory Pipeline Register. With additional signals for stalling.
    //-----------------------------------------------------------------
    pipeline_reg_memory PIPE_MEM (
        .clk_i             (clk_i                   ),
        .arst_i            (arst_i                  ),
        .stall_mem_i       (stall_mem_i             ),
        .result_src_i      (result_src_ex_mem_d     ),
        .mem_we_i          (mem_we_ex_mem_d         ),
        .reg_we_i          (reg_we_ex_mem_d         ),
        .csr_we_i          (csr_we_ex_mem_d         ),
        .pc_plus4_i        (pc_plus4_ex_mem_d       ),
        .pc_target_addr_i  (pc_target_addr_ex_mem_d ),
        .imm_ext_i         (imm_ext_ex_mem_d        ),
        .alu_result_i      (alu_result_ex_mem_d     ),
        .write_data_i      (write_data_ex_mem_d     ),
        .forward_src_i     (forward_src_ex_mem_d    ),
        .func3_i           (func3_ex_mem_d          ),
        .mem_access_i      (mem_access_ex_mem_d     ),
        .exc_detected_i    (exc_detected_ex_mem_d   ),
        .exc_cause_i       (exc_cause_ex_mem_d      ),
        .rd_addr_i         (rd_addr_ex_mem_d        ),
        .csr_write_addr_i  (csr_write_addr_ex_mem_d ),
        .csr_read_data_i   (csr_read_data_ex_mem_d  ),
        .instruction_log_i (instruction_log_ex_mem_d),
        .pc_log_i          (pc_log_ex_mem_d         ),
        .log_trace_i       (log_trace_ex_mem_d      ),
        .result_src_o      (result_src_ex_mem_q     ),
        .mem_we_o          (mem_we_ex_mem_q         ),
        .reg_we_o          (reg_we_ex_mem_q         ),
        .csr_we_o          (csr_we_ex_mem_q         ),
        .pc_plus4_o        (pc_plus4_ex_mem_q       ),
        .pc_target_addr_o  (pc_target_addr_ex_mem_q ),
        .imm_ext_o         (imm_ext_ex_mem_q        ),
        .alu_result_o      (alu_result_ex_mem_q     ),
        .write_data_o      (write_data_ex_mem_q     ),
        .forward_src_o     (forward_src_ex_mem_q    ),
        .func3_o           (func3_ex_mem_q          ),
        .mem_access_o      (mem_access_ex_mem_q     ),
        .exc_detected_o    (exc_detected_ex_mem_q   ),
        .exc_cause_o       (exc_cause_ex_mem_q      ),
        .rd_addr_o         (rd_addr_ex_mem_q        ),
        .csr_write_addr_o  (csr_write_addr_ex_mem_q ),
        .csr_read_data_o   (csr_read_data_ex_mem_q  ),
        .instruction_log_o (instruction_log_ex_mem_q),
        .pc_log_o          (pc_log_ex_mem_q         ),
        .log_trace_o       (log_trace_ex_mem_q      )
    );

    assign axi_read_addr_data_o = alu_result_ex_mem_q;
    assign mem_access_o         = mem_access_ex_mem_q;

    assign csr_we_mem_wb_d          = csr_we_ex_mem_q;
    assign csr_write_addr_mem_wb_d  = csr_write_addr_ex_mem_q;
    assign csr_read_data_mem_wb_d   = csr_read_data_ex_mem_q;
    assign instruction_log_mem_wb_d = instruction_log_ex_mem_q;

    //--------------------------------------------
    // For checking branch prediction accuracy.
    //--------------------------------------------
    logic [ 15:0 ] branch_count;
    logic [ 15:0 ] branch_mispred_count;

    always_ff @(posedge clk_i, posedge arst_i) begin : BRANCH_ACCURACY_CHECK
        if      (arst_i                           ) branch_count <= '0;
        else if (~ stall_if_i & branch_instr_ex_if) branch_count <= branch_count + 15'b1;

        if      (arst_i                             ) branch_mispred_count <= '0;
        else if (~ stall_if_i & branch_mispred_ex_if) branch_mispred_count <= branch_mispred_count + 15'b1;
    end


    //-------------------------------------
    // Memory stage module.
    //-------------------------------------
    memory_stage # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) STAGE4_MEM (
        .clk_i                (clk_i                      ),
        .arst_i               (arst_i                     ),
        .result_src_i         (result_src_ex_mem_q        ),
        .mem_we_i             (mem_we_ex_mem_q            ),
        .reg_we_i             (reg_we_ex_mem_q            ),
        .pc_plus4_i           (pc_plus4_ex_mem_q          ),
        .pc_target_addr_i     (pc_target_addr_ex_mem_q    ),
        .imm_ext_i            (imm_ext_ex_mem_q           ),
        .alu_result_i         (alu_result_ex_mem_q        ),
        .write_data_i         (write_data_ex_mem_q        ),
        .forward_src_i        (forward_src_ex_mem_q       ),
        .func3_i              (func3_ex_mem_q             ),
        .mem_access_i         (mem_access_ex_mem_q        ),
        .exc_detected_i       (exc_detected_ex_mem_q      ),
        .exc_cause_i          (exc_cause_ex_mem_q         ),
        .rd_addr_i            (rd_addr_ex_mem_q           ),
        .mem_block_we_i       (dcache_we_i                ),
        .data_block_i         (data_block_i               ),
        .pc_log_i             (pc_log_ex_mem_q            ),
        .mmio_access_i        (mmio_access                ),
        .mmio_rdata_i         (mmio_rdata_i               ),
        .log_trace_i          (log_trace_ex_mem_q         ),
        .result_src_o         (result_src_mem_wb_d        ),
        .reg_we_o             (reg_we_mem_wb_d            ),
        .pc_plus4_o           (pc_plus4_mem_wb_d          ),
        .pc_target_addr_o     (pc_target_addr_mem_wb_d    ),
        .imm_ext_o            (imm_ext_mem_wb_d           ),
        .alu_result_o         (alu_result_mem_wb_d        ),
        .read_data_o          (read_data_mem_wb_d         ),
        .exc_detected_o       (exc_detected_mem_wb_d      ),
        .exc_cause_o          (exc_cause_mem_wb_d         ),
        .rd_addr_o            (rd_addr_mem_wb_d           ),
        .forward_value_o      (forward_value_mem_ex       ),
        .dcache_hit_o         (dcache_hit_o               ),
        .dcache_dirty_o       (dcache_dirty_o             ),
        .axi_addr_wb_o        (axi_addr_wb_o              ),
        .data_block_o         (data_block_o               ),
        .pc_log_o             (pc_log_mem_wb_d            ),
        .mem_addr_log_o       (mem_addr_log_mem_wb_d      ),
        .mem_write_data_log_o (mem_write_data_log_mem_wb_d),
        .mem_we_log_o         (mem_we_log_mem_wb_d        ),
        .mem_access_log_o     (mem_access_log_mem_wb_d    ),
        .log_trace_o          (log_trace_mem_wb_d         )
    );

    //-------------------------------------------
    // Pipeline register for memory stage.
    //-------------------------------------------
    pipeline_reg_write_back PIPE_WB (
        .clk_i                (clk_i                      ),
        .arst_i               (arst_i                     ),
        .stall_wb_i           (stall_mem_i                ),
        .result_src_i         (result_src_mem_wb_d        ),
        .reg_we_i             (reg_we_mem_wb_d            ),
        .csr_we_i             (csr_we_mem_wb_d            ),
        .pc_plus4_i           (pc_plus4_mem_wb_d          ),
        .pc_target_addr_i     (pc_target_addr_mem_wb_d    ),
        .imm_ext_i            (imm_ext_mem_wb_d           ),
        .alu_result_i         (alu_result_mem_wb_d        ),
        .read_data_i          (read_data_mem_wb_d         ),
        .exc_detected_i       (exc_detected_mem_wb_d      ),
        .exc_cause_i          (exc_cause_mem_wb_d         ),
        .rd_addr_i            (rd_addr_mem_wb_d           ),
        .csr_write_addr_i     (csr_write_addr_mem_wb_d    ),
        .csr_read_data_i      (csr_read_data_mem_wb_d     ),
        .instruction_log_i    (instruction_log_mem_wb_d   ),
        .pc_log_i             (pc_log_mem_wb_d            ),
        .mem_addr_log_i       (mem_addr_log_mem_wb_d      ),
        .mem_write_data_log_i (mem_write_data_log_mem_wb_d),
        .mem_we_log_i         (mem_we_log_mem_wb_d        ),
        .mem_access_log_i     (mem_access_log_mem_wb_d    ),
        .log_trace_i          (log_trace_mem_wb_d         ),
        .result_src_o         (result_src_mem_wb_q        ),
        .reg_we_o             (reg_we_mem_wb_q            ),
        .csr_we_o             (csr_we_mem_wb_q            ),
        .pc_plus4_o           (pc_plus4_mem_wb_q          ),
        .pc_target_addr_o     (pc_target_addr_mem_wb_q    ),
        .imm_ext_o            (imm_ext_mem_wb_q           ),
        .alu_result_o         (alu_result_mem_wb_q        ),
        .read_data_o          (read_data_mem_wb_q         ),
        .exc_detected_o       (exc_detected_mem_wb_q      ),
        .exc_cause_o          (exc_cause_mem_wb_q         ),
        .rd_addr_o            (rd_addr_mem_wb_q           ),
        .csr_write_addr_o     (csr_write_addr_mem_wb_q    ),
        .csr_read_data_o      (csr_read_data_mem_wb_q     ),
        .instruction_log_o    (instruction_log_mem_wb_q   ),
        .pc_log_o             (pc_log_mem_wb_q            ),
        .mem_addr_log_o       (mem_addr_log_mem_wb_q      ),
        .mem_write_data_log_o (mem_write_data_log_mem_wb_q),
        .mem_we_log_o         (mem_we_log_mem_wb_q        ),
        .mem_access_log_o     (mem_access_log_mem_wb_q    ),
        .log_trace_o          (log_trace_mem_wb_q         )
    );

    //-------------------------------------
    // Write-back stage module.
    //-------------------------------------
    write_back_stage STAGE5_WB (
        .result_src_i         (result_src_mem_wb_q        ),
        .reg_we_i             (reg_we_mem_wb_q            ),
        .csr_we_i             (csr_we_mem_wb_q            ),
        .pc_plus4_i           (pc_plus4_mem_wb_q          ),
        .pc_target_addr_i     (pc_target_addr_mem_wb_q    ),
        .imm_ext_i            (imm_ext_mem_wb_q           ),
        .alu_result_i         (alu_result_mem_wb_q        ),
        .read_data_i          (read_data_mem_wb_q         ),
        .exc_detected_i       (exc_detected_mem_wb_q      ),
        .exc_cause_i          (exc_cause_mem_wb_q         ),
        .rd_addr_i            (rd_addr_mem_wb_q           ),
        .csr_write_addr_i     (csr_write_addr_mem_wb_q    ),
        .csr_read_data_i      (csr_read_data_mem_wb_q     ),
        .instruction_log_i    (instruction_log_mem_wb_q   ),
        .pc_log_i             (pc_log_mem_wb_q            ),
        .mem_addr_log_i       (mem_addr_log_mem_wb_q      ),
        .mem_write_data_log_i (mem_write_data_log_mem_wb_q),
        .mem_we_log_i         (mem_we_log_mem_wb_q        ),
        .mem_access_log_i     (mem_access_log_mem_wb_q    ),
        .branch_total_i       (branch_count               ),
        .branch_mispred_i     (branch_mispred_count       ),
        .a0_reg_lsb_i         (a0_reg_lsb                 ),
        .log_trace_i          (log_trace_mem_wb_q         ),
        .result_o             (result_wb_id               ),
        .rd_addr_o            (rd_addr_wb_id              ),
        .csr_write_addr_o     (csr_write_addr_wb_ex       ),
        .reg_we_o             (reg_we_wb_id               ),
        .csr_we_o             (csr_we_wb_ex               ),
        .mcause_write_data_o  (mcause_write_data_wb_ex    ),
        .exc_detected_o       (exc_detected_wb_if         ),
        .csr_write_data_o     (csr_write_data_wb_ex       )
    );

    assign result_wb_ex = result_wb_id;

    assign mcause_we_wb_ex = exc_detected_wb_if;



    //-------------------------------------------------------------
    // Continious assignment of outputs.
    //-------------------------------------------------------------
    assign rd_addr_wb_o        = rd_addr_wb_id;
    assign branch_mispred_ex_o = branch_mispred_ex_if;
    assign mdu_busy_ex_o       = mdu_busy_ex;

    // Pipeline between Dec & Exec.
    assign rs1_addr_id_o = rs1_addr_id_ex_d;
    assign rs2_addr_id_o = rs2_addr_id_ex_d;

    // Pipeline reg between Exec & Mem.
    assign rd_addr_ex_o  = rd_addr_ex_mem_d;
    assign reg_we_mem_o  = reg_we_ex_mem_q;

    // Pipeline reg between Mem & WB.
    assign rd_addr_mem_o = rd_addr_mem_wb_d;
    assign reg_we_wb_o   = reg_we_mem_wb_q;

    assign csr_stall_o = csr_we_id_ex_d || csr_we_ex_mem_d || csr_we_mem_wb_d || csr_we_wb_ex;
    assign exc_stall_o = exc_detected_ex_mem_d || exc_detected_mem_wb_d || exc_detected_wb_if;

    assign log_trace_wb_o = log_trace_mem_wb_q;

endmodule
