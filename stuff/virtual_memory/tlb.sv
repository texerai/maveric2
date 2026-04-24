/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------
// TLB: Translation Lookaside Buffer
// Caches Virtual Address → Physical Address mappings
// Fully-associative with 16 entries (minimal)
// -----------------------------------------------

module tlb
#(
    parameter VA_WIDTH   = 39,  // Virtual address (Sv39)
    parameter PA_WIDTH   = 56,  // Physical address (44 bits used, 56-bit field)
    parameter ENTRY_COUNT = 16,
    parameter ENTRY_IDX_W = 4   // log2(ENTRY_COUNT)
)
(
    // Control signals.
    input  logic                    clk_i,
    input  logic                    arst_i,

    // Lookup port (read-only, combinatorial).
    input  logic [VA_WIDTH - 1:0]   lookup_va_i,
    output logic                    lookup_hit_o,
    output logic [PA_WIDTH - 1:0]   lookup_pa_o,

    // Update port (write on TLB miss resolved).
    input  logic                    update_we_i,
    input  logic [VA_WIDTH - 1:0]   update_va_i,
    input  logic [PA_WIDTH - 1:0]   update_pa_i,

    // Invalidation.
    input  logic                    sfence_vma_i,  // SFENCE.VMA instruction
    input  logic [VA_WIDTH - 1:0]   sfence_va_i,   // Virtual address to invalidate (ignored if 0)

    // Flush entire TLB.
    input  logic                    flush_tlb_i
);

    //--------------------------------------------------------------------------
    // TLB Entry Structure
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic                  valid;
        logic [VA_WIDTH - 1:0] virtual_addr;
        logic [PA_WIDTH - 1:0] physical_addr;
    } tlb_entry_t;

    tlb_entry_t tlb_entries [ENTRY_COUNT - 1:0];
    logic [ENTRY_IDX_W - 1:0] replacement_ptr;  // Simple round-robin

    //--------------------------------------------------------------------------
    // TLB Lookup Logic (Combinatorial)
    //--------------------------------------------------------------------------
    logic hit_found_s;
    logic [PA_WIDTH - 1:0] pa_found_s;
    integer i;

    always_comb begin
        hit_found_s = 1'b0;
        pa_found_s = '0;

        for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
            if (tlb_entries[i].valid && (tlb_entries[i].virtual_addr[VA_WIDTH-1:12] == lookup_va_i[VA_WIDTH-1:12])) begin
                hit_found_s = 1'b1;
                pa_found_s = tlb_entries[i].physical_addr;
            end
        end
    end

    assign lookup_hit_o = hit_found_s;
    assign lookup_pa_o  = pa_found_s;

    //--------------------------------------------------------------------------
    // TLB Update & Invalidation Logic
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            // Initialize all entries as invalid
            for (int j = 0; j < ENTRY_COUNT; j = j + 1) begin
                tlb_entries[j].valid <= 1'b0;
            end
            replacement_ptr <= '0;
        end
        else if (flush_tlb_i) begin
            // Flush all TLB entries
            for (int j = 0; j < ENTRY_COUNT; j = j + 1) begin
                tlb_entries[j].valid <= 1'b0;
            end
            replacement_ptr <= '0;
        end
        else if (sfence_vma_i) begin
            // SFENCE.VMA: Invalidate specific entry or entire TLB
            if (sfence_va_i == '0) begin
                // Invalidate entire TLB
                for (int j = 0; j < ENTRY_COUNT; j = j + 1) begin
                    tlb_entries[j].valid <= 1'b0;
                end
            end
            else begin
                // Invalidate entry matching VA
                for (int j = 0; j < ENTRY_COUNT; j = j + 1) begin
                    if (tlb_entries[j].virtual_addr[VA_WIDTH-1:12] == sfence_va_i[VA_WIDTH-1:12]) begin
                        tlb_entries[j].valid <= 1'b0;
                    end
                end
            end
        end
        else if (update_we_i) begin
            // Insert new translation using round-robin replacement
            tlb_entries[replacement_ptr].valid         <= 1'b1;
            tlb_entries[replacement_ptr].virtual_addr  <= update_va_i;
            tlb_entries[replacement_ptr].physical_addr <= update_pa_i;
            replacement_ptr <= replacement_ptr + 1'b1;
        end
    end

endmodule
