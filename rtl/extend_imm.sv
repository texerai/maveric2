/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------
// This is a module to extend immediate input depending on type of instruction.
// ----------------------------------------------------------------------------

/*NOTE: Might optimize the mux width since upper 32 bits are always i_imm[24]*/

module extend_imm
// Parameters.
#(
    parameter IMM_WIDTH = 25,
    parameter OUT_WIDTH = 64
)
// Port decleration.
(
    // Control signal.
    input  logic [            2:0] control_signal_i,

    // Input interface.
    input  logic [IMM_WIDTH - 1:0] imm_i,

    // Output interface.
    output logic [OUT_WIDTH - 1:0] imm_ext_o
);

    logic [OUT_WIDTH - 1:0] i_type_s;
    logic [OUT_WIDTH - 1:0] s_type_s;
    logic [OUT_WIDTH - 1:0] b_type_s;
    logic [OUT_WIDTH - 1:0] j_type_s;
    logic [OUT_WIDTH - 1:0] u_type_s;
    // logic [OUT_WIDTH - 1:0] csr_type;

    // Sign extend immediate for different instruction types.
    assign i_type_s = {{52 {imm_i[24]}}, imm_i[24:13]};
    assign s_type_s = {{52 {imm_i[24]}}, imm_i[24:18], imm_i[4:0]};
    assign b_type_s = {{52 {imm_i[24]}}, imm_i[0], imm_i[23:18], imm_i[4:1], 1'b0};
    assign j_type_s = {{44 {imm_i[24]}}, imm_i[12:5], imm_i[13], imm_i[23:14], 1'b0};
    assign u_type_s = {{32 {imm_i[24]}}, imm_i[24:5], {12 {1'b0}}};
    // assign csr_type_s = {59'b0, imm_i[12:8]};

    // MUX to choose output based on instruction type.
    //  ___________________________________
    // | control signal | instuction type |
    // |________________|_________________|
    // | 000            | I type          |
    // | 001            | S type          |
    // | 010            | B type          |
    // | 011            | J type          |
    // | 100            | U type          |
    // | 101            | CSR             |
    // |__________________________________|
    always_comb begin
        case (control_signal_i)
            3'b000: imm_ext_o = i_type_s;
            3'b001: imm_ext_o = s_type_s;
            3'b010: imm_ext_o = b_type_s;
            3'b011: imm_ext_o = j_type_s;
            3'b100: imm_ext_o = u_type_s;
            // 3'b101: imm_ext_o = csr_type_s;
            default: imm_ext_o = '0;
        endcase
    end


endmodule
