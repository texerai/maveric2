/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the write-back stage.
// ---------------------------------------------------------------------------------------------

module write_back_stage
#(
    parameter ADDR_WIDTH  = 64,
              DATA_WIDTH  = 64,
              INSTR_WIDTH = 32,
              REG_ADDR_W  = 5
) 
(
    // Input interface.
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc_plus4,
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc_target_addr,
    input  logic [ DATA_WIDTH - 1:0 ] i_alu_result,
    input  logic [ DATA_WIDTH - 1:0 ] i_read_data,
    input  logic [ REG_ADDR_W - 1:0 ] i_rd_addr,
    input  logic [ DATA_WIDTH - 1:0 ] i_imm_ext,
    input  logic [              2:0 ] i_result_src,
    input  logic                      i_ecall_instr,
    input  logic [              3:0 ] i_cause,
    input  logic [             15:0 ] i_branch_total,
    input  logic [             15:0 ] i_branch_mispred,
    input  logic                      i_a0_reg_lsb,
    input  logic                      i_log_trace,
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc_log,
    input  logic [ INSTR_WIDTH - 1:0] i_instruction_log,
    input  logic [ ADDR_WIDTH - 1:0 ] i_mem_addr_log,
    input  logic [ ADDR_WIDTH - 1:0 ] i_mem_write_data_log,
    input  logic                      i_mem_we_log,
		input  logic                      i_mem_access_log,
    input  logic                      i_reg_we,

    // Output interface.
    output logic [ DATA_WIDTH - 1:0 ] o_result,
    output logic [ REG_ADDR_W - 1:0 ] o_rd_addr,
    output logic                      o_reg_we
);

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------
    mux5to1 MUX0 (
        .i_control_signal ( i_result_src     ),
        .i_mux_0          ( i_alu_result     ),
        .i_mux_1          ( i_read_data      ),
        .i_mux_2          ( i_pc_plus4       ),
        .i_mux_3          ( i_pc_target_addr ),
        .i_mux_4          ( i_imm_ext        ),
        .o_mux            ( o_result         )
    );


    //----------------------------------------
    // Logic for Ecall instruction detection.
    //----------------------------------------
    /* verilator lint_off WIDTH */
    import "DPI-C" function void check(byte a0, byte mcause, shortint unsigned branch_total, shortint unsigned branch_mispred);
    import "DPI-C" function void log_trace(
        longint unsigned pc,            // uint64_t
        int unsigned instruction,       // uint32_t
        longint unsigned reg_val,       // uint64_t
        byte unsigned reg_addr,         // uint8_t
        byte unsigned reg_we,
				byte unsigned mem_access,
        longint unsigned mem_val,
        longint unsigned mem_addr,
        byte unsigned mem_we);

    always_comb begin
        if ( i_ecall_instr ) begin
            check(i_a0_reg_lsb, i_cause, i_branch_total, i_branch_mispred); 
            $finish; // For simulation only.
        end
    end
    /* verilator lint_off WIDTH */


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign o_rd_addr = i_rd_addr;
    assign o_reg_we  = i_reg_we;


    // Log trace.
    always_comb begin
        if (i_log_trace) begin
            log_trace (i_pc_log, i_instruction_log, o_result, i_rd_addr, i_reg_we, i_mem_access_log, i_mem_write_data_log, i_mem_addr_log, i_mem_we_log);
        end
    end


endmodule

