/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 09/07/2026
// Last Revision: 15/07/2026
//------------------------------

// --------------------------------------------------------------
// This is a MMU PTW module for ITLB and DTLB misses and writes.
// It implements only Sv39.
// --------------------------------------------------------------

`include "maveric_pkg.sv"

module mmu_ptw #(
    parameter XLEN = maveric_pkg::XLEN
)
(
    // Input interface.
    input  logic                              clk_i,
    input  logic                              arst_i,
    input  logic [                       1:0] priv_mode_eff_i,
    input  logic                              mstatus_mxr_i,
    input  logic                              mstatus_sum_i,
    input  logic                              mem_store_i, // 1'b0 - Load, 1'b1 - Store.
    input  logic                              va_enabled_if_i,
    input  logic                              va_enabled_lsu_i,
    input  logic                              itlb_hit_i,
    input  logic                              dtlb_hit_i,
    input  logic                              lsu_access_i,
    input  logic                              dcache_hit_i,
    /* verilator lint_off UNUSED */
    input  logic [XLEN                 - 1:0] va_fetch_i,
    input  logic [XLEN                 - 1:0] va_lsu_i,
    /* verilator lint_off UNUSED */
    input  logic [XLEN                 - 1:0] dcache_rdata_i,
    input  logic [XLEN                 - 1:0] satp_i,
    input  logic                              trap_id_i,
    input  logic                              trap_commit_i,
    input  logic                              trap_pmp_i,

    // Output interface.
    output logic [XLEN                 - 1:0] dcache_addr_o,
    output logic [XLEN                 - 1:0] dcache_wdata_o,
    output logic                              dcache_we_o,
    output logic                              dcache_access_o,
    output logic [                      49:0] tlb_wdata_o,
    output logic [                      45:0] tlb_wtag_o,
    output logic                              itlb_we_o,
    output logic                              dtlb_we_o,
    output logic                              trap_dtlb_detected_o,
    output logic                              trap_itlb_detected_o,
    output logic [maveric_pkg::CAUSE_W - 1:0] trap_cause_o,
    output logic                              mmu_stall_icache_o,
    output logic                              mmu_stall_o
);

    //------------------------------------
    // Internal nets.
    //------------------------------------
    typedef struct packed {
        logic        N;
        logic [ 1:0] PBMT;
        logic [ 6:0] Reserved;
        logic [25:0] PPN_2;
        logic [ 8:0] PPN_1;
        logic [ 8:0] PPN_0;
        logic [ 1:0] RSW;
        logic        D, A, G, U, X, W, R, V;
    } pte_t;

    typedef struct packed {
        logic [8:0] VPN_2;
        logic [8:0] VPN_1;
        logic [8:0] VPN_0;
    } vpn_t;

    /* verilator lint_off UNUSED */
    pte_t pte;
    /* verilator lint_on UNUSED */
    vpn_t vpn;

    logic pte_update;
    logic dtlb_miss;
    logic itlb_miss;
    logic dcache_addr_update;
    logic [XLEN - 1:0] dcache_addr;

    logic [1:0] level_q;
    logic [1:0] level_d;
    logic       level_update;


    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) pte <= '0;
        else if (pte_update) pte <= dcache_rdata_i;
    end

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i             ) dcache_addr_o <= '0;
        else if (dcache_addr_update ) dcache_addr_o <= dcache_addr;
    end

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i      ) level_q <= '0;
        else if (level_update) level_q <= level_d;
    end

    assign dtlb_miss = !dtlb_hit_i && lsu_access_i & va_enabled_lsu_i;
    assign itlb_miss = !itlb_hit_i && va_enabled_if_i;

    assign vpn = dtlb_miss ? va_lsu_i[38:12] : va_fetch_i[38:12];


    //------------------------------------
    // FSM.
    //------------------------------------

    // FSM states.
    typedef enum logic [3:0]
    {
        IDLE               = 4'd0,
        READ_L2            = 4'd1,
        CHECK_L2           = 4'd2,
        ALIGNMENT_CHECK_L2 = 4'd3,
        READ_L1            = 4'd4,
        CHECK_L1           = 4'd5,
        ALIGNMENT_CHECK_L1 = 4'd6,
        READ_L0            = 4'd7,
        CHECK_L0           = 4'd8,
        PERMISSION_CHECK   = 4'd9,
        AD_UPDATE          = 4'd10,
        REFILL_TLB         = 4'd11,
        TRAP_PAGE_FAULT    = 4'd12,
        TRAP_ACCESS_FAULT  = 4'd13,
        TRAP_WAIT          = 4'd14
    } t_state;

    t_state PS;
    t_state NS;


    // FSM: PS syncronization.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) PS <= IDLE;
        else        PS <= NS;
    end


    // FSM: NS logic.
    always_comb begin
        // Default value.
        NS = PS;

        case (PS)
            IDLE: begin
                if (dtlb_miss || itlb_miss) NS = READ_L2;
            end
            READ_L2: begin
                if      (trap_pmp_i  ) NS = TRAP_ACCESS_FAULT;
                else if (dcache_hit_i) NS = CHECK_L2;
            end
            CHECK_L2: begin // Future: Also need to add check for pmpaddr and pmpcfg CSRs.
                if      ((!pte.V) || ((!pte.R) && (pte.W))) NS = TRAP_PAGE_FAULT;
                else if (pte.V && (pte.R || pte.X)        ) NS = ALIGNMENT_CHECK_L2;
                else                                        NS = READ_L1;
            end
            ALIGNMENT_CHECK_L2: begin
                if ((|pte.PPN_1) || (|pte.PPN_0)) NS = TRAP_PAGE_FAULT;
                else                              NS = PERMISSION_CHECK;
            end
            READ_L1: begin
                if      (trap_pmp_i  ) NS = TRAP_ACCESS_FAULT;
                else if (dcache_hit_i) NS = CHECK_L1;
            end
            CHECK_L1: begin
                if      ((!pte.V) || ((!pte.R) && (pte.W))) NS = TRAP_PAGE_FAULT;
                else if (pte.V && (pte.R || pte.X)        ) NS = ALIGNMENT_CHECK_L1;
                else                                        NS = READ_L0;
            end
            ALIGNMENT_CHECK_L1: begin
                if (|pte.PPN_0) NS = TRAP_PAGE_FAULT;
                else            NS = PERMISSION_CHECK;
            end
            READ_L0: begin
                if      (trap_pmp_i  ) NS = TRAP_ACCESS_FAULT;
                else if (dcache_hit_i) NS = CHECK_L0;
            end
            CHECK_L0: begin
                if      ((!pte.V) || ((!pte.R) && (pte.W))) NS = TRAP_PAGE_FAULT;
                else if (pte.V && (pte.R || pte.X)        ) NS = PERMISSION_CHECK;
                else                                        NS = TRAP_PAGE_FAULT;
            end
            PERMISSION_CHECK: begin
                if (dtlb_miss) begin // Load-store.
                    if (!pte.A || (mem_store_i && (!pte.D))) NS = TRAP_PAGE_FAULT;
                    else if (((!mem_store_i && (pte.R || (mstatus_mxr_i && pte.X))) || (mem_store_i && pte.W))) begin
                        if ((priv_mode_eff_i == csr_pkg::PRIV_U) && pte.U)
                            NS = AD_UPDATE;
                        else if ((priv_mode_eff_i == csr_pkg::PRIV_S) && ((!pte.U) || (pte.U && mstatus_sum_i)))
                            NS = AD_UPDATE;
                        else
                            NS = TRAP_PAGE_FAULT;
                    end else begin
                        NS = TRAP_PAGE_FAULT;
                    end
                end else begin // Instruction fetch.
                    if (!pte.A) NS = TRAP_PAGE_FAULT;
                    else if (pte.X) begin
                        if ((priv_mode_eff_i == csr_pkg::PRIV_U) && pte.U)
                            NS = AD_UPDATE;
                        else if ((priv_mode_eff_i == csr_pkg::PRIV_S) && (!pte.U))
                            NS = AD_UPDATE;
                        else
                            NS = TRAP_PAGE_FAULT;
                    end else NS = TRAP_PAGE_FAULT;
                end
            end
            AD_UPDATE: begin
                NS = REFILL_TLB;
            end
            REFILL_TLB: begin
                NS = IDLE;
            end
            TRAP_PAGE_FAULT: begin
                if (dtlb_miss | trap_id_i) NS = TRAP_WAIT;
            end
            TRAP_ACCESS_FAULT: begin
                if (dtlb_miss | trap_id_i) NS = TRAP_WAIT;
            end
            TRAP_WAIT: begin
                if (trap_commit_i) NS = IDLE;
            end
            default: NS = PS;
        endcase
    end


    // FSM: Output logic.
    always_comb begin
        // Default values.
        pte_update         = 1'b0;
        dcache_addr_update = 1'b0;
        dcache_access_o    = 1'b0;
        itlb_we_o          = 1'b0;
        dtlb_we_o          = 1'b0;
        dcache_we_o        = 1'b0;
        level_update       = 1'b0;

        dcache_addr    = '0;
        dcache_wdata_o = '0;
        tlb_wdata_o    = '0;
        tlb_wtag_o     = '0;
        level_d        = '0;

        trap_dtlb_detected_o = 1'b0;
        trap_itlb_detected_o = 1'b0;
        trap_cause_o         = '0;
        mmu_stall_icache_o   = 1'b0;
        mmu_stall_o          = 1'b1;

        case(PS)
            IDLE: begin
                dcache_addr_update = dtlb_miss || itlb_miss;
                dcache_addr        = {8'b0, satp_i[43:0], 12'b0} + {52'b0, vpn.VPN_2, 3'b0};
                mmu_stall_o        = dcache_addr_update;
            end
            READ_L2: begin
                dcache_access_o = 1'b1;
                pte_update      = dcache_hit_i;
            end
            CHECK_L2: begin
                dcache_access_o    = 1'b1;
                dcache_addr_update = !(pte.X || pte.W || pte.R); // Page walk continutes.
                dcache_addr        = {8'b0, pte.PPN_2, pte.PPN_1, pte.PPN_0, 12'b0} + {52'b0, vpn.VPN_1, 3'b0};
                level_d            = 2'd2;
                level_update       = 1'b1;
            end
            READ_L1: begin
                dcache_access_o = 1'b1;
                pte_update      = dcache_hit_i;
            end
            CHECK_L1: begin
                dcache_access_o    = 1'b1;
                dcache_addr_update = !(pte.X || pte.W || pte.R); // Page walk continutes.
                dcache_addr        = {8'b0, pte.PPN_2, pte.PPN_1, pte.PPN_0, 12'b0} + {52'b0, vpn.VPN_0, 3'b0};
                level_d            = 2'd1;
                level_update       = 1'b1;
            end
            READ_L0: begin
                dcache_access_o = 1'b1;
                pte_update      = dcache_hit_i;
            end
            CHECK_L0: begin
                dcache_access_o = 1'b1;
                level_d         = 2'd0;
                level_update    = 1'b1;
            end
            AD_UPDATE: begin
                dcache_access_o = 1'b0;
                dcache_we_o     = 1'b0;
                dcache_wdata_o  = pte; // | {56'b0, (dtlb_miss && mem_store_i), 1'b1, 6'b0};
            end
            REFILL_TLB: begin
                itlb_we_o = !dtlb_miss;
                dtlb_we_o = dtlb_miss;
                tlb_wdata_o = {pte.PPN_2, pte.PPN_1, pte.PPN_0, pte.D, pte.A, pte.U, pte.X, pte.W, pte.R} | {44'b0, (dtlb_miss && mem_store_i), 1'b1, 4'b0};
                tlb_wtag_o  = {vpn, satp_i[59:44], pte.G, level_q};
            end
            TRAP_PAGE_FAULT: begin
                if (dtlb_miss) begin
                    trap_dtlb_detected_o = 1'b1;
                    if (mem_store_i) trap_cause_o = csr_pkg::EXC_STORE_PAGE_FAULT;
                    else             trap_cause_o = csr_pkg::EXC_LOAD_PAGE_FAULT;
                end else begin
                    trap_itlb_detected_o = 1'b1;
                    trap_cause_o         = csr_pkg::EXC_INSTR_PAGE_FAULT;
                end
                mmu_stall_o        = 1'b0;
                mmu_stall_icache_o = 1'b1;
            end
            TRAP_ACCESS_FAULT: begin
                if (dtlb_miss) begin
                    trap_dtlb_detected_o = 1'b1;
                    if (mem_store_i) trap_cause_o = csr_pkg::EXC_STORE_ACCESS_FAULT;
                    else             trap_cause_o = csr_pkg::EXC_LOAD_ACCESS_FAULT;
                end else begin
                    trap_itlb_detected_o = 1'b1;
                    trap_cause_o         = csr_pkg::EXC_INSTR_ACCESS_FAULT;
                end
                mmu_stall_o        = 1'b0;
                mmu_stall_icache_o = 1'b1;
            end
            TRAP_WAIT: begin
                mmu_stall_icache_o = 1'b1;
                mmu_stall_o        = 1'b0;
            end
            default: begin
                pte_update         = 1'b0;
                dcache_addr_update = 1'b0;
                dcache_access_o    = 1'b0;
                itlb_we_o          = 1'b0;
                dtlb_we_o          = 1'b0;
                dcache_we_o        = 1'b0;

                dcache_addr    = '0;
                dcache_wdata_o = '0;
                tlb_wdata_o    = '0;
                tlb_wtag_o     = '0;

                trap_dtlb_detected_o = 1'b0;
                trap_itlb_detected_o = 1'b0;
                trap_cause_o         = '0;
                mmu_stall_icache_o   = 1'b0;
                mmu_stall_o          = 1'b1;
            end
        endcase
    end


endmodule
