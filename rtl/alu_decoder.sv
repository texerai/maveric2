/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// ALU decoder is a module designed to output alu control signal based on
// op[5], alu_op, func3, func7[5] signals. 
// -----------------------------------------------------------------------

module alu_decoder 
// Port delerations. 
(
    // Input interface.
    input  logic [ 2:0 ] i_alu_op,
    input  logic [ 2:0 ] i_func3,
    input  logic         i_func7_5,
    input  logic         i_op_5,

    // Output interface. 
    output logic [ 4:0 ] o_alu_control
);

    logic [ 1:0 ] s_op_func7_5;

    assign s_op_func7_5 = { i_op_5, i_func7_5 };

    // ALU decoder logic.
    always_comb begin 
        o_alu_control = '0;
        case ( i_alu_op )
            3'b000: o_alu_control = 5'b00000; // ADD for I type instruction: lw, sw.
            3'b001: o_alu_control = 5'b00001; // SUB for B type instructions: beq, bne.

            // I & R Type.
            3'b010: 
                case ( i_func3 )
                    3'b000: if ( s_op_func7_5 == 2'b11 ) o_alu_control = 5'b00001; // SUB.
                            else                         o_alu_control = 5'b00000; // ADD & ADDI.
                    3'b001:                              o_alu_control = 5'b00101; // SLL & SLLI.
                    3'b010:                              o_alu_control = 5'b00110; // SLT.
                    3'b011:                              o_alu_control = 5'b00111; // SLTU.
                    3'b100:                              o_alu_control = 5'b00100; // XOR.
                    3'b101: if ( i_func7_5 )             o_alu_control = 5'b01001; // SRA & SRAI. 
                            else                         o_alu_control = 5'b01000; // SRLI & SRLI.
                    3'b110:                              o_alu_control = 5'b00011; // OR.
                    3'b111:                              o_alu_control = 5'b00010; // AND
                    default:                             o_alu_control = 5'b00000; // Default to ADD. 
                endcase

            // I & R Type W.
            3'b011: 
                case ( i_func3 )
                    3'b000: if ( s_op_func7_5 == 2'b11 ) o_alu_control = 5'b01011; // SUBW.
                            else                         o_alu_control = 5'b01010; // ADDW & ADDIW.
                    3'b001:                              o_alu_control = 5'b01100; // SLLIW or SLLW
                    3'b101: if ( i_func7_5 )             o_alu_control = 5'b01110; // SRAIW or SRAW.
                            else                         o_alu_control = 5'b01101; // SRLIW or SRLW. 
                    default:                             o_alu_control = 5'b00000; // Default to ADD.                     
                endcase 

            // CSR.
            // 3'b100: 
            //     case ( i_func3[1:0] ) 
            //         2'b01: o_alu_control = 5'b10000;
            //         2'b10: o_alu_control = 5'b10001;
            //         2'b11: o_alu_control = 5'b10010;
            //         default: begin
            //             o_alu_control   = '0;
            //         end
            //     endcase
            
            default: begin
                o_alu_control   = '0;
            end

        endcase
    end

    
endmodule
