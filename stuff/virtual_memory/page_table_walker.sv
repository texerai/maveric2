/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------
// Page Table Walker: Traverses Sv39 page tables in memory
// RISC-V Privileged Spec: 3-level hierarchical page tables
// ----------------------------------------------------------

module page_table_walker
#(
    parameter VA_WIDTH    = 39,
    parameter PA_WIDTH    = 56,
    parameter DATA_WIDTH  = 64,
    parameter ADDR_WIDTH  = 64
)
(
    // Control signals.
    input  logic                      clk_i,
    input  logic                      arst_i,

    // Start translation request.
    input  logic                      start_translation_i,
    input  logic [VA_WIDTH - 1:0]     virtual_addr_i,
    input  logic [PA_WIDTH - 1:0]     satp_ppn_i,  // Root page table from SATP

    // Translation result.
    output logic                      translation_done_o,
    output logic                      page_fault_o,  // Page fault exception
    output logic [PA_WIDTH - 1:0]     physical_addr_o,

    // Memory interface (for page table access).
    output logic                      mem_read_req_o,
    output logic [ADDR_WIDTH - 1:0]   mem_read_addr_o,
    input  logic [DATA_WIDTH - 1:0]   mem_read_data_i,
    input  logic                      mem_read_done_i
);

    //--------------------------------------------------------------------------
    // Sv39 Page Table Entry (PTE) Structure (64-bit)
    // [9:0]   - Flags (D, A, G, U, X, W, R, V, etc.)
    // [53:10] - Physical Page Number (PPN)
    // [63:54] - Reserved
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic [9:0]  flags;    // [9:0] - V, R, W, X, U, G, A, D, RSW, PBMT
        logic [43:0] ppn;      // [53:10] - Physical Page Number
        logic [10:0] reserved; // [63:54]
    } pte_t;

    // PTE flag definitions
    localparam PTE_V = 10'd0;  // Valid bit
    localparam PTE_R = 10'd1;  // Readable
    localparam PTE_W = 10'd2;  // Writable
    localparam PTE_X = 10'd3;  // Executable
    localparam PTE_U = 10'd4;  // User-accessible
    localparam PTE_G = 10'd5;  // Global
    localparam PTE_A = 10'd6;  // Accessed
    localparam PTE_D = 10'd7;  // Dirty

    //--------------------------------------------------------------------------
    // Virtual Address Breakdown (Sv39)
    // [38:30] - VPN[2] - Level 2 page table index
    // [29:21] - VPN[1] - Level 1 page table index
    // [20:12] - VPN[0] - Level 0 page table index
    // [11:0]  - Page Offset (4KB pages)
    //--------------------------------------------------------------------------

    //--------------------------------------------------------------------------
    // FSM States
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        FETCH_L2       = 3'b001,  // Fetch Level 2 (top-level) PTE
        FETCH_L1       = 3'b010,  // Fetch Level 1 PTE
        FETCH_L0       = 3'b011,  // Fetch Level 0 (leaf) PTE
        DONE           = 3'b100,
        PAGE_FAULT     = 3'b101
    } state_t;

    state_t ps, ns;

    //--------------------------------------------------------------------------
    // Internal Signals
    //--------------------------------------------------------------------------
    logic [VA_WIDTH - 1:0] va_reg;
    logic [PA_WIDTH - 1:0] satp_ppn_reg;
    logic [43:0] current_ppn;      // Current page table PPN
    pte_t current_pte;
    logic [2:0] level;              // Current page table level (2, 1, or 0)

    logic [9:0] vpn [2:0];          // VPN fields extracted from VA
    logic [9:0] pte_index;          // Current PTE index

    //--------------------------------------------------------------------------
    // Extract VPN fields from virtual address
    //--------------------------------------------------------------------------
    assign vpn[2] = va_reg[38:30];  // L2 index
    assign vpn[1] = va_reg[29:21];  // L1 index
    assign vpn[0] = va_reg[20:12];  // L0 index

    //--------------------------------------------------------------------------
    // Select PTE index based on current level
    //--------------------------------------------------------------------------
    always_comb begin
        case (level)
            3'b010: pte_index = vpn[2];  // Level 2
            3'b001: pte_index = vpn[1];  // Level 1
            3'b000: pte_index = vpn[0];  // Level 0
            default: pte_index = '0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Memory read address calculation
    //--------------------------------------------------------------------------
    assign mem_read_addr_o = {{(ADDR_WIDTH - PA_WIDTH){1'b0}}, current_ppn, pte_index[9:0], 3'b000};

    //--------------------------------------------------------------------------
    // Decode PTE from memory
    //--------------------------------------------------------------------------
    assign current_pte = pte_t'(mem_read_data_i);

    //--------------------------------------------------------------------------
    // FSM: Page Table Walk
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            ps <= IDLE;
        end
        else begin
            ps <= ns;
        end
    end

    always_comb begin
        ns = ps;
        mem_read_req_o = 1'b0;
        translation_done_o = 1'b0;
        page_fault_o = 1'b0;

        case (ps)
            IDLE: begin
                if (start_translation_i) begin
                    ns = FETCH_L2;
                end
            end

            FETCH_L2: begin
                mem_read_req_o = 1'b1;
                if (mem_read_done_i) begin
                    if (!current_pte.flags[PTE_V]) begin
                        ns = PAGE_FAULT;  // Invalid PTE
                    end
                    else if (current_pte.flags[PTE_R] || current_pte.flags[PTE_X]) begin
                        // Leaf PTE (megapage) - translation complete
                        ns = DONE;
                    end
                    else begin
                        // Valid pointer to next level
                        ns = FETCH_L1;
                    end
                end
            end

            FETCH_L1: begin
                mem_read_req_o = 1'b1;
                if (mem_read_done_i) begin
                    if (!current_pte.flags[PTE_V]) begin
                        ns = PAGE_FAULT;
                    end
                    else if (current_pte.flags[PTE_R] || current_pte.flags[PTE_X]) begin
                        // Leaf PTE (page) - translation complete
                        ns = DONE;
                    end
                    else begin
                        ns = FETCH_L0;
                    end
                end
            end

            FETCH_L0: begin
                mem_read_req_o = 1'b1;
                if (mem_read_done_i) begin
                    if (!current_pte.flags[PTE_V]) begin
                        ns = PAGE_FAULT;
                    end
                    else if (!current_pte.flags[PTE_R] && !current_pte.flags[PTE_X]) begin
                        // Invalid leaf PTE
                        ns = PAGE_FAULT;
                    end
                    else begin
                        ns = DONE;
                    end
                end
            end

            DONE: begin
                translation_done_o = 1'b1;
                ns = IDLE;
            end

            PAGE_FAULT: begin
                page_fault_o = 1'b1;
                translation_done_o = 1'b1;
                ns = IDLE;
            end

            default: ns = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // Update internal state on memory read completion
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            va_reg <= '0;
            satp_ppn_reg <= '0;
            current_ppn <= '0;
            level <= '0;
        end
        else begin
            if (start_translation_i) begin
                va_reg <= virtual_addr_i;
                satp_ppn_reg <= satp_ppn_i;
                current_ppn <= satp_ppn_i;
                level <= 3'b010;  // Start at level 2
            end
            else if (mem_read_done_i) begin
                case (ps)
                    FETCH_L2: begin
                        current_ppn <= current_pte.ppn;
                        level <= 3'b001;
                    end
                    FETCH_L1: begin
                        current_ppn <= current_pte.ppn;
                        level <= 3'b000;
                    end
                    FETCH_L0: begin
                        current_ppn <= current_pte.ppn;
                        level <= 3'b000;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    //--------------------------------------------------------------------------
    // Output Physical Address
    // Combines final PPN with page offset from original VA
    //--------------------------------------------------------------------------
    assign physical_addr_o = {current_pte.ppn, va_reg[11:0]};

endmodule
