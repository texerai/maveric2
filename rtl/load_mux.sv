/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// This is a module designed to take 64-bit data from memory & adjust it
// based on different LOAD instruction requirements.
// -----------------------------------------------------------------------

module load_mux
// Parameters.
#(
    parameter DATA_WIDTH = 64
)
(
    // Input interface.
    input  logic [             2:0] func3_i,
    input  logic [DATA_WIDTH - 1:0] data_i,
    input  logic [             2:0] addr_offset_i,

    // Output interface
    output logic                    load_addr_ma_o,
    output logic [DATA_WIDTH - 1:0] data_o
);

    logic [ 7:0] byte_s;
    logic [15:0] half_s;
    logic [31:0] word_s;

    logic load_addr_ma_lh_s;
    logic load_addr_ma_lw_s;
    logic load_addr_ma_ld_s;

    assign load_addr_ma_lh_s = addr_offset_i[0];
    assign load_addr_ma_lw_s = | addr_offset_i[1:0];
    assign load_addr_ma_ld_s = | addr_offset_i;

    always_comb begin
        case (addr_offset_i[2:0])
            3'b000:  byte_s = data_i[ 7:0 ];
            3'b001:  byte_s = data_i[15:8 ];
            3'b010:  byte_s = data_i[23:16];
            3'b011:  byte_s = data_i[31:24];
            3'b100:  byte_s = data_i[39:32];
            3'b101:  byte_s = data_i[47:40];
            3'b110:  byte_s = data_i[55:48];
            3'b111:  byte_s = data_i[63:56];
            default: byte_s = data_i[ 7:0 ];
        endcase

        case (addr_offset_i[2:1])
            2'b00:   half_s = data_i[15:0 ];
            2'b01:   half_s = data_i[31:16];
            2'b10:   half_s = data_i[47:32];
            2'b11:   half_s = data_i[63:48];
            default: half_s = data_i[15:0 ];
        endcase

    end

    assign word_s = addr_offset_i[2] ? data_i[63:32] : data_i[31:0];

    always_comb begin
        // Default values.
        data_o         = '0;
        load_addr_ma_o = '0;

        case (func3_i)
            3'b000:  begin
                data_o         = {{56{byte_s[7]}}, byte_s}; // LB  Instruction.
                load_addr_ma_o = 1'b0;
            end
            3'b001:  begin
                data_o         = {{48{half_s[15]}}, half_s}; // LH  Instruction.
                load_addr_ma_o = load_addr_ma_lh_s;
            end
            3'b010:  begin
                data_o         = {{32{word_s[31]}}, word_s}; // LW  Instruction.
                load_addr_ma_o = load_addr_ma_lw_s;
            end
            3'b011:  begin
                data_o         = data_i;                     // LD  Instruction.
                load_addr_ma_o = load_addr_ma_ld_s;
            end
            3'b100:  begin
                data_o         = {{56{1'b0}}, byte_s};      // LBU Instruction.
                load_addr_ma_o = 1'b0;
            end
            3'b101:  begin
                data_o         = {{48{1'b0}}, half_s};      // LHU Instruction.
                load_addr_ma_o = load_addr_ma_lh_s;
            end
            3'b110:  begin
                data_o         = {{32{1'b0}}, word_s};      // LWU Instruction.
                load_addr_ma_o = load_addr_ma_lw_s;
            end
            default: begin
                data_o = '0;
            end
        endcase
    end

endmodule
