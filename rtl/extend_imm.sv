/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------
// This is a module to extend immediate input depending on type of instruction.
// ----------------------------------------------------------------------------

/*NOTE: Might optimize the mux width since upper 32 bits are always i_imm[24]*/

module extend_imm
// Parameters.
#(
    parameter IMM_WIDTH = 25,
              OUT_WIDTH = 64
) 
// Port decleration.
(
    // Control signal. 
    input  logic [             2:0 ] i_control_signal,

    // Input interface.
    input  logic [ IMM_WIDTH - 1:0 ] i_imm,
    
    // Output interface.
    output logic [ OUT_WIDTH - 1:0 ] o_imm_ext
);

    logic [ OUT_WIDTH - 1:0 ] s_i_type;
    logic [ OUT_WIDTH - 1:0 ] s_s_type;
    logic [ OUT_WIDTH - 1:0 ] s_b_type;
    logic [ OUT_WIDTH - 1:0 ] s_j_type;
    logic [ OUT_WIDTH - 1:0 ] s_u_type;
    // logic [ OUT_WIDTH - 1:0 ] csr_type;

    // Sign extend immediate for different instruction types. 
    assign s_i_type = { { 52 { i_imm [ 24 ] } }, i_imm [ 24:13 ] };
    assign s_s_type = { { 52 { i_imm [ 24 ] } }, i_imm [ 24:18 ], i_imm [ 4 :0  ] };
    assign s_b_type = { { 52 { i_imm [ 24 ] } }, i_imm [ 0     ], i_imm [ 23:18 ], i_imm[ 4 :1  ], 1'b0 };
    assign s_j_type = { { 44 { i_imm [ 24 ] } }, i_imm [ 12:5  ], i_imm [ 13    ], i_imm[ 23:14 ], 1'b0 };
    assign s_u_type = { { 32 { i_imm [ 24 ] } }, i_imm [ 24:5  ], { 12 { 1'b0 } } };
    // assign csr_type = { 59'b0, i_imm[12:8] };

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
        case ( i_control_signal )
            3'b000: o_imm_ext = s_i_type;
            3'b001: o_imm_ext = s_s_type;
            3'b010: o_imm_ext = s_b_type;
            3'b011: o_imm_ext = s_j_type;
            3'b100: o_imm_ext = s_u_type;
            // 3'b101: o_imm_ext = csr_type;
            default: o_imm_ext = '0;
        endcase
    end

    
endmodule