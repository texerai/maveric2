/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// ALU decoder is a module designed to output alu control signal based on
// op[5], alu_op, func3, func7[5] signals. 
// -----------------------------------------------------------------------

module alu_decoder
// Port delerations. 
(
    // Input interface.
    input  logic [2:0] alu_op_i,
    input  logic [2:0] func3_i,
    input  logic       func7_5_i,
    input  logic       op_5_i,

    // Output interface. 
    output logic [4:0] alu_control_o
);

    logic [1:0] op_5_func7_5_s;

    assign op_5_func7_5_s = {op_5_i, func7_5_i};

    // ALU decoder logic.
    always_comb begin 
        alu_control_o = '0;
        case (alu_op_i)
            3'b000: alu_control_o = 5'b00000; // ADD for I type instruction: lw, sw.
            3'b001: alu_control_o = 5'b00001; // SUB for B type instructions: beq, bne.

            // I & R Type.
            3'b010: 
                case (func3_i)
                    // I extension.
                    3'b000: if (op_5_func7_5_s == 2'b11) alu_control_o = 5'b00001;    // SUB.
                            else                           alu_control_o = 5'b00000;  // ADD & ADDI.
                    3'b001: alu_control_o = 5'b00101;                                 // SLL & SLLI.
                    3'b010: alu_control_o = 5'b00110;                                 // SLT.
                    3'b011: alu_control_o = 5'b00111;                                 // SLTU.
                    3'b100: alu_control_o = 5'b00100;                                 // XOR.
                    3'b101: if (func7_5_i) alu_control_o = 5'b01001;                  // SRA & SRAI.
                            else             alu_control_o = 5'b01000;                // SRLI & SRLI.
                    3'b110: alu_control_o = 5'b00011;                                 // OR.
                    3'b111: alu_control_o = 5'b00010;                                 // AND.
                    default: alu_control_o = 5'b00000;                                // Default to ADD.
                endcase

            // I & R Type W.
            3'b011: 
                case (func3_i)
                    // I extension
                    3'b000: if (op_5_func7_5_s == 2'b11) alu_control_o = 5'b01011;   // SUBW.
                            else                           alu_control_o = 5'b01010; // ADDW & ADDIW.
                    3'b001: alu_control_o = 5'b01100;                                // SLLIW or SLLW.
                    3'b101: if (func7_5_i) alu_control_o = 5'b01110;                 // SRAIW or SRAW.
                            else             alu_control_o = 5'b01101;               // SRLIW or SRLW.
                    default: alu_control_o = 5'b00000;                               // Default to ADD.
                endcase 

            // R Type M extension.
            // 3'b100:
            //     case (func3_i)
            //         3'b000: alu_control_o = 5'b01111;  // MUL.
            //         3'b001: alu_control_o = 5'b10000;  // MULH.
            //         3'b010: alu_control_o = 5'b10001;  // MULSHU.
            //         3'b011: alu_control_o = 5'b10010;  // MULHU.
            //         3'b100: alu_control_o = 5'b10011;  // DIV.
            //         3'b101: alu_control_o = 5'b10100;  // DIVU.
            //         3'b110: alu_control_o = 5'b10101;  // REM.
            //         3'b111: alu_control_o = 5'b10110;  // REMU.
            //         default: alu_control_o = 5'b00000; // Default to ADD.
            //     endcase

            // // R Type W M extansion.
            // 3'b101:
            //     case (func3_i)
            //         3'b000: alu_control_o = 5'b10111;  // MULW.
            //         3'b100: alu_control_o = 5'b11000;  // DIVW.
            //         3'b101: alu_control_o = 5'b11001;  // DIVUW.
            //         3'b110: alu_control_o = 5'b11010;  // REMW.
            //         3'b111: alu_control_o = 5'b11011;  // REMUW.
            //         default: alu_control_o = 5'b00000; // Default to ADD.
            //     endcase
            
            // CSR.
            // 3'b100:
            //     case (func3_i[1:0]) 
            //         2'b01: alu_control_o = 5'b10000;
            //         2'b10: alu_control_o = 5'b10001;
            //         2'b11: alu_control_o = 5'b10010;
            //         default: begin
            //             alu_control_o   = '0;
            //         end
            //     endcase
            
            default: begin
                alu_control_o = '0;
            end

        endcase
    end

    
endmodule
