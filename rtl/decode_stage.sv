/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 03/07/2026
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the decode stage.
// ----------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module decode_stage
#(
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5,
    parameter CSR_ADDR_W  = 12
)
(
    // Input interface.
    input  logic                       clk_i,
    input  logic                       arst_i,
    input  pipeline_stage_pkg::if_id_t if_id_i,
    input  logic [              1:0]   priv_mode_i,
    input  logic [DATA_WIDTH  - 1:0]   rd_wdata_i,
    input  logic [REG_ADDR_W  - 1:0]   rd_addr_i,
    input  logic                       reg_we_i,

    // Output interface.
    output pipeline_stage_pkg::id_ex_t id_ex_o,
    output logic                       a0_reg_lsb_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------

    // Control signals.
    logic [6:0] op;
    logic [2:0] func3;
    logic [6:0] func7;
    logic [1:0] instr_21_20;

    //
    logic        reg_we;
    logic        rd_zero;

    // Extend imm signal.
    logic [24:0] imm_data;
    logic [ 2:0] imm_src;

    // Register file.
    logic [REG_ADDR_W - 1:0] rs1_addr;
    logic [REG_ADDR_W - 1:0] rs2_addr;
    logic [REG_ADDR_W - 1:0] rd_addr;

    // CSR file.
    logic [CSR_ADDR_W - 1:0] csr_addr;


    //-------------------------------------------
    // Continious assignments for internal nets.
    //-------------------------------------------
    assign op          = if_id_i.instruction[6 :0 ];
    assign func3       = if_id_i.instruction[14:12];
    assign func7       = if_id_i.instruction[31:25];
    assign instr_21_20 = if_id_i.instruction[21:20];
    assign imm_data    = if_id_i.instruction[31:7 ];

    assign rs1_addr = if_id_i.instruction[19:15];
    assign rs2_addr = if_id_i.instruction[24:20];
    assign rd_addr  = if_id_i.instruction[11:7 ];

    assign csr_addr = if_id_i.instruction[31:20];

    // Check if the destination address is zero. If so don't enable we.
    assign rd_zero        = | rd_addr;
    assign id_ex_o.reg_we = reg_we & rd_zero;

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Control unit.
    control_unit CU0 (
        .op_i             (op                    ),
        .func3_i          (func3                 ),
        .func7_i          (func7                 ),
        .instr_21_20_i    (instr_21_20           ),
        .priv_mode_i      (priv_mode_i           ),
        .valid_i          (if_id_i.valid         ),
        .imm_src_o        (imm_src               ),
        .result_src_o     (id_ex_o.result_src    ),
        .alu_control_o    (id_ex_o.alu_control   ),
        .mem_we_o         (id_ex_o.mem_we        ),
        .reg_we_o         (reg_we                ),
        .csr_we_o         (id_ex_o.csr_we        ),
        .alu_srcA_o       (id_ex_o.alu_srcA      ),
        .alu_srcB_o       (id_ex_o.alu_srcB      ),
        .branch_o         (id_ex_o.branch        ),
        .jump_o           (id_ex_o.jump          ),
        .pc_target_src_o  (id_ex_o.pc_target_src ),
        .forward_src_o    (id_ex_o.forward_src   ),
        .mem_access_o     (id_ex_o.mem_access    ),
        .csr_access_o     (id_ex_o.csr_access    ),
        .trap_detected_o  (id_ex_o.trap_detected ),
        .trap_cause_o     (id_ex_o.trap_cause    ),
        .trap_mret_o      (id_ex_o.trap_mret     ),
        .trap_sret_o      (id_ex_o.trap_sret     ),
        .load_instr_o     (id_ex_o.load_instr    ),
        .atomic_lr_o      (id_ex_o.atomic_lr     ),
        .atomic_sc_o      (id_ex_o.atomic_sc     ),
        .atomic_amo_op_o  (id_ex_o.atomic_amo_op ),
        .atomic_alu_op_o  (id_ex_o.atomic_alu_op ),
        .fencei_o         (id_ex_o.fencei        ),
        .is_mdu_op_o      (id_ex_o.is_mdu_op     ),
        .is_mdu_word_op_o (id_ex_o.is_mdu_word_op)
    );

    // Extend immediate module.
    extend_imm EI0 (
        .control_signal_i (imm_src        ),
        .imm_i            (imm_data       ),
        .imm_ext_o        (id_ex_o.imm_ext)
    );

    // Register file.
    register_file REG_FILE0 (
        .clk_i        (clk_i           ),
        .we_3_i       (reg_we_i        ),
        .arst_i       (arst_i          ),
        .addr_1_i     (rs1_addr        ),
        .addr_2_i     (rs2_addr        ),
        .addr_3_i     (rd_addr_i       ),
        .wdata_3_i    (rd_wdata_i      ),
        .a0_reg_lsb_o (a0_reg_lsb_o    ),
        .rdata_1_o    (id_ex_o.rs1_data),
        .rdata_2_o    (id_ex_o.rs2_data)
    );


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign id_ex_o.pc_plus4            = if_id_i.pc_plus4;
    assign id_ex_o.pc                  = if_id_i.pc;
    assign id_ex_o.rs1_addr            = rs1_addr;
    assign id_ex_o.rs2_addr            = rs2_addr;
    assign id_ex_o.rd_addr             = rd_addr;
    assign id_ex_o.csr_addr            = csr_addr;
    assign id_ex_o.func3               = func3;
    assign id_ex_o.pc_target_addr_pred = if_id_i.pc_target_addr_pred;
    assign id_ex_o.btb_way             = if_id_i.btb_way;
    assign id_ex_o.branch_pred_taken   = if_id_i.branch_pred_taken;
    assign id_ex_o.instruction_log     = if_id_i.instruction;

    // Log trace.
    assign id_ex_o.log_trace = if_id_i.log_trace;
endmodule
