/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file for memory stage pipelining.
// ------------------------------------------------------------------------------------------

module pipeline_reg_write_back
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
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    stall_wb_i,
    input  logic [ADDR_WIDTH - 1:0] mem_addr_log_i,
    input  logic [ADDR_WIDTH - 1:0] mem_write_data_log_i,
    input  logic                    mem_we_log_i,
    input  logic                    mem_access_log_i,
    input  logic [INSTR_WIDTH - 1:0] instruction_log_i,
    input  logic [ADDR_WIDTH - 1:0] pc_log_i,
    input  logic                    log_trace_i,
    input  logic [             2:0] result_src_i,
    input  logic                    reg_we_i,
    input  logic [ADDR_WIDTH - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH - 1:0] pc_target_addr_i,
    input  logic [DATA_WIDTH - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH - 1:0] alu_result_i,
    input  logic [DATA_WIDTH - 1:0] read_data_i,
    input  logic                    ecall_instr_i,
    input  logic [             3:0] cause_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_i,

    // Output interface.
    output logic [ADDR_WIDTH  - 1:0] mem_addr_log_o,
    output logic [ADDR_WIDTH  - 1:0] mem_write_data_log_o,
    output logic                     mem_we_log_o,
    output logic                     mem_access_log_o,
    output logic [INSTR_WIDTH - 1:0] instruction_log_o,
    output logic [ADDR_WIDTH  - 1:0] pc_log_o,
    output logic                     log_trace_o,
    output logic [              2:0] result_src_o,
    output logic                     reg_we_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [DATA_WIDTH  - 1:0] alu_result_o,
    output logic [DATA_WIDTH  - 1:0] read_data_o,
    output logic                     ecall_instr_o,
    output logic [              3:0] cause_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o
  );

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
        mem_addr_log_o       <= '0;
        mem_write_data_log_o <= '0;
        mem_we_log_o         <= '0;
        mem_access_log_o     <= '0;
        instruction_log_o    <= '0;
        pc_log_o             <= '0;
        result_src_o         <= '0;
        reg_we_o             <= '0;
        pc_plus4_o           <= '0;
        pc_target_addr_o     <= '0;
        imm_ext_o            <= '0;
        alu_result_o         <= '0;
        read_data_o          <= '0;
        ecall_instr_o        <= '0;
        cause_o              <= '0;
        rd_addr_o            <= '0;
      end
      else if (~ stall_wb_i) begin
        mem_addr_log_o       <= mem_addr_log_i;
        mem_write_data_log_o <= mem_write_data_log_i;
        mem_we_log_o         <= mem_we_log_i;
        mem_access_log_o     <= mem_access_log_i;
        instruction_log_o    <= instruction_log_i;
        pc_log_o             <= pc_log_i;
        result_src_o         <= result_src_i;
        reg_we_o             <= reg_we_i;
        pc_plus4_o           <= pc_plus4_i;
        pc_target_addr_o     <= pc_target_addr_i;
        imm_ext_o            <= imm_ext_i;
        alu_result_o         <= alu_result_i;
        read_data_o          <= read_data_i;
        ecall_instr_o        <= ecall_instr_i;
        cause_o              <= cause_i;
        rd_addr_o            <= rd_addr_i;
      end

      if (arst_i)
        log_trace_o <= '0;
      else
        log_trace_o <= log_trace_i & (~ stall_wb_i);
    end


endmodule
