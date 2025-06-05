/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module contains logic for data and conrol hazard managment unit.
// ----------------------------------------------------------------------

module hazard_unit
// Parameters.
#(
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic [REG_ADDR_W - 1:0] rs1_addr_dec_i,
    input  logic [REG_ADDR_W - 1:0] rs1_addr_exec_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_dec_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_exec_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_exec_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_mem_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_wb_i,
    input  logic                    reg_we_mem_i,
    input  logic                    reg_we_wb_i,
    input  logic                    branch_mispred_exec_i,
    input  logic                    load_instr_exec_i,
    input  logic                    stall_cache_i,

    // Output interface.
    output logic                    stall_fetch_o,
    output logic                    stall_dec_o,
    output logic                    stall_exec_o,
    output logic                    stall_mem_o,
    output logic                    flush_dec_o,
    output logic                    flush_exec_o,
    output logic [             1:0] forward_rs1_o,
    output logic [             1:0] forward_rs2_o
);

    logic load_instr_stall_s;
    logic flush_dec_s;

    always_comb begin
        if      ((rs1_addr_exec_i == rd_addr_mem_i) & reg_we_mem_i) forward_rs1_o = 2'b10;
        else if ((rs1_addr_exec_i == rd_addr_wb_i ) & reg_we_wb_i ) forward_rs1_o = 2'b01;
        else                                                        forward_rs1_o = 2'b00;

        if      ((rs2_addr_exec_i == rd_addr_mem_i) & reg_we_mem_i) forward_rs2_o = 2'b10;
        else if ((rs2_addr_exec_i == rd_addr_wb_i ) & reg_we_wb_i ) forward_rs2_o = 2'b01;
        else                                                        forward_rs2_o = 2'b00;

    end

    assign load_instr_stall_s = load_instr_exec_i & ((rs1_addr_dec_i == rd_addr_exec_i) | (rs2_addr_dec_i == rd_addr_exec_i));

    assign stall_fetch_o = load_instr_stall_s | stall_cache_i;
    assign stall_dec_o   = load_instr_stall_s | stall_cache_i;
    assign stall_exec_o  = stall_cache_i;
    assign stall_mem_o   = stall_cache_i;

    assign flush_dec_s  = branch_mispred_exec_i & (~ stall_cache_i);
    assign flush_dec_o  = flush_dec_s;
    assign flush_exec_o = (load_instr_stall_s & (~ stall_cache_i)) | flush_dec_s;


endmodule
