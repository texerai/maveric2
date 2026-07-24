/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 10/07/2026
// Last Revision: 13/07/2026
//------------------------------

// ----------------------------------------------------------------------
// This module is a fully associative 4 entry ITLB.
// ----------------------------------------------------------------------

`include "maveric_pkg.sv"

module dtlb // Future: Still no access check, and permission check.
// Parameters.
#(
    parameter TAG_WIDTH  = 46,
    parameter DATA_WIDTH = 50,
    parameter N          = 4,
    parameter OFFSET     = 12,
    parameter VPN_LEN    = 27,
    parameter PPN_LEN    = 44,
    parameter ASID_LEN   = 16,
    parameter ADDR_WIDTH = maveric_pkg::XLEN
)
(
    // Input interface.
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic [             1:0] priv_mode_i,
    input  logic                    invalidate_i,
    input  logic                    access_i,
    input  logic                    mem_store_i,
    input  logic                    tlb_we_i,
    input  logic [ASID_LEN   - 1:0] satp_asid_i,
    /* verilator lint_off UNUSED */
    input  logic [ADDR_WIDTH - 1:0] va_i,
    /* verilator lint_on UNUSED */
    input  logic [TAG_WIDTH  - 1:0] tlb_wtag_i,
    input  logic [DATA_WIDTH - 1:0] tlb_wdata_i,
    input  logic                    mstatus_mxr_i,
    input  logic                    mstatus_sum_i,

    // Output interface.
    output logic                    trap_o,
    output logic [ADDR_WIDTH - 1:0] pa_o,
    output logic                    hit_o
);
    //----------------------------------------------------
    // Local param for cache size reconfigurability.
    //----------------------------------------------------
    localparam VPN_MSB  = TAG_WIDTH - 1;
    localparam VPN_LSB  = VPN_MSB - VPN_LEN + 1;
    localparam ASID_MSB = VPN_LSB - 1;
    localparam ASID_LSB = ASID_MSB -ASID_LEN + 1;

    localparam PPN_MSB = DATA_WIDTH - 1;
    localparam PPN_LSB = PPN_MSB - PPN_LEN + 1;

    localparam R_BIT = 0;
    localparam W_BIT = 1;
    localparam X_BIT = 2;
    localparam U_BIT = 3;
    localparam D_BIT = 5;



    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic [N          - 1:0] hit_find;
    logic [N          - 1:0] vpn_match;
    logic [N          - 1:0] asid_match;
    logic                    hit;
    logic [$clog2 (N) - 1:0] way;
    logic [$clog2 (N) - 1:0] plru;

    //---------------------------------------------------------
    // Memory blocks.
    //---------------------------------------------------------
    logic [TAG_WIDTH  - 1:0] tag_mem[N - 1:0]; // Tag memory.
    logic [N          - 1:0] valid_mem;        // Valid memory.
    logic [N          - 2:0] plru_mem;         // Tree Pseudo-LRU memory.
    logic [DATA_WIDTH - 1:0] tlb_mem[N - 1:0]; // TLB memory.




    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------

    //---------------------------------------------------
    // Check.
    //---------------------------------------------------

    // Check for hit and find the way/line that matches.
    always_comb begin
        for (int i = 0; i < N; i++) begin
            case (tag_mem[i][1:0]) // Level.
                2'd0: vpn_match[i] = (tag_mem[i][VPN_MSB:VPN_LSB     ] == va_i[VPN_LEN + OFFSET - 1:OFFSET     ]);
                2'd1: vpn_match[i] = (tag_mem[i][VPN_MSB:VPN_LSB +  9] == va_i[VPN_LEN + OFFSET - 1:OFFSET +  9]);
                2'd2: vpn_match[i] = (tag_mem[i][VPN_MSB:VPN_LSB + 18] == va_i[VPN_LEN + OFFSET - 1:OFFSET + 18]);
                default: vpn_match[i] = 1'b0;
            endcase

            if (tag_mem[i][2]) begin
                asid_match[i] = 1'b1;
            end else begin
                asid_match[i] = tag_mem[i][ASID_MSB:ASID_LSB] == satp_asid_i;
            end

            hit_find[i] = valid_mem[i] && vpn_match[i] && asid_match[i];
        end

        casez (hit_find)
            4'bzzz1: way = 2'b00;
            4'bzz10: way = 2'b01;
            4'bz100: way = 2'b10;
            4'b1000: way = 2'b11;
            default: way = plru;
        endcase
    end

    assign hit = | hit_find;

    // Logic for finding the PLRU.
    assign plru = {plru_mem[0], (plru_mem[0] ? plru_mem[2] : plru_mem[1])};



    //--------------------------------------------------
    // Memory write logic.
    //--------------------------------------------------

    // Valid memory.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i      ) valid_mem      <= '0;
        else if (invalidate_i) valid_mem      <= '0;
        else if (tlb_we_i    ) valid_mem[way] <= 1'b1;
    end


    // PLRU memory.
    //-----------------------------------------------------------------------
    // PLRU organization:
    // 0 - left, 1 - right leaf.
    // plru [0] - parent, plru [1] = left leaf, plru [2] - right leaf.
    //-----------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < N; i++) begin
                plru_mem [i] <= '0;
            end
        end else if (hit & access_i) begin
            plru_mem[0          ] <= ~ way [1];
            plru_mem[1 + way [1]] <= ~ way [0];
        end
    end


    // Data memory.
    always_ff @(posedge clk_i) begin
        if (tlb_we_i) begin
            tlb_mem [way] <= tlb_wdata_i;
            tag_mem [way] <= tlb_wtag_i;
        end
    end




    //--------------------------------------
    // Output continious assignments.
    //--------------------------------------
    assign hit_o = mem_store_i ? (hit && (tlb_mem[way][D_BIT] == 1'b1)) : hit;

    assign trap_o = !(((!mem_store_i && (tlb_mem[way][R_BIT] || (mstatus_mxr_i && tlb_mem[way][X_BIT]))) || (mem_store_i && tlb_mem[way][W_BIT]))
                    && (((priv_mode_i == csr_pkg::PRIV_U) && tlb_mem[way][U_BIT]) || ((priv_mode_i == csr_pkg::PRIV_S) && ((!tlb_mem[way][U_BIT]) || (tlb_mem[way][U_BIT] && mstatus_sum_i)))));

    always_comb begin
        pa_o = '0;

        case (tag_mem[way][1:0]) // level
            2'd0: pa_o = {8'b0, tlb_mem[way][PPN_MSB:PPN_LSB     ], va_i[OFFSET - 1     :0]};
            2'd1: pa_o = {8'b0, tlb_mem[way][PPN_MSB:PPN_LSB +  9], va_i[OFFSET - 1 +  9:0]};
            2'd2: pa_o = {8'b0, tlb_mem[way][PPN_MSB:PPN_LSB + 18], va_i[OFFSET - 1 + 18:0]};
            default: pa_o = '0;
        endcase
    end
endmodule
