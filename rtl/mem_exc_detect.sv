/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 11/06/2026
// Last Revision: 18/06/2026
//------------------------------

// -----------------------------------------------------------------------
// This is a module designed to detect memory access address misaligned
// exception detection. This includes load and store address misaligned
// exctoptions.
// -----------------------------------------------------------------------

`include "maveric_pkg.sv"

module mem_exc_detect
(
    // Input interface.
    input  logic       mem_access_i,
    input  logic       store_instr_i,
    input  logic [1:0] access_type_i,
    input  logic [2:0] addr_offset_i,

    // Output interface
    output logic       exc_addr_ma_o,
    output logic [5:0] trap_cause_o
);
    //---------------------------------------------------------
    // Internal nets.
    //---------------------------------------------------------
    logic addr_ma_hw;
    logic addr_ma_w;
    logic addr_ma_dw;

    assign addr_ma_hw = addr_offset_i[0];
    assign addr_ma_w  = | addr_offset_i[1:0];
    assign addr_ma_dw = | addr_offset_i;

    // Store address misalignment detection.
    always_comb begin
        // Default value.
        exc_addr_ma_o = 1'b0;
        trap_cause_o  = '0;

        if (mem_access_i) begin
            case (access_type_i)
                2'b11: exc_addr_ma_o = addr_ma_dw;
                2'b10: exc_addr_ma_o = addr_ma_w;
                2'b01: exc_addr_ma_o = addr_ma_hw;
                default: exc_addr_ma_o = 1'b0;
            endcase
            if (store_instr_i) trap_cause_o = csr_pkg::EXC_STORE_ADDR_MA;
            else               trap_cause_o = csr_pkg::EXC_LOAD_ADDR_MA;
        end
    end

endmodule
