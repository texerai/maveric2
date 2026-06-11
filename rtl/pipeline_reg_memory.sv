/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 09/06/2026
//------------------------------

// ------------------------------------------------------------------------------------------
// This is a nonarchitectural register file for execute stage pipelining.
// ------------------------------------------------------------------------------------------

module pipeline_reg_memory
// Parameters.
#(
    parameter DATA_WIDTH  = 64,
    parameter ADDR_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter REG_ADDR_W  = 5,
    parameter CSR_ADDR_W  = 12
)
// Port decleration.
(
    //Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     stall_mem_i,
    input  logic [              2:0] result_src_i,
    input  logic                     mem_we_i,
    input  logic                     reg_we_i,
    input  logic                     csr_we_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_i,
    input  logic [DATA_WIDTH  - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH  - 1:0] alu_result_i,
    input  logic [DATA_WIDTH  - 1:0] write_data_i,
    input  logic [              1:0] forward_src_i,
    input  logic [              2:0] func3_i,
    input  logic                     mem_access_i,
    input  logic                     exc_detected_i,
    input  logic [              3:0] exc_cause_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic [CSR_ADDR_W  - 1:0] csr_write_addr_i,
    input  logic [DATA_WIDTH  - 1:0] csr_read_data_i,
    input  logic [INSTR_WIDTH - 1:0] instruction_log_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
    input  logic                     log_trace_i,

    // Output interface.
    output logic [              2:0] result_src_o,
    output logic                     mem_we_o,
    output logic                     reg_we_o,
    output logic                     csr_we_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [DATA_WIDTH  - 1:0] alu_result_o,
    output logic [DATA_WIDTH  - 1:0] write_data_o,
    output logic [              1:0] forward_src_o,
    output logic [              2:0] func3_o,
    output logic                     mem_access_o,
    output logic                     exc_detected_o,
    output logic [              3:0] exc_cause_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [CSR_ADDR_W  - 1:0] csr_write_addr_o,
    output logic [DATA_WIDTH  - 1:0] csr_read_data_o,
    output logic [INSTR_WIDTH - 1:0] instruction_log_o,
    output logic [ADDR_WIDTH  - 1:0] pc_log_o,
    output logic                     log_trace_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            result_src_o      <= '0;
            mem_we_o          <= '0;
            reg_we_o          <= '0;
            csr_we_o          <= '0;
            pc_plus4_o        <= '0;
            pc_target_addr_o  <= '0;
            imm_ext_o         <= '0;
            alu_result_o      <= '0;
            write_data_o      <= '0;
            forward_src_o     <= '0;
            func3_o           <= '0;
            mem_access_o      <= '0;
            exc_detected_o    <= '0;
            exc_cause_o       <= '0;
            rd_addr_o         <= '0;
            csr_write_addr_o  <= '0;
            csr_read_data_o   <= '0;
            instruction_log_o <= '0;
            pc_log_o          <= '0;
            log_trace_o       <= '0;
        end else if (~ stall_mem_i) begin
            result_src_o      <= result_src_i;
            mem_we_o          <= mem_we_i;
            reg_we_o          <= reg_we_i;
            csr_we_o          <= csr_we_i;
            pc_plus4_o        <= pc_plus4_i;
            pc_target_addr_o  <= pc_target_addr_i;
            imm_ext_o         <= imm_ext_i;
            alu_result_o      <= alu_result_i;
            write_data_o      <= write_data_i;
            forward_src_o     <= forward_src_i;
            func3_o           <= func3_i;
            mem_access_o      <= mem_access_i;
            exc_detected_o    <= exc_detected_i;
            exc_cause_o       <= exc_cause_i;
            rd_addr_o         <= rd_addr_i;
            csr_write_addr_o  <= csr_write_addr_i;
            csr_read_data_o   <= csr_read_data_i;
            instruction_log_o <= instruction_log_i;
            pc_log_o          <= pc_log_i;
            log_trace_o       <= log_trace_i;
        end
    end

endmodule
