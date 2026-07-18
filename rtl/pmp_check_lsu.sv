/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 17/07/2026
// Last Revision: 17/07/2026
//------------------------------

// ----------------------------------------------------------------------
// This module is PMP check module for MEMORY module.
// ----------------------------------------------------------------------

`include "maveric_pkg.sv"

module pmp_check_lsu
// Parameters.
#(
    parameter PA_W       = maveric_pkg::PA_W,
    parameter PMP_N      = maveric_pkg::PMP_N,
    parameter XLEN       = maveric_pkg::XLEN
)
(
    // Input interface.
    /* verilator lint_off UNUSED */
    input  logic [XLEN                 - 1:0] addr_i,
    input  csr_pkg::pmp_t                     pmp_data_i,
     /* verilator lint_on UNUSED */
    input  logic [                       1:0] priv_mode_i,
    input  logic                              mem_access_i,
    input  logic                              mem_store_i,
    input  logic [                       1:0] ls_type,

    // Output interface.
    output logic                              trap_o
);
    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic [PA_W - 1:0] pmpaddr_lo [PMP_N - 1:0];
    logic [PA_W - 1:0] pmpaddr_hi [PMP_N - 1:0];

    logic [PA_W - 1:0] access_lo;
    logic [PA_W - 1:0] access_hi;

    logic [PMP_N - 1:0] overlap;
    logic [PMP_N - 1:0] contains;



    //---------------------------------------------
    // Continious assignments.
    //---------------------------------------------
    assign pmpaddr_lo[0]  = pmp_data_i.pmpaddr0_lo;
    assign pmpaddr_hi[0]  = pmp_data_i.pmpaddr0_hi;
    assign pmpaddr_lo[1]  = pmp_data_i.pmpaddr1_lo;
    assign pmpaddr_hi[1]  = pmp_data_i.pmpaddr1_hi;
    assign pmpaddr_lo[2]  = pmp_data_i.pmpaddr2_lo;
    assign pmpaddr_hi[2]  = pmp_data_i.pmpaddr2_hi;
    assign pmpaddr_lo[3]  = pmp_data_i.pmpaddr3_lo;
    assign pmpaddr_hi[3]  = pmp_data_i.pmpaddr3_hi;
    assign pmpaddr_lo[4]  = pmp_data_i.pmpaddr4_lo;
    assign pmpaddr_hi[4]  = pmp_data_i.pmpaddr4_hi;
    assign pmpaddr_lo[5]  = pmp_data_i.pmpaddr5_lo;
    assign pmpaddr_hi[5]  = pmp_data_i.pmpaddr5_hi;
    assign pmpaddr_lo[6]  = pmp_data_i.pmpaddr6_lo;
    assign pmpaddr_hi[6]  = pmp_data_i.pmpaddr6_hi;
    assign pmpaddr_lo[7]  = pmp_data_i.pmpaddr7_lo;
    assign pmpaddr_hi[7]  = pmp_data_i.pmpaddr7_hi;
    assign pmpaddr_lo[8]  = pmp_data_i.pmpaddr8_lo;
    assign pmpaddr_hi[8]  = pmp_data_i.pmpaddr8_hi;
    assign pmpaddr_lo[9]  = pmp_data_i.pmpaddr9_lo;
    assign pmpaddr_hi[9]  = pmp_data_i.pmpaddr9_hi;
    assign pmpaddr_lo[10] = pmp_data_i.pmpaddr10_lo;
    assign pmpaddr_hi[10] = pmp_data_i.pmpaddr10_hi;
    assign pmpaddr_lo[11] = pmp_data_i.pmpaddr11_lo;
    assign pmpaddr_hi[11] = pmp_data_i.pmpaddr11_hi;
    assign pmpaddr_lo[12] = pmp_data_i.pmpaddr12_lo;
    assign pmpaddr_hi[12] = pmp_data_i.pmpaddr12_hi;
    assign pmpaddr_lo[13] = pmp_data_i.pmpaddr13_lo;
    assign pmpaddr_hi[13] = pmp_data_i.pmpaddr13_hi;
    assign pmpaddr_lo[14] = pmp_data_i.pmpaddr14_lo;
    assign pmpaddr_hi[14] = pmp_data_i.pmpaddr14_hi;
    assign pmpaddr_lo[15] = pmp_data_i.pmpaddr15_lo;
    assign pmpaddr_hi[15] = pmp_data_i.pmpaddr15_hi;

    always_comb begin
        access_lo = addr_i[PA_W - 1:0];
        access_hi = addr_i[PA_W - 1:0];

        case (ls_type)
            2'b00: access_hi = addr_i[PA_W - 1:0] + {{(PA_W - 3){1'b0}}, 3'd0};
            2'b01: access_hi = addr_i[PA_W - 1:0] + {{(PA_W - 3){1'b0}}, 3'd1};
            2'b10: access_hi = addr_i[PA_W - 1:0] + {{(PA_W - 3){1'b0}}, 3'd3};
            2'b11: access_hi = addr_i[PA_W - 1:0] + {{(PA_W - 3){1'b0}}, 3'd7};
            default: access_hi = addr_i[PA_W - 1:0] + {{(PA_W - 3){1'b0}}, 3'd3};
        endcase
    end

    always_comb begin
        for (int i = 0; i < PMP_N; i++) begin
            overlap[i] = pmp_data_i.active[i] && (access_lo < pmpaddr_hi[i]) && (access_hi > pmpaddr_lo[i]);
            contains[i] = (access_lo >= pmpaddr_lo[i]) && (access_hi < pmpaddr_hi[i]);
        end
    end

    //---------------------------------------------------
    // Check.
    //---------------------------------------------------
    logic permitted;

    always_comb begin
        if ((((priv_mode_i == csr_pkg::PRIV_M) && pmp_data_i.L[0]) || (priv_mode_i < csr_pkg::PRIV_M)) && mem_access_i) begin
            if (mem_store_i) begin
                casez (overlap)
                    16'bzzzzzzzzzzzzzzz1: permitted = contains[0 ] && pmp_data_i.W[0];
                    16'bzzzzzzzzzzzzzz10: permitted = contains[1 ] && pmp_data_i.W[1];
                    16'bzzzzzzzzzzzzz100: permitted = contains[2 ] && pmp_data_i.W[2];
                    16'bzzzzzzzzzzzz1000: permitted = contains[3 ] && pmp_data_i.W[3];
                    16'bzzzzzzzzzzz10000: permitted = contains[4 ] && pmp_data_i.W[4];
                    16'bzzzzzzzzzz100000: permitted = contains[5 ] && pmp_data_i.W[5];
                    16'bzzzzzzzzz1000000: permitted = contains[6 ] && pmp_data_i.W[6];
                    16'bzzzzzzzz10000000: permitted = contains[7 ] && pmp_data_i.W[7];
                    16'bzzzzzzz100000000: permitted = contains[8 ] && pmp_data_i.W[8];
                    16'bzzzzzz1000000000: permitted = contains[9 ] && pmp_data_i.W[9];
                    16'bzzzzz10000000000: permitted = contains[10] && pmp_data_i.W[10];
                    16'bzzzz100000000000: permitted = contains[11] && pmp_data_i.W[11];
                    16'bzzz1000000000000: permitted = contains[12] && pmp_data_i.W[12];
                    16'bzz10000000000000: permitted = contains[13] && pmp_data_i.W[13];
                    16'bz100000000000000: permitted = contains[14] && pmp_data_i.W[14];
                    16'b1000000000000000: permitted = contains[15] && pmp_data_i.W[15];
                    default: permitted = 1'b1;
                endcase
            end else begin
                casez (overlap)
                    16'bzzzzzzzzzzzzzzz1: permitted = contains[0 ] && pmp_data_i.R[0];
                    16'bzzzzzzzzzzzzzz10: permitted = contains[1 ] && pmp_data_i.R[1];
                    16'bzzzzzzzzzzzzz100: permitted = contains[2 ] && pmp_data_i.R[2];
                    16'bzzzzzzzzzzzz1000: permitted = contains[3 ] && pmp_data_i.R[3];
                    16'bzzzzzzzzzzz10000: permitted = contains[4 ] && pmp_data_i.R[4];
                    16'bzzzzzzzzzz100000: permitted = contains[5 ] && pmp_data_i.R[5];
                    16'bzzzzzzzzz1000000: permitted = contains[6 ] && pmp_data_i.R[6];
                    16'bzzzzzzzz10000000: permitted = contains[7 ] && pmp_data_i.R[7];
                    16'bzzzzzzz100000000: permitted = contains[8 ] && pmp_data_i.R[8];
                    16'bzzzzzz1000000000: permitted = contains[9 ] && pmp_data_i.R[9];
                    16'bzzzzz10000000000: permitted = contains[10] && pmp_data_i.R[10];
                    16'bzzzz100000000000: permitted = contains[11] && pmp_data_i.R[11];
                    16'bzzz1000000000000: permitted = contains[12] && pmp_data_i.R[12];
                    16'bzz10000000000000: permitted = contains[13] && pmp_data_i.R[13];
                    16'bz100000000000000: permitted = contains[14] && pmp_data_i.R[14];
                    16'b1000000000000000: permitted = contains[15] && pmp_data_i.R[15];
                    default: permitted = 1'b1;
                endcase
            end
        end
        else permitted = 1'b1;
    end

    assign trap_o = !permitted;

endmodule
