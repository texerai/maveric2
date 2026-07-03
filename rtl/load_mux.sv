/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 20/01/2025
//------------------------------

// -----------------------------------------------------------------------
// This is a module designed to take 64-bit data from memory & adjust it
// based on different LOAD instruction requirements.
// -----------------------------------------------------------------------

`include "maveric_pkg.sv"

module load_mux
// Parameters.
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN
)
(
    // Input interface.
    input  logic [             2:0] func3_i,
    input  logic [DATA_WIDTH - 1:0] data_i,
    input  logic [             2:0] addr_offset_i,

    // Output interface
    output logic [DATA_WIDTH - 1:0] data_o
);

    logic [ 7:0] byte_data;
    logic [15:0] half;
    logic [31:0] word;


    always_comb begin
        case (addr_offset_i[2:0])
            3'b000:  byte_data = data_i[ 7:0 ];
            3'b001:  byte_data = data_i[15:8 ];
            3'b010:  byte_data = data_i[23:16];
            3'b011:  byte_data = data_i[31:24];
            3'b100:  byte_data = data_i[39:32];
            3'b101:  byte_data = data_i[47:40];
            3'b110:  byte_data = data_i[55:48];
            3'b111:  byte_data = data_i[63:56];
            default: byte_data = data_i[ 7:0 ];
        endcase

        case (addr_offset_i[2:1])
            2'b00:   half = data_i[15:0 ];
            2'b01:   half = data_i[31:16];
            2'b10:   half = data_i[47:32];
            2'b11:   half = data_i[63:48];
            default: half = data_i[15:0 ];
        endcase

    end

    assign word = addr_offset_i[2] ? data_i[63:32] : data_i[31:0];

    always_comb begin
        // Default values.
        data_o         = '0;

        case (func3_i)
            3'b000: data_o = {{56{byte_data[7]}}, byte_data}; // LB  Instruction.
            3'b001: data_o = {{48{half[15]}}, half};          // LH  Instruction.
            3'b010: data_o = {{32{word[31]}}, word};          // LW  Instruction.
            3'b011: data_o = data_i;                          // LD  Instruction.
            3'b100: data_o = {{56{1'b0}}, byte_data};         // LBU Instruction.
            3'b101: data_o = {{48{1'b0}}, half};              // LHU Instruction.
            3'b110: data_o = {{32{1'b0}}, word};              // LWU Instruction.
            default: begin
                data_o = '0;
            end
        endcase
    end

endmodule
