/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 22/06/2026
//------------------------------

// ---------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the write-back stage.
// ---------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module write_back_stage
// Parameters.
#(
    parameter DATA_WIDTH  = 64,
    parameter CSR_ADDR_W  = 12,
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic                        clk_i,
    input  pipeline_stage_pkg::mem_wb_t mem_wb_i,
    input  logic [             15:0]    branch_total_i,
    input  logic [             15:0]    branch_mispred_i,
    input  logic                        a0_reg_lsb_i,
`ifndef DROMAJO_COSIM
    /* verilator lint_off UNUSEDSIGNAL */
`endif
    input  logic [DATA_WIDTH  - 1:0] mstatus_i,
`ifndef DROMAJO_COSIM
    /* verilator lint_on UNUSEDSIGNAL */
`endif

    // Output interface.
    output logic [DATA_WIDTH  - 1:0] result_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [CSR_ADDR_W  - 1:0] csr_waddr_o,
    output logic                     reg_we_o,
    output logic                     csr_we_o,
    output logic [DATA_WIDTH  - 1:0] mepc_wdata_o,
    output logic [              5:0] mcause_wdata_o,
    output logic                     trap_detected_o,
    output logic                     trap_return_o,
    output logic                     log_trace_o,
    output logic [DATA_WIDTH  - 1:0] csr_wdata_o
);

`ifdef NO_TRACECOMP
    /* verilator lint_off UNUSEDSIGNAL */
    logic unused_trace_payload;

    assign unused_trace_payload = |{
        mem_wb_i.mem_addr_log,
        mem_wb_i.mem_wdata_log,
        mem_wb_i.mem_we_log,
        mem_wb_i.mem_access_log
    };
    /* verilator lint_on UNUSEDSIGNAL */
`endif

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------
    mux6to1 MUX0 (
        .control_signal_i (mem_wb_i.result_src    ),
        .mux_0_i          (mem_wb_i.alu_result    ),
        .mux_1_i          (mem_wb_i.rdata         ),
        .mux_2_i          (mem_wb_i.pc_plus4      ),
        .mux_3_i          (mem_wb_i.pc_target_addr),
        .mux_4_i          (mem_wb_i.imm_ext       ),
        .mux_5_i          (mem_wb_i.csr_rdata     ),
        .mux_o            (result_o               )
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
        byte unsigned reg_we,           // uint8_t
        longint unsigned mstatus        // uint64_t
    );
    import "DPI-C" function void dromajo_raise_trap(
        byte unsigned cause              // uint8_t: {interrupt, cause[4:0]}
    );
`endif

    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign rd_addr_o = mem_wb_i.rd_addr;
    assign reg_we_o  = mem_wb_i.reg_we;

    assign csr_wdata_o     = mem_wb_i.alu_result;
    assign csr_waddr_o     = mem_wb_i.csr_waddr;
    assign csr_we_o        = mem_wb_i.csr_we;
    assign trap_detected_o = mem_wb_i.trap_detected;
    assign trap_return_o   = mem_wb_i.trap_return;
    assign log_trace_o     = mem_wb_i.log_trace;
    assign mepc_wdata_o    = mem_wb_i.pc_log;
    assign mcause_wdata_o  = mem_wb_i.trap_cause;

    always_ff @(posedge clk_i) begin
        int check_done;
        logic a0_retired_lsb;

        a0_retired_lsb = (mem_wb_i.reg_we & (mem_wb_i.rd_addr == 5'd10)) ? result_o[0] : a0_reg_lsb_i;

        if (mem_wb_i.log_trace) begin
            check_update({7'b0, a0_retired_lsb});
`ifndef NO_TRACECOMP
            log_trace(
                mem_wb_i.pc_log,
                mem_wb_i.instruction_log,
                result_o,
                mem_wb_i.rd_addr,
                mem_wb_i.reg_we,
                mem_wb_i.mem_access_log,
                mem_wb_i.mem_wdata_log,
                mem_wb_i.mem_addr_log,
                mem_wb_i.mem_we_log,
                csr_we_o,
                csr_waddr_o,
                csr_wdata_o
            );
`endif
`ifdef DROMAJO_COSIM
            if (!mem_wb_i.trap_detected || (mem_wb_i.trap_cause >= 6'd8 && mem_wb_i.trap_cause <= 6'd11)) begin
                dromajo_step(mem_wb_i.pc_log, mem_wb_i.instruction_log, result_o, mem_wb_i.reg_we, mstatus_i);
            end
`endif
        end

        if (mem_wb_i.trap_detected) begin
`ifdef DROMAJO_COSIM
            dromajo_raise_trap({2'b0, mem_wb_i.trap_cause});
`endif
            check_done = check({7'b0, a0_retired_lsb}, mem_wb_i.trap_cause, branch_total_i, branch_mispred_i);
`ifndef MAVERIC_CONTINUE_AFTER_TRAP
            $finish; // For simulation only.
`else
            if (check_done) $finish; // For simulation only.
`endif
        end
    end
    /* verilator lint_on WIDTH */


endmodule
