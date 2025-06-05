/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file with a flush signal for decode stage pipelining.
// ------------------------------------------------------------------------------------------

module pipeline_reg_execute
// Parameters.
#(
    parameter DATA_WIDTH  = 64,
    parameter ADDR_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter REG_ADDR_W  = 5
)
// Port decleration.
(
    //Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_exec_i,
    input  logic                     flush_exec_i,
    input  logic [INSTR_WIDTH - 1:0] instruction_log_i,
    input  logic                     log_trace_i,
    input  logic [              2:0] result_src_i,
    input  logic [              4:0] alu_control_i,
    input  logic                     mem_we_i,
    input  logic                     reg_we_i,
    input  logic                     alu_src_i,
    input  logic                     branch_i,
    input  logic                     jump_i,
    input  logic                     pc_target_src_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_i,
    input  logic [DATA_WIDTH  - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH  - 1:0] rs1_data_i,
    input  logic [DATA_WIDTH  - 1:0] rs2_data_i,
    input  logic [REG_ADDR_W  - 1:0] rs1_addr_i,
    input  logic [REG_ADDR_W  - 1:0] rs2_addr_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic [              2:0] func3_i,
    input  logic [              1:0] forward_src_i,
    input  logic                     mem_access_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_i,
    input  logic [              1:0] btb_way_i,
    input  logic                     branch_pred_taken_i,
    input  logic                     ecall_instr_i,
    input  logic [              3:0] cause_i,
    input  logic                     load_instr_i,
    
    // Output interface.
    output logic [INSTR_WIDTH - 1:0] instruction_log_o,
    output logic                     log_trace_o,
    output logic [              2:0] result_src_o,
    output logic [              4:0] alu_control_o,
    output logic                     mem_we_o,
    output logic                     reg_we_o,
    output logic                     alu_src_o,
    output logic                     branch_o,
    output logic                     jump_o,
    output logic                     pc_target_src_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [DATA_WIDTH  - 1:0] rs1_data_o,
    output logic [DATA_WIDTH  - 1:0] rs2_data_o,
    output logic [REG_ADDR_W  - 1:0] rs1_addr_o,
    output logic [REG_ADDR_W  - 1:0] rs2_addr_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [              2:0] func3_o,
    output logic [              1:0] forward_src_o,
    output logic                     mem_access_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred_o,
    output logic [              1:0] btb_way_o,
    output logic                     branch_pred_taken_o,
    output logic                     ecall_instr_o,
    output logic [              3:0] cause_o,
    output logic                     load_instr_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            instruction_log_o     <= '0;
            log_trace_o           <= '0;
            result_src_o          <= '0;
            alu_control_o         <= '0;
            mem_we_o              <= '0;
            reg_we_o              <= '0;
            alu_src_o             <= '0;
            branch_o              <= '0;
            jump_o                <= '0;
            pc_target_src_o       <= '0;
            pc_plus4_o            <= '0;
            pc_o                  <= '0;
            imm_ext_o             <= '0;
            rs1_data_o            <= '0;
            rs2_data_o            <= '0;
            rs1_addr_o            <= '0;
            rs2_addr_o            <= '0;
            rd_addr_o             <= '0;
            func3_o               <= '0;
            forward_src_o         <= '0;
            mem_access_o          <= '0;
            pc_target_addr_pred_o <= '0;
            btb_way_o             <= '0;
            branch_pred_taken_o   <= '0;
            ecall_instr_o         <= '0;
            cause_o               <= '0;
            load_instr_o          <= '0;
        end
        else if (flush_exec_i) begin
            instruction_log_o     <= '0;
            log_trace_o           <= '0;
            result_src_o          <= '0;
            alu_control_o         <= '0;
            mem_we_o              <= '0;
            reg_we_o              <= '0;
            alu_src_o             <= '0;
            branch_o              <= '0;
            jump_o                <= '0;
            pc_target_src_o       <= '0;
            pc_plus4_o            <= '0;
            pc_o                  <= '0;
            imm_ext_o             <= '0;
            rs1_data_o            <= '0;
            rs2_data_o            <= '0;
            rs1_addr_o            <= '0;
            rs2_addr_o            <= '0;
            rd_addr_o             <= '0;
            func3_o               <= '0;
            forward_src_o         <= '0;
            mem_access_o          <= '0;
            pc_target_addr_pred_o <= '0;
            btb_way_o             <= '0;
            branch_pred_taken_o   <= '0;
            ecall_instr_o         <= '0;
            cause_o               <= '0;
            load_instr_o          <= '0;
        end
        else if (~ stall_exec_i) begin
            instruction_log_o     <= instruction_log_i;
            log_trace_o           <= log_trace_i;
            result_src_o          <= result_src_i;
            alu_control_o         <= alu_control_i;
            mem_we_o              <= mem_we_i;
            reg_we_o              <= reg_we_i;
            alu_src_o             <= alu_src_i;
            branch_o              <= branch_i;
            jump_o                <= jump_i;
            pc_target_src_o       <= pc_target_src_i;
            pc_plus4_o            <= pc_plus4_i;
            pc_o                  <= pc_i;
            imm_ext_o             <= imm_ext_i;
            rs1_data_o            <= rs1_data_i;
            rs2_data_o            <= rs2_data_i;
            rs1_addr_o            <= rs1_addr_i;
            rs2_addr_o            <= rs2_addr_i;
            rd_addr_o             <= rd_addr_i;
            func3_o               <= func3_i;
            forward_src_o         <= forward_src_i;
            mem_access_o          <= mem_access_i;
            pc_target_addr_pred_o <= pc_target_addr_pred_i;
            btb_way_o             <= btb_way_i;
            branch_pred_taken_o   <= branch_pred_taken_i;
            ecall_instr_o         <= ecall_instr_i;
            cause_o               <= cause_i;
            load_instr_o          <= load_instr_i;
        end
    end
    
endmodule
