/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 22/06/2026
//------------------------------

// ---------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the write-back stage.
// ---------------------------------------------------------------------------------------------

module write_back_stage
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter CSR_ADDR_W  = 12,
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic [              2:0] result_src_i,
    input  logic                     reg_we_i,
    input  logic                     csr_we_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_i,
    input  logic [DATA_WIDTH  - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH  - 1:0] alu_result_i,
    input  logic [DATA_WIDTH  - 1:0] read_data_i,
    input  logic                     trap_detected_i,
    input  logic [              5:0] trap_cause_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic [CSR_ADDR_W  - 1:0] csr_write_addr_i,
    input  logic [DATA_WIDTH  - 1:0] csr_read_data_i,
`ifdef NO_TRACECOMP
    /* verilator lint_off UNUSEDSIGNAL */
`endif
    input  logic [INSTR_WIDTH - 1:0] instruction_log_i,
`ifdef NO_TRACECOMP
    /* verilator lint_on UNUSEDSIGNAL */
`endif
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
`ifdef NO_TRACECOMP
    /* verilator lint_off UNUSEDSIGNAL */
`endif
    input  logic [ADDR_WIDTH  - 1:0] mem_addr_log_i,
    input  logic [DATA_WIDTH  - 1:0] mem_write_data_log_i,
    input  logic                     mem_we_log_i,
    input  logic                     mem_access_log_i,
`ifdef NO_TRACECOMP
    /* verilator lint_on UNUSEDSIGNAL */
`endif
    input  logic [             15:0] branch_total_i,
    input  logic [             15:0] branch_mispred_i,
    input  logic                     a0_reg_lsb_i,
    input  logic                     log_trace_i,

    // Output interface.
    output logic [DATA_WIDTH  - 1:0] result_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [CSR_ADDR_W  - 1:0] csr_write_addr_o,
    output logic                     reg_we_o,
    output logic                     csr_we_o,
    output logic [DATA_WIDTH  - 1:0] mepc_write_data_o,
    output logic [              5:0] mcause_write_data_o,
    output logic                     trap_detected_o,
    output logic [DATA_WIDTH  - 1:0] csr_write_data_o
);

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------
    mux6to1 MUX0 (
        .control_signal_i (result_src_i    ),
        .mux_0_i          (alu_result_i    ),
        .mux_1_i          (read_data_i     ),
        .mux_2_i          (pc_plus4_i      ),
        .mux_3_i          (pc_target_addr_i),
        .mux_4_i          (imm_ext_i       ),
        .mux_5_i          (csr_read_data_i ),
        .mux_o            (result_o        )
    );


    //----------------------------------------
    // Logic for Ecall instruction detection.
    //----------------------------------------
    /* verilator lint_off WIDTH */
    import "DPI-C" function int check(
        byte unsigned a0,
        byte unsigned mcause,
        shortint unsigned branch_total,
        shortint unsigned branch_mispred
    );
    import "DPI-C" function void check_update(
        byte unsigned a0
    );
`ifndef NO_TRACECOMP
    import "DPI-C" function void log_trace(
        longint unsigned pc,            // uint64_t
        int unsigned instruction,       // uint32_t
        longint unsigned reg_val,       // uint64_t
        byte unsigned reg_addr,         // uint8_t
        byte unsigned reg_we,
        byte unsigned mem_access,
        longint unsigned mem_val,
        longint unsigned mem_addr,
        byte unsigned mem_we,
        byte unsigned csr_we,
        shortint unsigned csr_addr,
        longint unsigned csr_data
    );
`endif
`ifdef DROMAJO_COSIM
    import "DPI-C" function void dromajo_step(
        longint unsigned pc,            // uint64_t
        int unsigned insn,              // uint32_t
        longint unsigned wdata,         // uint64_t
        byte unsigned reg_we            // uint8_t
    );
    import "DPI-C" function void dromajo_raise_trap(
        byte unsigned cause              // uint8_t: {interrupt, cause[4:0]}
    );
`endif

    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign rd_addr_o = rd_addr_i;
    assign reg_we_o  = reg_we_i;

    assign csr_write_data_o    = alu_result_i;
    assign csr_write_addr_o    = csr_write_addr_i;
    assign csr_we_o            = csr_we_i;
    assign trap_detected_o     = trap_detected_i;
    assign mepc_write_data_o   = pc_log_i;
    assign mcause_write_data_o = trap_cause_i;

    always_ff @(posedge clk_i) begin
        int check_done;
        logic a0_retired_lsb;

        a0_retired_lsb = (reg_we_i & (rd_addr_i == 5'd10)) ? result_o[0] : a0_reg_lsb_i;

        if (log_trace_i) begin
            check_update({7'b0, a0_retired_lsb});
`ifndef NO_TRACECOMP
            log_trace   (pc_log_i, instruction_log_i, result_o, rd_addr_i, reg_we_i, mem_access_log_i, mem_write_data_log_i, mem_addr_log_i, mem_we_log_i, csr_we_o, csr_write_addr_o, csr_write_data_o);
`endif
`ifdef DROMAJO_COSIM
            if (~(trap_detected_i & trap_cause_i[5])) dromajo_step(pc_log_i, instruction_log_i, result_o, reg_we_i);
`endif
        end

        if (trap_detected_i) begin
`ifdef DROMAJO_COSIM
            dromajo_raise_trap({2'b0, trap_cause_i});
`endif
            check_done = check({7'b0, a0_retired_lsb}, trap_cause_i, branch_total_i, branch_mispred_i);
`ifndef MAVERIC_CONTINUE_AFTER_TRAP
            $finish; // For simulation only.
`else
            if (check_done) $finish; // For simulation only.
`endif
        end
    end
    /* verilator lint_on WIDTH */


endmodule
