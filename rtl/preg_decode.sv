/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file with a flush signal for decode stage pipelining.
// ------------------------------------------------------------------------------------------

module preg_decode
// Parameters.
#(
    parameter DATA_WIDTH  = 64,
              ADDR_WIDTH  = 64,
              REG_ADDR_W  = 5
)
// Port decleration. 
(   
    //Input interface. 
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic                       i_stall_exec,
    input  logic                       i_flush_exec,
    input  logic [               2:0 ] i_result_src,
    input  logic [               4:0 ] i_alu_control,
    input  logic                       i_mem_we,
    input  logic                       i_reg_we,
    input  logic                       i_alu_src,
    input  logic                       i_branch,
    input  logic                       i_jump,
    input  logic                       i_pc_target_src,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_plus4,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc,
    input  logic [ DATA_WIDTH  - 1:0 ] i_imm_ext,
    input  logic [ DATA_WIDTH  - 1:0 ] i_rs1_data,
    input  logic [ DATA_WIDTH  - 1:0 ] i_rs2_data,
    input  logic [ REG_ADDR_W  - 1:0 ] i_rs1_addr,
    input  logic [ REG_ADDR_W  - 1:0 ] i_rs2_addr,
    input  logic [ REG_ADDR_W  - 1:0 ] i_rd_addr,
    input  logic [               2:0 ] i_func3,
    input  logic [               1:0 ] i_forward_src,
    input  logic                       i_mem_access,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_target_pred,
    input  logic [               1:0 ] i_btb_way,
    input  logic                       i_branch_pred_taken,
    input  logic                       i_ecall_instr,
    input  logic [               3:0 ] i_cause,
    input  logic                       i_load_instr,
    
    // Output interface.
    output logic [               2:0 ] o_result_src,
    output logic [               4:0 ] o_alu_control,
    output logic                       o_mem_we,
    output logic                       o_reg_we,
    output logic                       o_alu_src,
    output logic                       o_branch,
    output logic                       o_jump,
    output logic                       o_pc_target_src,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_plus4,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc,
    output logic [ DATA_WIDTH  - 1:0 ] o_imm_ext,
    output logic [ DATA_WIDTH  - 1:0 ] o_rs1_data,
    output logic [ DATA_WIDTH  - 1:0 ] o_rs2_data,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs1_addr,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs2_addr,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr,
    output logic [               2:0 ] o_func3,
    output logic [               1:0 ] o_forward_src,
    output logic                       o_mem_access,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_target_pred,
    output logic [               1:0 ] o_btb_way,
    output logic                       o_branch_pred_taken,
    output logic                       o_ecall_instr,
    output logic [               3:0 ] o_cause,
    output logic                       o_load_instr
);

    // Write logic.
    always_ff @( posedge i_clk, posedge i_arst ) begin 
        if ( i_arst ) begin
            o_result_src        <= '0;
            o_alu_control       <= '0;
            o_mem_we            <= '0;
            o_reg_we            <= '0;
            o_alu_src           <= '0;
            o_branch            <= '0;
            o_jump              <= '0;
            o_pc_target_src     <= '0;
            o_pc_plus4          <= '0;
            o_pc                <= '0;
            o_imm_ext           <= '0;
            o_rs1_data          <= '0;
            o_rs2_data          <= '0;
            o_rs1_addr          <= '0;
            o_rs2_addr          <= '0;
            o_rd_addr           <= '0;
            o_func3             <= '0;
            o_forward_src       <= '0;
            o_mem_access        <= '0;
            o_pc_target_pred    <= '0;
            o_btb_way           <= '0;
            o_branch_pred_taken <= '0;
            o_ecall_instr       <= '0;
            o_cause             <= '0;
            o_load_instr        <= '0;
        end
        else if ( i_flush_exec ) begin
            o_result_src        <= '0;
            o_alu_control       <= '0;
            o_mem_we            <= '0;
            o_reg_we            <= '0;
            o_alu_src           <= '0;
            o_branch            <= '0;
            o_jump              <= '0;
            o_pc_target_src     <= '0;
            o_pc_plus4          <= '0;
            o_pc                <= '0;
            o_imm_ext           <= '0;
            o_rs1_data          <= '0;
            o_rs2_data          <= '0;
            o_rs1_addr          <= '0;
            o_rs2_addr          <= '0;
            o_rd_addr           <= '0;
            o_func3             <= '0;
            o_forward_src       <= '0;
            o_mem_access        <= '0;
            o_pc_target_pred    <= '0;
            o_btb_way           <= '0;
            o_branch_pred_taken <= '0;
            o_ecall_instr       <= '0;
            o_cause             <= '0;
            o_load_instr        <= '0;
        end
        else if ( ~ i_stall_exec ) begin
            o_result_src        <= i_result_src;
            o_alu_control       <= i_alu_control;
            o_mem_we            <= i_mem_we;
            o_reg_we            <= i_reg_we;
            o_alu_src           <= i_alu_src;  
            o_branch            <= i_branch;
            o_jump              <= i_jump;
            o_pc_target_src     <= i_pc_target_src;
            o_pc_plus4          <= i_pc_plus4;
            o_pc                <= i_pc;
            o_imm_ext           <= i_imm_ext;
            o_rs1_data          <= i_rs1_data;
            o_rs2_data          <= i_rs2_data;
            o_rs1_addr          <= i_rs1_addr;
            o_rs2_addr          <= i_rs2_addr;
            o_rd_addr           <= i_rd_addr;
            o_func3             <= i_func3;
            o_forward_src       <= i_forward_src;
            o_mem_access        <= i_mem_access;
            o_pc_target_pred    <= i_pc_target_pred;
            o_btb_way           <= i_btb_way;
            o_branch_pred_taken <= i_branch_pred_taken;
            o_ecall_instr       <= i_ecall_instr;
            o_cause             <= i_cause;
            o_load_instr        <= i_load_instr;
        end
    end
    
endmodule