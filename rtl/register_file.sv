/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 15/03/2025
//------------------------------

// ----------------------------------------------------------------------------
// This is a register file component of processor based on RISC-V architecture.
// ----------------------------------------------------------------------------

`include "maveric_pkg.sv"

module register_file
// Parameters.
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN,
              ADDR_WIDTH = maveric_pkg::REG_ADDR_W,
              REG_DEPTH  = 32
)
// Port decleration.
(
    // Common clock, enable & reset signal.
    input  logic                    clk_i,
    input  logic                    we_3_i,
    input  logic                    arst_i,

    // Input interface.
    input  logic [ADDR_WIDTH - 1:0] addr_1_i,
    input  logic [ADDR_WIDTH - 1:0] addr_2_i,
    input  logic [ADDR_WIDTH - 1:0] addr_3_i,
    input  logic [DATA_WIDTH - 1:0] wdata_3_i,

    // Output interface.
    output logic                    a0_reg_lsb_o,
    output logic [DATA_WIDTH - 1:0] rdata_1_o,
    output logic [DATA_WIDTH - 1:0] rdata_2_o
);

    // Register block.
    logic [DATA_WIDTH - 1:0] mem_block [REG_DEPTH - 1:0];


    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < REG_DEPTH; i++) begin
                mem_block [i] <= '0;
            end
        end else if (we_3_i) begin
            mem_block [addr_3_i] <= wdata_3_i;
        end
    end

    // Read logic.
    assign rdata_1_o = ((addr_1_i == addr_3_i) & we_3_i) ? wdata_3_i : mem_block[addr_1_i];
    assign rdata_2_o = ((addr_2_i == addr_3_i) & we_3_i) ? wdata_3_i : mem_block[addr_2_i];

    assign a0_reg_lsb_o = mem_block[10][0];


endmodule
