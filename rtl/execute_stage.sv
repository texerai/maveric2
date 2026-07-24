/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/07/2026
//------------------------------

// -------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the execute stage.
// -------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"
`include "maveric_pkg.sv"

module execute_stage
#(
    parameter XLEN       = maveric_pkg::XLEN,
    parameter REG_ADDR_W = maveric_pkg::REG_ADDR_W,
    parameter CSR_ADDR_W = maveric_pkg::CSR_ADDR_W
)
(
    // Input interface.
    input  logic                       clk_i,
    input  logic                       arst_i,
    input  pipeline_stage_pkg::id_ex_t id_ex_i,
    input  logic                       trap_mret_wb_i,
    input  logic                       trap_sret_wb_i,
    input  logic [CSR_ADDR_W    - 1:0] csr_waddr_i,
    input  logic [XLEN          - 1:0] csr_wdata_i,
    input  logic                       csr_we_wb_i,
    input  logic [XLEN          - 1:0] result_i,
    input  logic [XLEN          - 1:0] forward_value_i,
    input  logic [                1:0] forward_rs1_ex_i,
    input  logic [                1:0] forward_rs2_ex_i,
    input  logic [XLEN          - 1:0] xepc_wdata_i,
    input  logic [                5:0] xcause_wdata_i,
    input  logic [XLEN          - 1:0] xtval_wdata_i,
    input  logic                       trap_taken_i,
    input  logic [XLEN          - 1:0] mtime_val_i,
    input  logic                       timer_irq_i,
    input  logic                       software_irq_i,
    input  logic                       instr_ret_i,

    // Output interface.
    output pipeline_stage_pkg::ex_mem_t ex_mem_o,
    output logic [                 1:0] priv_mode_o,
    output logic [XLEN           - 1:0] pc_new_o,
    output logic [REG_ADDR_W     - 1:0] rs1_addr_o,
    output logic [REG_ADDR_W     - 1:0] rs2_addr_o,
    output logic                        branch_mispred_o,
    output logic                        branch_instr_ex_o,
    output logic                        branch_taken_ex_o,
    output logic [                 1:0] btb_way_ex_o,
    output logic [XLEN           - 1:0] pc_ex_o,
    output logic                        load_instr_o,
    output logic                        mdu_busy_o,
    output logic [XLEN           - 1:0] csr_xtvec_rdata_o,
    output logic [XLEN           - 1:0] csr_xepc_rdata_o,
    output logic [XLEN           - 1:0] satp_rdata_o,
    output csr_pkg::pmp_t               pmp_data_o,
    output logic [XLEN           - 1:0] csr_wdata_log_o,
    output logic [XLEN           - 1:0] mstatus_rdata_log_o,
    output logic [XLEN           - 1:0] mstatus_rdata_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [XLEN - 1:0] alu_srcA;
    logic [XLEN - 1:0] alu_srcB;
    logic [XLEN - 1:0] forward_srcA;
    logic [XLEN - 1:0] forward_srcB;
    logic [XLEN - 1:0] wdata;
    logic [XLEN - 1:0] csr_rdata;

    logic [XLEN - 1:0] alu_result;
    logic [XLEN - 1:0] mdu_result;
    logic [XLEN - 1:0] pc_plus_imm;
    logic [XLEN - 1:0] rs1_plus_imm;
    logic [XLEN - 1:0] pc_target_addr;

    logic zero_flag;
    logic lt_flag;
    logic ltu_flag;

    logic branch;

    logic [XLEN - 1:0] pc_new;
    logic              branch_taken;
    logic              branch_instr;

    logic       trap_detected;
    logic       trap_detected_instr_addr_ma;
    logic       trap_detected_clint;
    logic       trap_illegal_instr;
    logic       trap_detected_clint_valid;
    logic [5:0] trap_cause_clint;


    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // ALU.
    alu ALU0 (
        .alu_control_i (id_ex_i.alu_control),
        .src_1_i       (alu_srcA           ),
        .src_2_i       (alu_srcB           ),
        .alu_result_o  (alu_result         ),
        .zero_flag_o   (zero_flag          ),
        .lt_flag_o     (lt_flag            ),
        .ltu_flag_o    (ltu_flag           )
    );

    mdu MDU0 (
        .clk_i            (clk_i                  ),
        .arst_i           (arst_i                 ),
        .start_i          (id_ex_i.is_mdu_op      ),
        .is_mdu_word_op_i (id_ex_i.is_mdu_word_op ),
        .op_i             (id_ex_i.func3          ),
        .a_i              (alu_srcA               ),
        .b_i              (forward_srcB           ),
        .c_o              (mdu_result             ),
        .busy_o           (mdu_busy_o             )
    );

    // CSR file.
    csr_file CSR_FILE0 (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .we_i                (csr_we_wb_i        ),
        .csr_write_instr_i   (id_ex_i.csr_we     ),
        .wdata_i             (csr_wdata_i        ),
        .raddr_i             (id_ex_i.csr_addr   ),
        .waddr_i             (csr_waddr_i        ),
        .csr_access_i        (id_ex_i.csr_access ),
        .xepc_wdata_i        (xepc_wdata_i       ),
        .xcause_wdata_i      (xcause_wdata_i     ),
        .xtval_wdata_i       (xtval_wdata_i      ),
        .trap_taken_i        (trap_taken_i       ),
        .trap_mret_i         (trap_mret_wb_i     ),
        .trap_sret_i         (trap_sret_wb_i     ),
        .mtime_val_i         (mtime_val_i        ),
        .timer_irq_i         (timer_irq_i        ),
        .software_irq_i      (software_irq_i     ),
        .instr_ret_i         (instr_ret_i        ),
        .priv_mode_o         (priv_mode_o        ),
        .csr_xtvec_rdata_o   (csr_xtvec_rdata_o  ),
        .csr_xepc_rdata_o    (csr_xepc_rdata_o   ),
        .illegal_instr_o     (trap_illegal_instr ),
        .iqr_detected_o      (trap_detected_clint),
        .trap_cause_o        (trap_cause_clint   ),
        .satp_rdata_o        (satp_rdata_o       ),
        .pmp_data_o          (pmp_data_o         ),
        .csr_wdata_log_o     (csr_wdata_log_o    ),
        .mstatus_rdata_log_o (mstatus_rdata_log_o),
        .mstatus_rdata_o     (mstatus_rdata_o    ),
        .rdata_o             (csr_rdata          )
    );
    assign trap_detected_clint_valid = trap_detected_clint & id_ex_i.log_trace;

    // Adder for target pc value calculation.
    assign pc_plus_imm = id_ex_i.pc + id_ex_i.imm_ext;

    // 3-to-1 ALU SrcA Forwarding MUX.
    mux3to1 MUX_FORWARD_A0 (
        .control_signal_i (forward_rs1_ex_i),
        .mux_0_i          (id_ex_i.rs1_data),
        .mux_1_i          (result_i        ),
        .mux_2_i          (forward_value_i ),
        .mux_o            (forward_srcA    )
    );

    // 2-to-1 ALU SrcA data MUX.
    mux2to1 MUX_ALU_SRC_A0 (
        .control_signal_i (id_ex_i.alu_srcA),
        .mux_0_i          (forward_srcA    ), // Forward out.
        .mux_1_i          (id_ex_i.imm_ext ), // Imm ext.
        .mux_o            (alu_srcA        )
    );

    // 3-to-1 ALU SrcB Forwarding MUX.
    mux3to1 MUX_FORWARD_B0 (
        .control_signal_i (forward_rs2_ex_i),
        .mux_0_i          (id_ex_i.rs2_data),
        .mux_1_i          (result_i        ),
        .mux_2_i          (forward_value_i ),
        .mux_o            (forward_srcB    )
    );
    assign wdata = forward_srcB;

    // 3-to-1 ALU SrcB MUX.
    mux3to1 MUX_ALU_SRC_B0 (
        .control_signal_i (id_ex_i.alu_srcB),
        .mux_0_i          (forward_srcB    ),
        .mux_1_i          (id_ex_i.imm_ext ),
        .mux_2_i          (csr_rdata       ), // CSR Read.
        .mux_o            (alu_srcB        )
    );

    // 2-to-1 PC target src MUX that chooses between PC_PLUS_IMM & RS1_PLUS_IMM.
    assign rs1_plus_imm = {alu_result[XLEN - 1:1], 1'b0};
    mux2to1 MUX3 (
        .control_signal_i (id_ex_i.pc_target_src),
        .mux_0_i          (pc_plus_imm          ),
        .mux_1_i          (rs1_plus_imm         ),
        .mux_o            (pc_target_addr       )
    );

    // 2-to-1 MUX that chooses between PC target calculated & PC_PLUS4.
    mux2to1 MUX4 (
        .control_signal_i (branch_taken    ),
        .mux_0_i          (id_ex_i.pc_plus4),
        .mux_1_i          (pc_target_addr  ),
        .mux_o            (pc_new          )
    );


    //--------------------------------------------------
    // Branch decision & misprediction detection logic.
    //--------------------------------------------------

    // Branch decision logic.
    always_comb begin
        case (id_ex_i.func3)
            3'd0:    branch = id_ex_i.branch & zero_flag;     // beq.
            3'd1:    branch = id_ex_i.branch & (~ zero_flag); // bne.
            3'd4:    branch = id_ex_i.branch & lt_flag;       // blt.
            3'd5:    branch = id_ex_i.branch & (~ lt_flag);   // bge.
            3'd6:    branch = id_ex_i.branch & ltu_flag;      // bltu.
            3'd7:    branch = id_ex_i.branch & (~ ltu_flag);  // breu.
            default: branch = 1'b0;
        endcase
    end

    assign branch_taken      = id_ex_i.jump | branch;
    assign branch_instr      = id_ex_i.jump | id_ex_i.branch;
    assign branch_taken_ex_o = branch_taken;
    assign branch_instr_ex_o = branch_instr;

    // Branch misprediction detection logic.
    assign branch_mispred_o = (id_ex_i.branch_pred_taken ^ branch_taken) | (id_ex_i.branch_pred_taken & (id_ex_i.pc_target_addr_pred != pc_target_addr));

    assign trap_detected_instr_addr_ma = branch_mispred_o ? (|pc_new[1:0]) : (|id_ex_i.pc[1:0]);


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign trap_detected           = id_ex_i.trap_detected | trap_detected_clint_valid | trap_detected_instr_addr_ma | trap_illegal_instr;
    assign ex_mem_o.result_src     = id_ex_i.result_src;
    assign ex_mem_o.mem_we         = id_ex_i.mem_we & (~trap_detected);
    assign ex_mem_o.reg_we         = id_ex_i.reg_we & (~trap_detected);
    assign ex_mem_o.csr_we         = id_ex_i.csr_we & (~trap_detected);
    assign ex_mem_o.pc_plus4       = id_ex_i.pc_plus4;
    assign ex_mem_o.pc_target_addr = pc_target_addr;
    assign ex_mem_o.imm_ext        = id_ex_i.imm_ext;
    assign ex_mem_o.alu_result     = id_ex_i.is_mdu_op ? mdu_result : alu_result;
    assign ex_mem_o.wdata          = wdata;
    assign ex_mem_o.forward_src    = id_ex_i.forward_src;
    assign ex_mem_o.func3          = id_ex_i.func3;
    assign ex_mem_o.mem_access     = id_ex_i.mem_access & (~trap_detected);
    assign ex_mem_o.trap_detected  = trap_detected;

    assign ex_mem_o.trap_mret       = id_ex_i.trap_mret;
    assign ex_mem_o.trap_sret       = id_ex_i.trap_sret;
    assign ex_mem_o.rd_addr         = id_ex_i.rd_addr;
    assign ex_mem_o.csr_waddr       = id_ex_i.csr_addr;
    assign ex_mem_o.csr_rdata       = csr_rdata;
    assign ex_mem_o.instruction_log = id_ex_i.instruction_log;
    assign ex_mem_o.pc_log          = id_ex_i.pc;
    assign pc_new_o                 = pc_new;
    assign rs1_addr_o               = id_ex_i.rs1_addr;
    assign rs2_addr_o               = id_ex_i.rs2_addr;
    assign btb_way_ex_o             = id_ex_i.btb_way;
    assign pc_ex_o                  = id_ex_i.pc;
    assign load_instr_o             = id_ex_i.load_instr;
    assign ex_mem_o.rs2_data        = forward_srcB;
    assign ex_mem_o.atomic_lr       = id_ex_i.atomic_lr;
    assign ex_mem_o.atomic_sc       = id_ex_i.atomic_sc;
    assign ex_mem_o.atomic_amo_op   = id_ex_i.atomic_amo_op;
    assign ex_mem_o.atomic_alu_op   = id_ex_i.atomic_alu_op;
    assign ex_mem_o.fencei          = id_ex_i.fencei;
    assign ex_mem_o.sfence          = id_ex_i.sfence;

    always_comb begin
        ex_mem_o.trap_cause = '0;
        ex_mem_o.xtval      = '0;

        if (id_ex_i.trap_detected) begin
            case (id_ex_i.trap_cause)
                csr_pkg::EXC_INSTR_PAGE_FAULT,
                csr_pkg::EXC_ILLEGAL_INSTR: begin
                    ex_mem_o.trap_cause = id_ex_i.trap_cause;
                    ex_mem_o.xtval      = id_ex_i.xtval;
                end
                csr_pkg::EXC_BREAKPOINT,
                csr_pkg::EXC_U_ENV_CALL,
                csr_pkg::EXC_S_ENV_CALL,
                csr_pkg::EXC_M_ENV_CALL: begin
                    if (trap_illegal_instr) begin
                        ex_mem_o.trap_cause = csr_pkg::EXC_ILLEGAL_INSTR;
                        ex_mem_o.xtval      = {32'b0, id_ex_i.instruction_log};
                    end else if (trap_detected_instr_addr_ma) begin
                        ex_mem_o.trap_cause = csr_pkg::EXC_INSTR_ADDR_MA;
                        ex_mem_o.xtval      = branch_mispred_o ? pc_new : id_ex_i.pc;
                    end else if (trap_detected_clint_valid) begin
                        ex_mem_o.trap_cause = trap_cause_clint;
                        ex_mem_o.xtval      = '0;
                    end
                    else begin
                        ex_mem_o.trap_cause = id_ex_i.trap_cause;
                        ex_mem_o.xtval      = id_ex_i.xtval;
                    end
                end
                default: begin
                    ex_mem_o.trap_cause = id_ex_i.trap_cause;
                    ex_mem_o.xtval      = id_ex_i.xtval;
                end
            endcase
        end else begin
            if (trap_illegal_instr) begin
                ex_mem_o.trap_cause = csr_pkg::EXC_ILLEGAL_INSTR;
                ex_mem_o.xtval      = {32'b0, id_ex_i.instruction_log};
            end else if (trap_detected_instr_addr_ma) begin
                ex_mem_o.trap_cause = csr_pkg::EXC_INSTR_ADDR_MA;
                ex_mem_o.xtval      = branch_mispred_o ? pc_new : id_ex_i.pc;
            end else if (trap_detected_clint_valid) begin
                ex_mem_o.trap_cause = trap_cause_clint;
                ex_mem_o.xtval      = '0;
            end else begin
                ex_mem_o.trap_cause = '0;
                ex_mem_o.xtval      = '0;
            end
        end
    end


    // Log trace.
    assign ex_mem_o.log_trace = id_ex_i.log_trace;

endmodule
