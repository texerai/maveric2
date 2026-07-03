/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Yesmurat
// Create Date  : 19/05/2026
// Last Revision: 19/05/2026
//------------------------------

// Performance counter module. Tracks cycle count, retired instructions,
// pipeline stall cycles, I$/D$ hit/miss counts, and branch mispredictions.
// Calls report_perf() via DPI-C in a final block when simulation ends.

`include "maveric_pkg.sv"

module perf_counters
#(
    parameter COUNTER_WIDTH = maveric_pkg::XLEN
)
(
    // Clock and reset.
    input  logic clk_i,
    input  logic arst_i,

    // Instruction retirement: high for one cycle each time an instruction
    // commits at write-back (driven by log_trace_wb from datapath).
    input  logic instr_retired_i,

    // Pipeline stall: high when the fetch stage cannot advance
    // (covers both cache-miss stalls and load-use hazard stalls).
    input  logic stall_i,

    // Instruction cache signals.
    input  logic icache_hit_i,   // I$ hit (combinational from icache)
    input  logic icache_req_i,   // AXI read request for I$ fill (level signal)

    // Data cache signals.
    input  logic dcache_hit_i,   // D$ hit (combinational from dcache)
    input  logic dcache_req_i,   // AXI read request for D$ fill (level signal)
    input  logic mem_access_i,   // Load/store present in memory stage

    // Branch misprediction.
    input  logic branch_mispred_i,

    // Counter outputs.
    output logic [COUNTER_WIDTH - 1:0] cycle_count_o,
    output logic [COUNTER_WIDTH - 1:0] instr_count_o,
    output logic [COUNTER_WIDTH - 1:0] stall_cycles_o,
    output logic [COUNTER_WIDTH - 1:0] icache_hits_o,
    output logic [COUNTER_WIDTH - 1:0] icache_misses_o,
    output logic [COUNTER_WIDTH - 1:0] dcache_hits_o,
    output logic [COUNTER_WIDTH - 1:0] dcache_misses_o,
    output logic [COUNTER_WIDTH - 1:0] branch_mispred_count_o
);

    // Edge detection for I$ and D$ miss pulses.
    // axi_req signals are level-high for the full AXI fill duration;
    // a rising edge marks exactly one new cache miss.

    logic icache_req_q;
    logic dcache_req_q;

    always_ff @(posedge clk_i, posedge arst_i) begin

        if (arst_i) begin
            icache_req_q <= 1'b0;
            dcache_req_q <= 1'b0;
        end

        else begin
            icache_req_q <= icache_req_i;
            dcache_req_q <= dcache_req_i;
        end

    end

    logic icache_miss_pulse;
    logic dcache_miss_pulse;
    assign icache_miss_pulse = icache_req_i & ~icache_req_q;
    assign dcache_miss_pulse = dcache_req_i & ~dcache_req_q;


    // Counters.
    // Total elapsed clock cycles (starts from end of reset).
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) cycle_count_o <= '0;
        else        cycle_count_o <= cycle_count_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // Instructions retired at write-back.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i         ) instr_count_o <= '0;
        else if (instr_retired_i) instr_count_o <= instr_count_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // Cycles where fetch (and thus the whole pipeline) is stalled.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i ) stall_cycles_o <= '0;
        else if (stall_i) stall_cycles_o <= stall_cycles_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // I$ hits: icache hit on a cycle where the pipeline is advancing.
    // Gated by ~stall_i to avoid counting repeated hits for the same
    // address while the pipeline is held (load-use or D$ miss stall).
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i                 ) icache_hits_o <= '0;
        else if (icache_hit_i & ~stall_i) icache_hits_o <= icache_hits_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // I$ misses: one per rising edge of the AXI fill request.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i           ) icache_misses_o <= '0;
        else if (icache_miss_pulse) icache_misses_o <= icache_misses_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // D$ hits: valid memory-stage access that hits the cache.
    // Gated by ~icache_req_i to prevent overcounting when an I$ fill stall
    // holds a D$-hitting instruction in the memory stage for thousands of cycles.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i                                     ) dcache_hits_o <= '0;
        else if (dcache_hit_i & mem_access_i & ~icache_req_i) dcache_hits_o <= dcache_hits_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // D$ misses: one per rising edge of the AXI fill request.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i           ) dcache_misses_o <= '0;
        else if (dcache_miss_pulse) dcache_misses_o <= dcache_misses_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end

    // Branch mispredictions.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i          ) branch_mispred_count_o <= '0;
        else if (branch_mispred_i) branch_mispred_count_o <= branch_mispred_count_o + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1};
    end


    // DPI-C reporting: fires once when $finish is called.
    // import "DPI-C" function void report_perf(
    //     longint unsigned cycle_count,
    //     longint unsigned instr_count,
    //     longint unsigned stall_cycles,
    //     longint unsigned icache_hits,
    //     longint unsigned icache_misses,
    //     longint unsigned dcache_hits,
    //     longint unsigned dcache_misses,
    //     longint unsigned branch_mispred
    // );

    // final begin
    //     report_perf(
    //         cycle_count_o,
    //         instr_count_o,
    //         stall_cycles_o,
    //         icache_hits_o,
    //         icache_misses_o,
    //         dcache_hits_o,
    //         dcache_misses_o,
    //         branch_mispred_count_o
    //     );
    // end

endmodule
