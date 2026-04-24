/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------
// MMU: Memory Management Unit
// Coordinates TLB + Page Table Walker for VA→PA
// -----------------------------------------------

module mmu
#(
    parameter VA_WIDTH    = 39,
    parameter PA_WIDTH    = 56,
    parameter DATA_WIDTH  = 64,
    parameter ADDR_WIDTH  = 64
)
(
    // Control signals.
    input  logic                     clk_i,
    input  logic                     arst_i,

    // Translation request (from CPU pipeline).
    input  logic                     trans_req_i,
    input  logic [VA_WIDTH - 1:0]    virt_addr_i,
    input  logic [PA_WIDTH - 1:0]    satp_ppn_i,    // From SATP CSR
    input  logic                     satp_mode_i,   // 1 = Sv39 enabled, 0 = bypass

    // Translation response.
    output logic                     trans_done_o,
    output logic                     page_fault_o,
    output logic [PA_WIDTH - 1:0]    phys_addr_o,

    // TLB management.
    input  logic                     sfence_vma_i,
    input  logic [VA_WIDTH - 1:0]    sfence_va_i,
    input  logic                     flush_tlb_i,

    // Memory interface (to L1 caches for page table walks).
    output logic                     mem_read_req_o,
    output logic [ADDR_WIDTH - 1:0]  mem_read_addr_o,
    input  logic [DATA_WIDTH - 1:0]  mem_read_data_i,
    input  logic                     mem_read_done_i
);

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    logic tlb_hit_s;
    logic [PA_WIDTH - 1:0] tlb_pa_s;

    logic walker_done_s;
    logic walker_fault_s;
    logic [PA_WIDTH - 1:0] walker_pa_s;

    logic tlb_update_we_s;
    logic [VA_WIDTH - 1:0] tlb_update_va_s;
    logic [PA_WIDTH - 1:0] tlb_update_pa_s;

    logic translation_in_progress_s;

    //--------------------------------------------------------------------------
    // TLB Instance
    //--------------------------------------------------------------------------
    tlb #(
        .VA_WIDTH(VA_WIDTH),
        .PA_WIDTH(PA_WIDTH),
        .ENTRY_COUNT(16)
    ) TLB_INST (
        .clk_i(clk_i),
        .arst_i(arst_i),
        .lookup_va_i(virt_addr_i),
        .lookup_hit_o(tlb_hit_s),
        .lookup_pa_o(tlb_pa_s),
        .update_we_i(tlb_update_we_s),
        .update_va_i(tlb_update_va_s),
        .update_pa_i(tlb_update_pa_s),
        .sfence_vma_i(sfence_vma_i),
        .sfence_va_i(sfence_va_i),
        .flush_tlb_i(flush_tlb_i)
    );

    //--------------------------------------------------------------------------
    // Page Table Walker Instance
    //--------------------------------------------------------------------------
    page_table_walker #(
        .VA_WIDTH(VA_WIDTH),
        .PA_WIDTH(PA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) PT_WALKER_INST (
        .clk_i(clk_i),
        .arst_i(arst_i),
        .start_translation_i(trans_req_i && ~tlb_hit_s && satp_mode_i && ~translation_in_progress_s),
        .virtual_addr_i(virt_addr_i),
        .satp_ppn_i(satp_ppn_i),
        .translation_done_o(walker_done_s),
        .page_fault_o(walker_fault_s),
        .physical_addr_o(walker_pa_s),
        .mem_read_req_o(mem_read_req_o),
        .mem_read_addr_o(mem_read_addr_o),
        .mem_read_data_i(mem_read_data_i),
        .mem_read_done_i(mem_read_done_i)
    );

    //--------------------------------------------------------------------------
    // Translation Logic
    //--------------------------------------------------------------------------
    always_comb begin
        // By default: pass through
        trans_done_o = 1'b0;
        page_fault_o = 1'b0;
        phys_addr_o = '0;
        tlb_update_we_s = 1'b0;
        tlb_update_va_s = '0;
        tlb_update_pa_s = '0;

        if (~satp_mode_i) begin
            // MMU disabled (Sv39 mode off) - direct VA→PA (identity mapping)
            if (trans_req_i) begin
                phys_addr_o = {{{PA_WIDTH - VA_WIDTH}{1'b0}}, virt_addr_i};
                trans_done_o = 1'b1;
            end
        end
        else if (tlb_hit_s) begin
            // TLB hit: immediate response
            if (trans_req_i) begin
                phys_addr_o = tlb_pa_s;
                trans_done_o = 1'b1;
            end
        end
        else if (walker_done_s) begin
            // Page table walk completed
            if (walker_fault_s) begin
                page_fault_o = 1'b1;
            end
            else begin
                phys_addr_o = walker_pa_s;
                // Update TLB with new translation
                tlb_update_we_s = 1'b1;
                tlb_update_va_s = virt_addr_i;
                tlb_update_pa_s = walker_pa_s;
            end
            trans_done_o = 1'b1;
        end
    end

    //--------------------------------------------------------------------------
    // Track page table walk in progress
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            translation_in_progress_s <= 1'b0;
        end
        else begin
            if (trans_req_i && ~tlb_hit_s && satp_mode_i) begin
                translation_in_progress_s <= 1'b1;
            end
            else if (walker_done_s) begin
                translation_in_progress_s <= 1'b0;
            end
        end
    end

endmodule
