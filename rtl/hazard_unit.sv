/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 16/06/2026
//------------------------------

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
    input  logic [REG_ADDR_W - 1:0] rs1_addr_id_i,
    input  logic [REG_ADDR_W - 1:0] rs1_addr_ex_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_id_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_ex_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_ex_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_mem_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_wb_i,
    input  logic                    reg_we_mem_i,
    input  logic                    reg_we_wb_i,
    input  logic                    branch_mispred_ex_i,
    input  logic                    load_instr_ex_i,
    input  logic                    stall_cache_i,
    input  logic                    mdu_busy_ex_i,
    input  logic                    csr_stall_i,
    input  logic                    exc_stall_i,
    input  logic                    trap_return_stall_i,
    input  logic                    mmio_stall_i,

    // Output interface.
    output logic                    stall_if_o,
    output logic                    stall_id_o,
    output logic                    stall_ex_o,
    output logic                    stall_mem_o,
    output logic                    flush_id_o,
    output logic                    flush_ex_o,
    output logic                    load_stall_o,
    output logic [             1:0] forward_rs1_o,
    output logic [             1:0] forward_rs2_o
);

    logic load_instr_stall;
    logic mdu_stall;

    always_comb begin
        if      ((rs1_addr_ex_i == rd_addr_mem_i) & reg_we_mem_i) forward_rs1_o = 2'b10;
        else if ((rs1_addr_ex_i == rd_addr_wb_i ) & reg_we_wb_i ) forward_rs1_o = 2'b01;
        else                                                      forward_rs1_o = 2'b00;

        if      ((rs2_addr_ex_i == rd_addr_mem_i) & reg_we_mem_i) forward_rs2_o = 2'b10;
        else if ((rs2_addr_ex_i == rd_addr_wb_i ) & reg_we_wb_i ) forward_rs2_o = 2'b01;
        else                                                      forward_rs2_o = 2'b00;

    end

    assign load_instr_stall = load_instr_ex_i & ((rs1_addr_id_i == rd_addr_ex_i) | (rs2_addr_id_i == rd_addr_ex_i));
    assign mdu_stall        = mdu_busy_ex_i;

    assign load_stall_o = load_instr_stall;

    always_comb begin
        // Default values.
        stall_if_o  = 1'b0;
        stall_id_o  = 1'b0;
        stall_ex_o  = 1'b0;
        stall_mem_o = 1'b0;
        flush_id_o  = 1'b0;
        flush_ex_o  = 1'b0;

        if (stall_cache_i) begin
            stall_if_o  = 1'b1;
            stall_id_o  = 1'b1;
            stall_ex_o  = 1'b1;
            stall_mem_o = 1'b1;
        end else if (mmio_stall_i) begin
            stall_if_o  = 1'b1;
            stall_id_o  = 1'b1;
            stall_ex_o  = 1'b1;
            stall_mem_o = 1'b1;
        end else if (load_instr_stall) begin
            stall_if_o  = 1'b1;
            stall_id_o  = 1'b1;
            flush_ex_o  = 1'b1;
        end else if (mdu_stall) begin
            stall_if_o  = 1'b1;
            stall_id_o  = 1'b1;
            stall_ex_o  = 1'b1;
            stall_mem_o = 1'b1;
        end else if (branch_mispred_ex_i) begin
            flush_id_o  = 1'b1;
            flush_ex_o  = 1'b1;
        end else if (exc_stall_i) begin
            flush_id_o  = 1'b1;
            flush_ex_o  = 1'b1;
        end else if (csr_stall_i) begin
            stall_if_o  = 1'b1;
            flush_id_o  = 1'b1;
        end else if (trap_return_stall_i) begin
            flush_id_o  = 1'b1;
        end
    end


endmodule
