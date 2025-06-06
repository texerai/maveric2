/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// This is a module designed to assign ImmSrc based on instruction opcode.
// ImmSrc is a signal designed to control immediate extension logic.
// -----------------------------------------------------------------------

module instr_decoder
// Parameters.
#(
    parameter WIDTH     = 4,
    parameter OUT_WIDTH = 3
)
// Ports.
(
    input  logic [WIDTH     - 1:0] instr_i,
    output logic [OUT_WIDTH - 1:0] imm_src_o
);

    //Decoder logic.
    /*
    ____________________________________
    | control signal | instuction type |
    |________________|_________________|
    | 000            | I type          |
    | 001            | S type          |
    | 010            | B type          |
    | 011            | J type          |
    | 100            | U type          |
    | 101            | R type          |
    |__________________________________|
    */

    always_comb begin
        case (instr_i)
            4'b0000,                      // I type. ex: LB.
            4'b0001,                      // I type. ex: ADDI.
            4'b0010,                      // I type. ex: JALR.
            4'b0011: imm_src_o = 3'b000;  // I type. ex: ADDIW.
            4'b0100: imm_src_o = 3'b001;  // S type. ex: SB.
            4'b0111: imm_src_o = 3'b010;  // B type. ex: BEQ.
            4'b1000: imm_src_o = 3'b011;  // J type. ex: JAL.
            4'b1001,                      // U type. ex: AUIPC.
            4'b1010: imm_src_o = 3'b100;  // U type. ex: LUI.
            default: imm_src_o = 3'b101;  // Default to R type.
        endcase
    end

endmodule
