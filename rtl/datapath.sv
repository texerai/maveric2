/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 22/06/2026
//------------------------------


// ------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units in all stages of the pipeline
// ------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module datapath
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter BLOCK_WIDTH = 512,
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5,
    parameter CSR_ADDR_W  = 12,
    /* verilator lint_off UNUSEDPARAM */
    parameter INSTR_WIDTH = 32
    /* verilator lint_on UNUSEDPARAM */
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
    input  logic                     flush_mem_i,
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
    output logic                     trap_stall_o,
    output logic                     trap_return_stall_o,
    output logic                     mmio_access_o,
    output logic                     mmio_access_type_o,
    output logic [DATA_WIDTH  - 1:0] mmio_wdata_o,
    output logic [              3:0] mmio_wstrb_o,
    output logic                     log_trace_wb_o
);

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------

    // Pipeline stage signals.
    pipeline_stage_pkg::if_id_t  if_id_d;
    pipeline_stage_pkg::if_id_t  if_id_q;
    pipeline_stage_pkg::id_ex_t  id_ex_d;
    pipeline_stage_pkg::id_ex_t  id_ex_q;
    pipeline_stage_pkg::ex_mem_t ex_mem_d;
    pipeline_stage_pkg::ex_mem_t ex_mem_q;
    pipeline_stage_pkg::mem_wb_t mem_wb_d;
    pipeline_stage_pkg::mem_wb_t mem_wb_q;

    // Fetch stage sideband signals.
    logic [ADDR_WIDTH  - 1:0] pc_target_addr_ex_if;
    logic                     branch_mispred_ex_if;
    logic                     branch_instr_ex_if;
    logic                     branch_taken_ex_if;
    logic [              1:0] btb_way_ex_if;
    logic [ADDR_WIDTH  - 1:0] pc_ex_if;
    logic                     trap_detected_wb_if;
    logic                     trap_return_wb_if;

    // Decode stage sideband signals.
    logic [DATA_WIDTH  - 1:0] result_wb_id;
    logic [REG_ADDR_W  - 1:0] rd_addr_wb_id;
    logic                     reg_we_wb_id;
    logic                     a0_reg_lsb;

    // Execute stage sideband signals.
    logic                     trap_return_wb_ex;
    logic [CSR_ADDR_W  - 1:0] csr_write_addr_wb_ex;
    logic [DATA_WIDTH  - 1:0] csr_write_data_wb_ex;
    logic                     csr_we_wb_ex;
    logic [DATA_WIDTH  - 1:0] result_wb_ex;
    logic [DATA_WIDTH  - 1:0] forward_value_mem_ex;
    logic                     trap_taken_wb_ex;
    logic [              5:0] mcause_write_data_wb_ex;
    logic [DATA_WIDTH  - 1:0] mepc_write_data_wb_ex;
    logic [DATA_WIDTH  - 1:0] mstatus_ex_wb;
    logic [DATA_WIDTH  - 1:0] mtime_val_mem_ex;
    logic                     timer_irq_mem_ex;
    logic                     software_irq_mem_ex;
    logic [ADDR_WIDTH  - 1:0] pc_new_ex_if;
    logic                     mdu_busy_ex;
    logic [ADDR_WIDTH  - 1:0] csr_mtvec_read_ex_if;
    logic [ADDR_WIDTH  - 1:0] csr_mepc_read_ex_if;

    // Memory stage sideband signals.
    logic                     clint_access;

    // Write-back stage sideband signals.
    logic                     trap_return_wb;
    logic                     log_trace_wb;



    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Fetch stage module.
    //-------------------------------------
    fetch_stage # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) STAGE1_FETCH (
        .clk_i               (clk_i                ),
        .arst_i              (arst_i               ),
        .pc_target_addr_i    (pc_target_addr_ex_if ),
        .branch_mispred_i    (branch_mispred_ex_if ),
        .stall_if_i          (stall_if_i           ),
        .instr_we_i          (instr_we_i           ),
        .instr_block_i       (data_block_i         ),
        .branch_instr_ex_i   (branch_instr_ex_if   ),
        .branch_taken_ex_i   (branch_taken_ex_if   ),
        .btb_way_ex_i        (btb_way_ex_if        ),
        .pc_ex_i             (pc_ex_if             ),
        .csr_mtvec_read_ex_i (csr_mtvec_read_ex_if ),
        .trap_detected_wb_i  (trap_detected_wb_if  ),
        .csr_mepc_read_ex_i  (csr_mepc_read_ex_if  ),
        .trap_return_wb_i    (trap_return_wb_if    ),
        .if_id_o             (if_id_d              ),
        .axi_read_addr_o     (axi_read_addr_instr_o),
        .icache_hit_o        (icache_hit_o         )
    );

    //------------------------------------------------------------------------------
    // Decode Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_decode PIPE_DEC (
        .clk_i      (clk_i     ),
        .arst_i     (arst_i    ),
        .flush_id_i (flush_id_i),
        .stall_id_i (stall_id_i),
        .if_id_i    (if_id_d   ),
        .if_id_o    (if_id_q   )
    );

    //-------------------------------------
    // Decode stage module.
    //-------------------------------------
    decode_stage STAGE2_DEC (
        .clk_i           (clk_i        ),
        .arst_i          (arst_i       ),
        .if_id_i         (if_id_q      ),
        .rd_write_data_i (result_wb_id ),
        .rd_addr_i       (rd_addr_wb_id),
        .reg_we_i        (reg_we_wb_id ),
        .id_ex_o         (id_ex_d      ),
        .a0_reg_lsb_o    (a0_reg_lsb   )
    );

    //-------------------------------------------------------------------------------
    // Execute Pipeline Register. With additional signals for stalling and flushing.
    //-------------------------------------------------------------------------------
    pipeline_reg_execute PIPE_EXEC (
        .clk_i      (clk_i     ),
        .arst_i     (arst_i    ),
        .stall_ex_i (stall_ex_i),
        .flush_ex_i (flush_ex_i),
        .id_ex_i    (id_ex_d   ),
        .id_ex_o    (id_ex_q   )
    );

    //-------------------------------------
    // Execute stage module.
    //-------------------------------------
    execute_stage STAGE3_EXEC (
        .clk_i               (clk_i                  ),
        .arst_i              (arst_i                 ),
        .id_ex_i             (id_ex_q                ),
        .trap_return_wb_i    (trap_return_wb_ex      ),
        .csr_write_addr_i    (csr_write_addr_wb_ex   ),
        .csr_write_data_i    (csr_write_data_wb_ex   ),
        .csr_we_wb_i         (csr_we_wb_ex           ),
        .result_i            (result_wb_ex           ),
        .forward_value_i     (forward_value_mem_ex   ),
        .forward_rs1_ex_i    (forward_rs1_i          ),
        .forward_rs2_ex_i    (forward_rs2_i          ),
        .mepc_write_data_i   (mepc_write_data_wb_ex  ),
        .mcause_write_data_i (mcause_write_data_wb_ex),
        .trap_taken_i        (trap_taken_wb_ex       ),
        .mtime_val_i         (mtime_val_mem_ex       ),
        .timer_irq_i         (timer_irq_mem_ex       ),
        .software_irq_i      (software_irq_mem_ex    ),
        .ex_mem_o            (ex_mem_d               ),
        .pc_new_o            (pc_new_ex_if           ),
        .rs1_addr_o          (rs1_addr_ex_o          ),
        .rs2_addr_o          (rs2_addr_ex_o          ),
        .branch_mispred_o    (branch_mispred_ex_if   ),
        .branch_instr_ex_o   (branch_instr_ex_if     ),
        .branch_taken_ex_o   (branch_taken_ex_if     ),
        .btb_way_ex_o        (btb_way_ex_if          ),
        .pc_ex_o             (pc_ex_if               ),
        .load_instr_o        (load_instr_ex_o        ),
        .mdu_busy_o          (mdu_busy_ex            ),
        .csr_mtvec_read_o    (csr_mtvec_read_ex_if   ),
        .csr_mepc_read_o     (csr_mepc_read_ex_if    ),
        .mstatus_read_o      (mstatus_ex_wb          )
    );

    assign pc_target_addr_ex_if = pc_new_ex_if;

    //-----------------------------------------------------------------
    // Memory Pipeline Register. With additional signals for stalling.
    //-----------------------------------------------------------------
    pipeline_reg_memory PIPE_MEM (
        .clk_i       (clk_i      ),
        .arst_i      (arst_i     ),
        .stall_mem_i (stall_mem_i),
        .flush_mem_i (flush_mem_i),
        .ex_mem_i    (ex_mem_d   ),
        .ex_mem_o    (ex_mem_q   )
    );

    assign axi_read_addr_data_o = ex_mem_q.alu_result;
    assign mem_access_o         = ex_mem_q.mem_access & (~clint_access) & (~mmio_access_o);

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
        .clk_i              (clk_i               ),
        .arst_i             (arst_i              ),
        .ex_mem_i           (ex_mem_q            ),
        .mem_block_we_i     (dcache_we_i         ),
        .data_block_i       (data_block_i        ),
        .mmio_rdata_i       (mmio_rdata_i        ),
        .mem_wb_o           (mem_wb_d            ),
        .forward_value_o    (forward_value_mem_ex),
        .dcache_hit_o       (dcache_hit_o        ),
        .dcache_dirty_o     (dcache_dirty_o      ),
        .axi_addr_wb_o      (axi_addr_wb_o       ),
        .data_block_o       (data_block_o        ),
        .mmio_access_o      (mmio_access_o       ),
        .mmio_access_type_o (mmio_access_type_o  ),
        .mmio_wdata_o       (mmio_wdata_o        ),
        .mmio_wstrb_o       (mmio_wstrb_o        ),
        .clint_access_o     (clint_access        ),
        .mtime_val_o        (mtime_val_mem_ex    ),
        .timer_irq_o        (timer_irq_mem_ex    ),
        .software_irq_o     (software_irq_mem_ex )
    );

    //-------------------------------------------
    // Pipeline register for memory stage.
    //-------------------------------------------
    pipeline_reg_write_back PIPE_WB (
        .clk_i      (clk_i      ),
        .arst_i     (arst_i     ),
        .stall_wb_i (stall_mem_i),
        .mem_wb_i   (mem_wb_d   ),
        .mem_wb_o   (mem_wb_q   )
    );

    //-------------------------------------
    // Write-back stage module.
    //-------------------------------------
    write_back_stage STAGE5_WB (
        .clk_i               (clk_i                  ),
        .mem_wb_i            (mem_wb_q               ),
        .branch_total_i      (branch_count           ),
        .branch_mispred_i    (branch_mispred_count   ),
        .a0_reg_lsb_i        (a0_reg_lsb             ),
        .mstatus_i           (mstatus_ex_wb          ),
        .result_o            (result_wb_id           ),
        .rd_addr_o           (rd_addr_wb_id          ),
        .csr_write_addr_o    (csr_write_addr_wb_ex   ),
        .reg_we_o            (reg_we_wb_id           ),
        .csr_we_o            (csr_we_wb_ex           ),
        .mepc_write_data_o   (mepc_write_data_wb_ex  ),
        .mcause_write_data_o (mcause_write_data_wb_ex),
        .trap_detected_o     (trap_detected_wb_if    ),
        .trap_return_o       (trap_return_wb         ),
        .log_trace_o         (log_trace_wb           ),
        .csr_write_data_o    (csr_write_data_wb_ex   )
    );

    assign result_wb_ex = result_wb_id;

    assign trap_taken_wb_ex = trap_detected_wb_if;
    assign trap_return_wb_if = trap_return_wb;
    assign trap_return_wb_ex = trap_return_wb;



    //-------------------------------------------------------------
    // Continious assignment of outputs.
    //-------------------------------------------------------------
    assign rd_addr_wb_o        = rd_addr_wb_id;
    assign branch_mispred_ex_o = branch_mispred_ex_if;
    assign mdu_busy_ex_o       = mdu_busy_ex;

    // Pipeline between Dec & Exec.
    assign rs1_addr_id_o = id_ex_d.rs1_addr;
    assign rs2_addr_id_o = id_ex_d.rs2_addr;

    // Pipeline reg between Exec & Mem.
    assign rd_addr_ex_o  = ex_mem_d.rd_addr;
    assign reg_we_mem_o  = ex_mem_q.reg_we;

    // Pipeline reg between Mem & WB.
    assign rd_addr_mem_o = mem_wb_d.rd_addr;
    assign reg_we_wb_o   = mem_wb_q.reg_we;

    assign csr_stall_o         = id_ex_d.csr_we || ex_mem_d.csr_we || mem_wb_d.csr_we || csr_we_wb_ex;
    assign trap_stall_o        = ex_mem_d.trap_detected || mem_wb_d.trap_detected || trap_detected_wb_if;
    assign trap_return_stall_o = id_ex_d.trap_return || ex_mem_d.trap_return || mem_wb_d.trap_return || trap_return_wb_if;

    assign log_trace_wb_o = log_trace_wb;

endmodule
