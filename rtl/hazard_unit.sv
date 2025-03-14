/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------
// This module contains logic for data and conrol hazard managment unit.
// ----------------------------------------------------------------------

module hazard_unit
#(
    parameter REG_ADDR_W  = 5
) 
(
    // Input interface.
    input  logic [ REG_ADDR_W - 1:0 ] i_rs1_addr_dec,
    input  logic [ REG_ADDR_W - 1:0 ] i_rs1_addr_exec,
    input  logic [ REG_ADDR_W - 1:0 ] i_rs2_addr_dec,
    input  logic [ REG_ADDR_W - 1:0 ] i_rs2_addr_exec,
    input  logic [ REG_ADDR_W - 1:0 ] i_rd_addr_exec,
    input  logic [ REG_ADDR_W - 1:0 ] i_rd_addr_mem,
    input  logic [ REG_ADDR_W - 1:0 ] i_rd_addr_wb,
    input  logic                      i_reg_we_mem,
    input  logic                      i_reg_we_wb,
    input  logic                      i_branch_mispred_exec,
    input  logic                      i_load_instr_exec,
    input  logic                      i_stall_cache,

    // Output interface.
    output logic                      o_stall_fetch,
    output logic                      o_stall_dec,
    output logic                      o_stall_exec,
    output logic                      o_stall_mem,
    output logic                      o_flush_dec,
    output logic                      o_flush_exec,
    output logic [              1:0 ] o_forward_rs1, 
    output logic [              1:0 ] o_forward_rs2
);

    logic s_load_instr_stall;
    logic s_flush_dec;

    always_comb begin
        if      ( ( i_rs1_addr_exec == i_rd_addr_mem ) & i_reg_we_mem ) o_forward_rs1 = 2'b10;
        else if ( ( i_rs1_addr_exec == i_rd_addr_wb  ) & i_reg_we_wb  ) o_forward_rs1 = 2'b01;
        else                                                            o_forward_rs1 = 2'b00;

        if      ( ( i_rs2_addr_exec == i_rd_addr_mem ) & i_reg_we_mem ) o_forward_rs2 = 2'b10;
        else if ( ( i_rs2_addr_exec == i_rd_addr_wb  ) & i_reg_we_wb  ) o_forward_rs2 = 2'b01;
        else                                                            o_forward_rs2 = 2'b00;

    end

    assign s_load_instr_stall = i_load_instr_exec & ( ( i_rs1_addr_dec == i_rd_addr_exec ) | ( i_rs2_addr_dec == i_rd_addr_exec ) );

    assign o_stall_fetch = s_load_instr_stall | i_stall_cache;
    assign o_stall_dec   = s_load_instr_stall | i_stall_cache;
    assign o_stall_exec  = i_stall_cache;
    assign o_stall_mem   = i_stall_cache;

    assign s_flush_dec  = i_branch_mispred_exec & (~ i_stall_cache);
    assign o_flush_dec  = s_flush_dec;
    assign o_flush_exec = ( s_load_instr_stall & (~ i_stall_cache)) | s_flush_dec;


endmodule