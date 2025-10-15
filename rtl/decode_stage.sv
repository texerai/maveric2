/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the decode stage.
// ----------------------------------------------------------------------------------------

module decode_stage
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5,
    parameter INSTR_WIDTH = 32
)
(
    // Input interface.
    input  logic                      clk_i,
    input  logic                      arst_i,
    input  logic [INSTR_WIDTH - 1:0 ] instruction_i,
    input  logic [ADDR_WIDTH  - 1:0 ] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0 ] pc_i,
    input  logic [DATA_WIDTH  - 1:0 ] rd_write_data_i,
    input  logic [REG_ADDR_W  - 1:0 ] rd_addr_i,
    input  logic                      reg_we_i,
    input  logic [ADDR_WIDTH  - 1:0 ] pc_target_addr_pred_i,
    input  logic [              1:0 ] btb_way_i,
    input  logic                      branch_pred_taken_i,
    input  logic                      log_trace_i,

    // Output interface.
    output logic [              2:0] func3_o,
    output logic [ADDR_WIDTH  - 1:0] pc_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [DATA_WIDTH  - 1:0] rs1_data_o,
    output logic [DATA_WIDTH  - 1:0] rs2_data_o,
    output logic [REG_ADDR_W  - 1:0] rs1_addr_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [              2:0] result_src_o,
    output logic [              4:0] alu_control_o,
    output logic                     mem_we_o,
    output logic                     reg_we_o,
    output logic                     alu_src_o,
    output logic                     branch_o,
    output logic                     jump_o,
    output logic                     pc_target_src_o,
    output logic [              1:0] forward_src_o,
    output logic                     mem_access_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_o,
    output logic [              1:0] btb_way_o,
    output logic                     branch_pred_taken_o,
    output logic                     ecall_instr_o,
    output logic                     log_trace_o,
    output logic [INSTR_WIDTH - 1:0] instruction_log_o,
    output logic [              3:0] cause_o,
    output logic                     a0_reg_lsb_o,
    output logic                     load_instr_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------

    // Control signals.
    logic [6 :0] op_s;
    logic [2 :0] func3_s;
    logic        func7_5_s;
    logic        instr_25_s;

    //
    logic        reg_we_s;
    logic        rd_zero_s;

    // Extend imm signal.
    logic [24:0] imm_data_s;
    logic [ 2:0] imm_src_s;

    // Register file.
    logic [REG_ADDR_W - 1:0] rs1_addr_s;
    logic [REG_ADDR_W - 1:0] rs2_addr_s;
    logic [REG_ADDR_W - 1:0] rd_addr_s;


    //-------------------------------------------
    // Continious assignments for internal nets.
    //-------------------------------------------
    assign op_s       = instruction_i [6 :0 ];
    assign func3_s    = instruction_i [14:12];
    assign func7_5_s  = instruction_i [30   ];
    assign instr_25_s = instruction_i [25   ];
    assign imm_data_s = instruction_i [31:7 ];

    assign rs1_addr_s = instruction_i [19:15];
    assign rs2_addr_s = instruction_i [24:20];
    assign rd_addr_s  = instruction_i [11:7 ];

    // Check if the destination address is zero. If so don't enable we.
    assign rd_zero_s = | rd_addr_s;
    assign reg_we_o  = reg_we_s & rd_zero_s;

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Control unit.
    control_unit CU0 (
        .op_i            (op_s           ),
        .func3_i         (func3_s        ),
        .func7_5_i       (func7_5_s      ),
        .instr_25_i      (instr_25_s     ),
        .imm_src_o       (imm_src_s      ),
        .result_src_o    (result_src_o   ),
        .alu_control_o   (alu_control_o  ),
        .mem_we_o        (mem_we_o       ),
        .reg_we_o        (reg_we_s       ),
        .alu_src_o       (alu_src_o      ),
        .branch_o        (branch_o       ),
        .jump_o          (jump_o         ),
        .pc_target_src_o (pc_target_src_o),
        .forward_src_o   (forward_src_o  ),
        .mem_access_o    (mem_access_o   ),
        .ecall_instr_o   (ecall_instr_o  ),
        .cause_o         (cause_o        ),
        .load_instr_o    (load_instr_o   )
    );

    // Extend immediate module.
    extend_imm EI0 (
        .control_signal_i (imm_src_s ),
        .imm_i            (imm_data_s),
        .imm_ext_o        (imm_ext_o )
    );

    // Register file.
    register_file REG_FILE0 (
        .clk_i          (clk_i          ),
        .write_en_3_i   (reg_we_i       ),
        .arst_i         (arst_i         ),
        .addr_1_i       (rs1_addr_s     ),
        .addr_2_i       (rs2_addr_s     ),
        .addr_3_i       (rd_addr_i      ),
        .write_data_3_i (rd_write_data_i),
        .a0_reg_lsb_o   (a0_reg_lsb_o   ),
        .read_data_1_o  (rs1_data_o     ),
        .read_data_2_o  (rs2_data_o     )
    );


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign pc_plus4_o            = pc_plus4_i;
    assign pc_o                  = pc_i;
    assign rs1_addr_o            = rs1_addr_s;
    assign rs2_addr_o            = rs2_addr_s;
    assign rd_addr_o             = rd_addr_s;
    assign func3_o               = func3_s;
    assign pc_target_addr_pred_o = pc_target_addr_pred_i;
    assign btb_way_o             = btb_way_i;
    assign branch_pred_taken_o   = branch_pred_taken_i;

    // Log trace.
    assign log_trace_o       = log_trace_i;
    assign instruction_log_o = instruction_i;
endmodule
