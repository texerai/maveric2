/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 16/07/2026
//------------------------------

// ---------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the write-back stage.
// ---------------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"
`include "maveric_pkg.sv"

module write_back_stage
// Parameters.
#(
    parameter XLEN        = maveric_pkg::XLEN,
    parameter CSR_ADDR_W  = maveric_pkg::CSR_ADDR_W,
    parameter REG_ADDR_W  = maveric_pkg::REG_ADDR_W
)
(
    // Input interface.
    input  logic                        clk_i,
    input  pipeline_stage_pkg::mem_wb_t mem_wb_i,
    input  logic [                15:0] branch_total_i,
    input  logic [                15:0] branch_mispred_i,
    input  logic                        a0_reg_lsb_i,
`ifndef DROMAJO_COSIM
    /* verilator lint_off UNUSEDSIGNAL */
`endif
    input  logic [XLEN           - 1:0] mstatus_log_i,
    input  logic [XLEN           - 1:0] csr_wdata_log_i,
    input  logic [                 1:0] priv_mode_log_i,
`ifndef DROMAJO_COSIM
    /* verilator lint_on UNUSEDSIGNAL */
`endif

    // Output interface.
    output logic [XLEN        - 1:0] result_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [CSR_ADDR_W  - 1:0] csr_waddr_o,
    output logic                     reg_we_o,
    output logic                     csr_we_o,
    output logic [XLEN        - 1:0] xepc_wdata_o,
    output logic [              5:0] xcause_wdata_o,
    output logic [XLEN        - 1:0] xtval_wdata_o,
    output logic                     trap_detected_o,
    output logic                     trap_return_o,
    output logic                     trap_mret_o,
    output logic                     trap_sret_o,
    output logic                     sfence_o,
    output logic                     instr_ret_o,
    output logic                     log_trace_o,
    output logic [XLEN        - 1:0] csr_wdata_o
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



    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign rd_addr_o = mem_wb_i.rd_addr;
    assign reg_we_o  = mem_wb_i.reg_we;

    assign csr_wdata_o     = mem_wb_i.alu_result;
    assign csr_waddr_o     = mem_wb_i.csr_waddr;
    assign csr_we_o        = mem_wb_i.csr_we;



    //----------------------------------------
    // Current privilige mode register
    // and trap commit.
    //----------------------------------------
    assign trap_detected_o = mem_wb_i.trap_detected;
    assign trap_return_o   = mem_wb_i.trap_mret | mem_wb_i.trap_sret;
    assign trap_mret_o     = mem_wb_i.trap_mret;
    assign trap_sret_o     = mem_wb_i.trap_sret;
    assign log_trace_o     = mem_wb_i.log_trace;
    assign xepc_wdata_o    = mem_wb_i.pc_log;
    assign xcause_wdata_o  = mem_wb_i.trap_cause;
    assign xtval_wdata_o   = mem_wb_i.xtval;
    assign sfence_o        = mem_wb_i.sfence;
    assign instr_ret_o     = mem_wb_i.log_trace && ((!mem_wb_i.trap_detected) |
                           ((mem_wb_i.trap_detected) && ((mem_wb_i.trap_cause == 6'd3) | (mem_wb_i.trap_cause == 6'd8) | (mem_wb_i.trap_cause == 6'd9) | (mem_wb_i.trap_cause == 6'd11))));



`ifndef NO_TRACECOMP
    logic                    trace_csr_we;
    logic [CSR_ADDR_W - 1:0] trace_csr_addr;
    logic [XLEN       - 1:0] trace_csr_data;

    always_comb begin
        trace_csr_we   = csr_we_o;
        trace_csr_addr = csr_waddr_o;
        trace_csr_data = csr_wdata_log_i;

        if (csr_we_o && ((csr_waddr_o == csr_pkg::CSR_MSTATUS) | (csr_waddr_o == csr_pkg::CSR_SSTATUS))) begin
                trace_csr_addr = csr_pkg::CSR_MSTATUS;
                trace_csr_data = mstatus_log_i;
        end

        if (mem_wb_i.trap_mret | mem_wb_i.trap_sret) begin
            trace_csr_we   = 1'b1;
            trace_csr_addr = csr_pkg::CSR_MSTATUS;
            trace_csr_data = mstatus_log_i;
        end
    end
`endif





    //----------------------------------------
    // Logic for Ecall instruction detection.
    //----------------------------------------
    /* verilator lint_off WIDTH */
    import "DPI-C" function int check(
        byte unsigned a0,
        byte unsigned trap_cause,
        shortint unsigned branch_total,
        shortint unsigned branch_mispred,
        longint unsigned pc
    );
    import "DPI-C" function void check_update(
        byte unsigned a0
    );
    import "DPI-C" function int check_self_loop(
        byte unsigned a0
    );
`ifndef NO_TRACECOMP
    import "DPI-C" function void log_trace(
        byte unsigned priv_mode,
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
    // Simulation.
    //--------------------------------------
    always_ff @(posedge clk_i) begin
        int check_done;
        logic a0_retired_lsb;

        a0_retired_lsb = (mem_wb_i.reg_we & (mem_wb_i.rd_addr == 5'd10)) ? result_o[0] : a0_reg_lsb_i;

        if (mem_wb_i.log_trace) begin
`ifndef NO_TRACECOMP
            log_trace(
                priv_mode_log_i,
                mem_wb_i.pc_log,
                mem_wb_i.instruction_log,
                result_o,
                mem_wb_i.rd_addr,
                mem_wb_i.reg_we,
                mem_wb_i.mem_access_log,
                mem_wb_i.mem_wdata_log,
                mem_wb_i.mem_addr_log,
                mem_wb_i.mem_we_log,
                trace_csr_we,
                trace_csr_addr,
                trace_csr_data
            );
`endif
`ifdef DROMAJO_COSIM
            if (!mem_wb_i.trap_detected || (mem_wb_i.trap_cause >= 6'd8 && mem_wb_i.trap_cause <= 6'd11)) begin
                dromajo_step(mem_wb_i.pc_log, mem_wb_i.instruction_log, result_o, mem_wb_i.reg_we, mstatus_log_i);
            end
`endif
        end

        if (mem_wb_i.trap_detected) begin
`ifdef DROMAJO_COSIM
            dromajo_raise_trap({2'b0, mem_wb_i.trap_cause});
`endif
            if (((mem_wb_i.trap_cause == 6'd3) | (mem_wb_i.trap_cause == 6'd8) | (mem_wb_i.trap_cause == 6'd9) | (mem_wb_i.trap_cause == 6'd11))) begin
                check_update({7'b0, a0_retired_lsb});
            end
            check_done = check({7'b0, a0_retired_lsb}, mem_wb_i.trap_cause, branch_total_i, branch_mispred_i, mem_wb_i.pc_log);
            if (check_done) $finish; // For simulation only.
        end

`ifndef MAVERIC_SELF_LOOP_CONTINUE
        if (mem_wb_i.log_trace && !mem_wb_i.trap_detected
            && (mem_wb_i.instruction_log == 32'h0000006f)) begin
            check_done = check_self_loop({7'b0, a0_retired_lsb});
            if (check_done) $finish; // For simulation only.
        end
`endif
    end
    /* verilator lint_on WIDTH */


endmodule
