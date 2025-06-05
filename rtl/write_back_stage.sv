/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the write-back stage.
// ---------------------------------------------------------------------------------------------

module write_back_stage
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic [ADDR_WIDTH  - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_i,
    input  logic [DATA_WIDTH  - 1:0] alu_result_i,
    input  logic [DATA_WIDTH  - 1:0] read_data_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic [DATA_WIDTH  - 1:0] imm_ext_i,
    input  logic [              2:0] result_src_i,
    input  logic                     ecall_instr_i,
    input  logic [              3:0] cause_i,
    input  logic [             15:0] branch_total_i,
    input  logic [             15:0] branch_mispred_i,
    input  logic                     a0_reg_lsb_i,
    input  logic                     log_trace_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
    input  logic [INSTR_WIDTH - 1:0] instruction_log_i,
    input  logic [ADDR_WIDTH  - 1:0] mem_addr_log_i,
    input  logic [ADDR_WIDTH  - 1:0] mem_write_data_log_i,
    input  logic                     mem_we_log_i,
    input  logic                     mem_access_log_i,
    input  logic                     reg_we_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] result_o,
    output logic [REG_ADDR_W - 1:0] rd_addr_o,
    output logic                    reg_we_o
);

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------
    mux5to1 MUX0 (
        .control_signal_i (result_src_i    ),
        .mux_0_i          (alu_result_i    ),
        .mux_1_i          (read_data_i     ),
        .mux_2_i          (pc_plus4_i      ),
        .mux_3_i          (pc_target_addr_i),
        .mux_4_i          (imm_ext_i       ),
        .mux_o            (result_o        )
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
        if (ecall_instr_i) begin
            check(a0_reg_lsb_i, cause_i, branch_total_i, branch_mispred_i);
            $finish; // For simulation only.
        end
    end
    /* verilator lint_off WIDTH */


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign rd_addr_o = rd_addr_i;
    assign reg_we_o  = reg_we_i;

    // Log trace.
    always_comb begin
        if (log_trace_i) begin
            log_trace (pc_log_i, instruction_log_i, result_o, rd_addr_i, reg_we_i, mem_access_log_i, mem_write_data_log_i, mem_addr_log_i, mem_we_log_i);
        end
    end


endmodule

