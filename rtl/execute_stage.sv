/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the execute stage.
// -------------------------------------------------------------------------------------------

module execute_stage
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic [ADDR_WIDTH - 1:0] pc_i,
    input  logic [ADDR_WIDTH - 1:0] pc_plus4_i,
    input  logic [DATA_WIDTH - 1:0] rs1_data_i,
    input  logic [DATA_WIDTH - 1:0] rs2_data_i,
    input  logic [REG_ADDR_W - 1:0] rs1_addr_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_i,
    input  logic [DATA_WIDTH - 1:0] imm_ext_i,
    input  logic [             2:0] func3_i,
    input  logic [             2:0] result_src_i,
    input  logic [             4:0] alu_control_i,
    input  logic                    mem_we_i,
    input  logic                    reg_we_i,
    input  logic                    alu_src_i,
    input  logic                    branch_i,
    input  logic                    jump_i,
    input  logic                    pc_target_src_i,
    input  logic [DATA_WIDTH - 1:0] result_i,
    input  logic [DATA_WIDTH - 1:0] forward_value_i,
    input  logic [             1:0] forward_src_i,
    input  logic                    mem_access_i,
    input  logic                    load_instr_i,
    input  logic [             1:0] forward_rs1_exec_i,
    input  logic [             1:0] forward_rs2_exec_i,
    input  logic [ADDR_WIDTH - 1:0] pc_target_addr_pred_i,
    input  logic [             1:0] btb_way_i,
    input  logic                    ecall_instr_i,
    input  logic [             3:0] cause_i,
    input  logic                    branch_pred_taken_i,
    input  logic                    log_trace_i,

    // Output interface.
    output logic [ADDR_WIDTH - 1:0] pc_log_o,
    output logic [ADDR_WIDTH - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH - 1:0] pc_new_o,
    output logic [ADDR_WIDTH - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH - 1:0] alu_result_o,
    output logic [DATA_WIDTH - 1:0] write_data_o,
    output logic [REG_ADDR_W - 1:0] rs1_addr_o,
    output logic [REG_ADDR_W - 1:0] rs2_addr_o,
    output logic [REG_ADDR_W - 1:0] rd_addr_o,
    output logic [DATA_WIDTH - 1:0] imm_ext_o,
    output logic [             2:0] result_src_o,
    output logic [             1:0] forward_src_o,
    output logic                    mem_we_o,
    output logic                    reg_we_o,
    output logic                    branch_mispred_o,
    output logic [             2:0] func3_o,
    output logic                    mem_access_o,
    output logic                    branch_exec_o,
    output logic                    branch_taken_exec_o,
    output logic [             1:0] btb_way_exec_o,
    output logic [ADDR_WIDTH - 1:0] pc_exec_o,
    output logic                    ecall_instr_o,
    output logic [             3:0] cause_o,
    output logic                    log_trace_o,
    output logic                    load_instr_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [DATA_WIDTH - 1:0] alu_srcA_s;
    logic [DATA_WIDTH - 1:0] alu_srcB_s;
    logic [DATA_WIDTH - 1:0] write_data_s;

    logic [DATA_WIDTH - 1:0] alu_result_s;
    logic [ADDR_WIDTH - 1:0] pc_plus_imm_s;
    logic [ADDR_WIDTH - 1:0] rs1_plus_imm_s;
    logic [ADDR_WIDTH - 1:0] pc_target_addr_s;

    logic zero_flag_s;
    logic lt_flag_s;
    logic ltu_flag_s;

    logic branch_s;

    logic [ADDR_WIDTH - 1:0] pc_new_s;
    logic                    branch_taken_s;
    logic                    branch_exec_s;


    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // ALU.
    alu ALU0 (
        .alu_control_i (alu_control_i),
        .src_1_i       (alu_srcA_s   ),
        .src_2_i       (alu_srcB_s   ),
        .alu_result_o  (alu_result_s ),
        .zero_flag_o   (zero_flag_s  ),
        .lt_flag_o     (lt_flag_s    ),
        .ltu_flag_o    (ltu_flag_s   )
    );

    // Adder for target pc value calculation.
    adder ADD_IMM0 (
        .input1_i (pc_i         ),
        .input2_i (imm_ext_i    ),
        .sum_o    (pc_plus_imm_s)
    );

    // 3-to-1 ALU SrcA MUX.
    mux3to1 MUX0 (
        .control_signal_i (forward_rs1_exec_i),
        .mux_0_i          (rs1_data_i        ),
        .mux_1_i          (result_i          ),
        .mux_2_i          (forward_value_i   ),
        .mux_o            (alu_srcA_s        )
    );

    // 3-to-1 write data MUX.
    mux3to1 MUX1 (
        .control_signal_i (forward_rs2_exec_i),
        .mux_0_i          (rs2_data_i        ),
        .mux_1_i          (result_i          ),
        .mux_2_i          (forward_value_i   ),
        .mux_o            (write_data_s      )
    );

    // 2-to-1 ALU SrcB MUX.
    mux2to1 MUX2 (
        .control_signal_i (alu_src_i   ),
        .mux_0_i          (write_data_s),
        .mux_1_i          (imm_ext_i   ),
        .mux_o            (alu_srcB_s  )
    );

    // 2-to-1 PC target src MUX that chooses between PC_PLUS_IMM & RS1_PLUS_IMM.
    assign rs1_plus_imm_s = {alu_result_s[DATA_WIDTH - 1:1], 1'b0};
    mux2to1 MUX3 (
        .control_signal_i (pc_target_src_i ),
        .mux_0_i          (pc_plus_imm_s   ),
        .mux_1_i          (rs1_plus_imm_s  ),
        .mux_o            (pc_target_addr_s)
    );

    // 2-to-1 MUX that chooses between PC target calculated & PC_PLUS4.
    mux2to1 MUX4 (
        .control_signal_i (branch_taken_s  ),
        .mux_0_i          (pc_plus4_i      ),
        .mux_1_i          (pc_target_addr_s),
        .mux_o            (pc_new_s        )
    );


    //--------------------------------------------------
    // Branch decision & misprediction detection logic.
    //--------------------------------------------------

    // Branch decision logic.
    always_comb begin
        case (func3_i)
            3'd0:    branch_s = branch_i & zero_flag_s;     // beq.
            3'd1:    branch_s = branch_i & (~ zero_flag_s); // bne.
            3'd4:    branch_s = branch_i & lt_flag_s;       // blt.
            3'd5:    branch_s = branch_i & (~ lt_flag_s);   // bge.
            3'd6:    branch_s = branch_i & ltu_flag_s;      // bltu.
            3'd7:    branch_s = branch_i & (~ ltu_flag_s);  // breu.
            default: branch_s = 1'b0;
        endcase
    end

    assign branch_taken_s      = jump_i | branch_s;
    assign branch_exec_s       = jump_i | branch_i;
    assign branch_taken_exec_o = branch_taken_s;
    assign branch_exec_o       = branch_exec_s;

    // Branch misprediction detection logic.
    assign branch_mispred_o = (branch_pred_taken_i ^ branch_taken_s) | (branch_pred_taken_i & (pc_target_addr_pred_i != pc_target_addr_s));


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign pc_new_o     = pc_new_s;
    assign rs1_addr_o   = rs1_addr_i;
    assign rs2_addr_o   = rs2_addr_i;
    assign rd_addr_o    = rd_addr_i;
    assign load_instr_o = load_instr_i;

    assign btb_way_exec_o = btb_way_i;
    assign pc_exec_o      = pc_i;

    assign result_src_o     = result_src_i;
    assign mem_we_o         = mem_we_i;
    assign reg_we_o         = reg_we_i;
    assign pc_plus4_o       = pc_plus4_i;
    assign pc_target_addr_o = pc_target_addr_s;
    assign imm_ext_o        = imm_ext_i;
    assign alu_result_o     = alu_result_s;
    assign write_data_o     = write_data_s;
    assign forward_src_o    = forward_src_i;
    assign func3_o          = func3_i;
    assign mem_access_o     = mem_access_i;
    assign ecall_instr_o    = ecall_instr_i;
    assign cause_o          = cause_i;

    // Log trace.
    assign log_trace_o = log_trace_i;
    assign pc_log_o    = pc_i;

endmodule
