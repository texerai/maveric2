/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 09/06/2026
//------------------------------

// --------------------------------
// This is a main decoder module.
// --------------------------------

module main_decoder
(
    // Input interface.
    input  logic [6:0] op_i,
    input  logic [2:0] func3_i,
    input  logic       instr_20_i,
    input  logic       instr_25_i,

    // Output interface.
    output logic [2:0] imm_src_o,
    output logic [2:0] result_src_o,
    output logic [2:0] alu_op_o,
    output logic       mem_we_o,
    output logic       reg_we_o,
    output logic       csr_we_o,
    output logic       alu_srcA_o,
    output logic [1:0] alu_srcB_o,
    output logic       branch_o,
    output logic       jump_o,
    output logic       pc_target_src_o,
    output logic [1:0] forward_src_o,
    output logic       mem_access_o,
    output logic       ecall_instr_o,
    output logic [3:0] cause_o,
    output logic       load_instr_o,
    output logic       is_mdu_op_o,
    output logic       is_mdu_word_op_o
);

    // Instruction type.
    typedef enum logic [3:0] {
        I_Type      = 4'b0000,
        I_Type_ALU  = 4'b0001,
        I_Type_JALR = 4'b0010,
        I_Type_ALUW = 4'b0011,
        S_Type      = 4'b0100,
        R_Type      = 4'b0101,
        R_Type_W    = 4'b0110,
        B_Type      = 4'b0111,
        J_Type      = 4'b1000,
        U_Type_ALU  = 4'b1001,
        U_Type_LOAD = 4'b1010,
        FENCE_Type  = 4'b1011,
        CSR_Type    = 4'b1100,
        CALL        = 4'b1101,
        DEF         = 4'b1111
    } t_instruction;

    // Instruction decoder signal.
    t_instruction instr_type_s;

    //----------------------------
    // Instruction decoder logic.
    //---------------------- -----
    always_comb begin
        case (op_i)
            7'b0000011: instr_type_s = I_Type;
            7'b0010011: instr_type_s = I_Type_ALU;
            7'b1100111: instr_type_s = I_Type_JALR;
            7'b0011011: instr_type_s = I_Type_ALUW;
            7'b0100011: instr_type_s = S_Type;
            7'b0110011: instr_type_s = R_Type;
            7'b0111011: instr_type_s = R_Type_W;
            7'b1100011: instr_type_s = B_Type;
            7'b1101111: instr_type_s = J_Type;
            7'b0010111: instr_type_s = U_Type_ALU;
            7'b0110111: instr_type_s = U_Type_LOAD;
            7'b0001111: instr_type_s = FENCE_Type;
            7'b1110011: instr_type_s = (|func3_i) ? CSR_Type : CALL;
            default   : instr_type_s = DEF;
        endcase
    end

    instr_decoder INSTR_DEC (
        .instr_i   (instr_type_s),
        .imm_src_o (imm_src_o   )
    );


    //----------------------------------------------
    // Decoder for output control signals.
    //----------------------------------------------
    always_comb begin
        // Default values.
        result_src_o     = 3'b0; // 000 - ALUResult, 001 - ReadDataMem, 010 - PCPlus4, 011 - PCPlusImm, 100 - ImmExtended, 101 - CSR read.
        alu_op_o         = 3'b0; // 000 - Add, 001 - Sub, 010 - I & R RV64I, 011 - I & R W RV64I, 100 - CSR.
        mem_we_o         = 1'b0;
        reg_we_o         = 1'b0;
        csr_we_o         = 1'b0;
        alu_srcA_o       = 1'b0; // 0 - Reg, 1 - Immediate.
        alu_srcB_o       = 2'b0; // 0 - Reg, 1 - Immediate, 2 - CSR read.
        branch_o         = 1'b0;
        jump_o           = 1'b0;
        pc_target_src_o  = 1'b0; // 0 - PC + IMM , 1 - ALUResult.
        forward_src_o    = 2'b0; // 00 - ALUResult, 01 - PCTarget, 10 - ImmExt.
        mem_access_o     = 1'b0;
        ecall_instr_o    = 1'b0;
        cause_o          = 4'b0;
        load_instr_o     = 1'b0;
        is_mdu_op_o      = 1'b0;
        is_mdu_word_op_o = 1'b0;

        case (instr_type_s)
            I_Type: begin
                reg_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                result_src_o = 3'b1;
                mem_access_o = 1'b1;
                load_instr_o = 1'b1;
            end
            I_Type_ALU: begin
                reg_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                alu_op_o     = 3'b10;
            end
            I_Type_JALR: begin
                reg_we_o        = 1'b1;
                alu_srcB_o      = 2'b1;
                jump_o          = 1'b1;
                result_src_o    = 3'b10;
                pc_target_src_o = 1'b1;
            end
            I_Type_ALUW: begin
                reg_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                alu_op_o     = 3'b11;
            end
            S_Type: begin
                mem_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                mem_access_o = 1'b1;
            end
            R_Type: begin
                reg_we_o  = 1'b1;
                if (instr_25_i) begin
                    is_mdu_op_o = 1'b1; // regular mult/div instruction
                end else begin
                    alu_op_o = 3'b010; // I & R RV64I.
                end
            end
            R_Type_W: begin
                reg_we_o = 1'b1;
                if (instr_25_i) begin
                    is_mdu_op_o      = 1'b1;
                    is_mdu_word_op_o = 1'b1; // word instruction
                end else begin
                    alu_op_o = 3'b011; // I & R W RV64I.
                end
            end
            B_Type: begin
                branch_o     = 1'b1;
                alu_op_o     = 3'b01;
            end
            J_Type: begin
                reg_we_o     = 1'b1;
                jump_o       = 1'b1;
                result_src_o = 3'b10;
            end
            U_Type_ALU: begin
                reg_we_o      = 1'b1;
                result_src_o  = 3'b11;
                forward_src_o = 2'b01;
            end
            U_Type_LOAD: begin
                reg_we_o      = 1'b1;
                result_src_o  = 3'b100;
                forward_src_o = 2'b10;
            end
            CSR_Type: begin
                reg_we_o     = 1'b1;
                result_src_o = 3'b101;
                csr_we_o     = 1'b1;
                alu_srcA_o   = func3_i[2];
                alu_srcB_o   = 2'd2;
            end
            CALL: begin
                ecall_instr_o = 1'b1;
                if (instr_20_i) cause_o = 4'd3;  // Ebreak.
                else            cause_o = 4'd11; // M-mode Ecall.
            end

            DEF: begin
                if (op_i != 7'b0000000) begin
                    ecall_instr_o = 1'b1;
                    cause_o       = 4'b0010; // Illegal instr.
                end
            end
            default: begin
                result_src_o     = 3'b0;
                alu_op_o         = 3'b0;
                mem_we_o         = 1'b0;
                reg_we_o         = 1'b0;
                csr_we_o         = 1'b0;
                alu_srcA_o       = 1'b0;
                alu_srcB_o       = 2'b0;
                branch_o         = 1'b0;
                jump_o           = 1'b0;
                pc_target_src_o  = 1'b0;
                forward_src_o    = 2'b0;
                mem_access_o     = 1'b0;
                ecall_instr_o    = 1'b0;
                load_instr_o     = 1'b0;
                is_mdu_op_o      = 1'b0;
                is_mdu_word_op_o = 1'b0;
            end
        endcase
    end

endmodule
