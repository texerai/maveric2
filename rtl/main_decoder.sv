/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 03/07/2026
//------------------------------

// --------------------------------
// This is a main decoder module.
// --------------------------------

module main_decoder
(
    // Input interface.
    input  logic [6:0] op_i,
    input  logic [2:0] func3_i,
    /* verilator lint_off UNUSED */
    input  logic [6:0] func7_i,
    /* verilator lint_on UNUSED */
    input  logic [1:0] instr_21_20_i,
    input  logic [1:0] priv_mode_i,
    input  logic       valid_i,

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
    output logic       csr_access_o,
    output logic       trap_detected_o,
    output logic [5:0] trap_cause_o,
    output logic       trap_mret_o,
    output logic       trap_sret_o,
    output logic       load_instr_o,
    output logic       atomic_lr_o,
    output logic       atomic_sc_o,
    output logic       atomic_amo_op_o,
    output logic [4:0] atomic_alu_op_o,
    output logic       fencei_o,
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
        SYSTEM      = 4'b1101,
        ATOMIC      = 4'b1110,
        DEF         = 4'b1111
    } t_instruction;

    // Instruction decoder signal.
    t_instruction instr_type;

    //----------------------------
    // Instruction decoder logic.
    //---------------------- -----
    always_comb begin
        case (op_i)
            7'b0000011: instr_type = I_Type;
            7'b0010011: instr_type = I_Type_ALU;
            7'b1100111: instr_type = I_Type_JALR;
            7'b0011011: instr_type = I_Type_ALUW;
            7'b0100011: instr_type = S_Type;
            7'b0110011: instr_type = R_Type;
            7'b0111011: instr_type = R_Type_W;
            7'b1100011: instr_type = B_Type;
            7'b1101111: instr_type = J_Type;
            7'b0010111: instr_type = U_Type_ALU;
            7'b0110111: instr_type = U_Type_LOAD;
            7'b0001111: instr_type = FENCE_Type;
            7'b1110011: instr_type = (|func3_i) ? CSR_Type : SYSTEM;
            7'b0101111: instr_type = ATOMIC;
            default   : instr_type = DEF;
        endcase
    end

    instr_decoder INSTR_DEC (
        .instr_i   (instr_type),
        .imm_src_o (imm_src_o )
    );


    //----------------------------------------------
    // Decoder for output control signals.
    //----------------------------------------------
    always_comb begin
        // Default values.
        result_src_o     = 3'b0; // 000 - ALUResult, 001 - ReadDataMem, 010 - PCPlus4, 011 - PCPlusImm, 100 - ImmExtended, 101 - CSR read.
        alu_op_o         = 3'b0; // 000 - Add, 001 - Sub, 010 - I & R RV64I, 011 - I & R W RV64I, 100 - CSR, 101 - AMO.
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
        csr_access_o     = 1'b0;
        trap_detected_o  = 1'b0;
        trap_cause_o     = 6'b0;
        trap_mret_o      = 1'b0;
        trap_sret_o      = 1'b0;
        load_instr_o     = 1'b0;
        atomic_lr_o      = 1'b0;
        atomic_sc_o      = 1'b0;
        atomic_amo_op_o  = 1'b0;
        atomic_alu_op_o  = 5'b0;
        fencei_o         = 1'b0;
        is_mdu_op_o      = 1'b0;
        is_mdu_word_op_o = 1'b0;

        case (instr_type)
            I_Type: begin
                reg_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                result_src_o = 3'b1;
                mem_access_o = 1'b1;
                load_instr_o = 1'b1;
            end
            I_Type_ALU: begin
                reg_we_o   = 1'b1;
                alu_srcB_o = 2'b1;
                alu_op_o   = 3'b10;
            end
            I_Type_JALR: begin
                reg_we_o        = 1'b1;
                alu_srcB_o      = 2'b1;
                jump_o          = 1'b1;
                result_src_o    = 3'b10;
                pc_target_src_o = 1'b1;
            end
            I_Type_ALUW: begin
                reg_we_o   = 1'b1;
                alu_srcB_o = 2'b1;
                alu_op_o   = 3'b11;
            end
            S_Type: begin
                mem_we_o     = 1'b1;
                alu_srcB_o   = 2'b1;
                mem_access_o = 1'b1;
            end
            R_Type: begin
                reg_we_o = 1'b1;
                if (func7_i[0]) begin
                    is_mdu_op_o = 1'b1; // regular mult/div instruction
                end else begin
                    alu_op_o = 3'b010; // I & R RV64I.
                end
            end
            R_Type_W: begin
                reg_we_o = 1'b1;
                if (func7_i[0]) begin
                    is_mdu_op_o      = 1'b1;
                    is_mdu_word_op_o = 1'b1; // word instruction
                end else begin
                    alu_op_o = 3'b011; // I & R W RV64I.
                end
            end
            B_Type: begin
                branch_o = 1'b1;
                alu_op_o = 3'b01;
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
            FENCE_Type: begin
                fencei_o = func3_i[0]; // FENCE.I instr, others treated as nop, cause processor is already in-order.
            end
            CSR_Type: begin
                alu_op_o     = 3'b100;
                reg_we_o     = 1'b1;
                result_src_o = 3'b101;
                csr_we_o     = 1'b1;
                alu_srcA_o   = func3_i[2];
                alu_srcB_o   = 2'd2;
                csr_access_o = 1'b1;
            end
            SYSTEM: begin
                trap_detected_o = '0;
                trap_cause_o    = '0;
                if (instr_21_20_i == 2'b10) begin
                    if (func7_i[4] & (&priv_mode_i)) begin
                        trap_mret_o = 1'b1;
                    end else if ((~func7_i[4]) & (priv_mode_i >= 2'b01)) begin
                        trap_sret_o = 1'b1;
                    end else begin
                        trap_detected_o = valid_i;
                        trap_cause_o    = 6'd2; // Illegal instr.
                    end
                end else if (instr_21_20_i == 2'b01) begin
                    trap_detected_o = 1'b1;
                    trap_cause_o    = 6'd3; // Ebreak.
                end else if (instr_21_20_i == 2'b00) begin
                    trap_detected_o = 1'b1;
                    trap_cause_o    = 6'd11; // M-mode Ecall.
                    case (priv_mode_i)
                        2'b00: trap_cause_o = 6'd8; // U-mode Ecall.
                        2'b01: trap_cause_o = 6'd9; // S-mode Ecall.
                        2'b11: trap_cause_o = 6'd11; // M-mode Ecall.
                        default: trap_cause_o = 6'd11; // M-mode Ecall.
                    endcase
                end
            end
            ATOMIC: begin
                result_src_o    = 3'b1;
                mem_access_o    = 1'b1;
                load_instr_o    = 1'b1;
                reg_we_o        = 1'b1;
                alu_op_o        = 3'b101; // Bypass rs1.
                alu_srcA_o      = 1'b0; // rs1;
                alu_srcB_o      = 2'b0; // rs2;
                atomic_lr_o     = 1'b0;
                atomic_sc_o     = 1'b0;
                atomic_amo_op_o = 1'b0;
                atomic_alu_op_o = 5'b0;

                case (func7_i[3:2])
                    2'b00,
                    2'b01: begin
                        atomic_amo_op_o = 1'b1;
                        atomic_alu_op_o = {func7_i[2], func3_i[0], func7_i[6:4]};
                    end
                    2'b10: begin
                        atomic_lr_o = 1'b1;
                    end
                    2'b11: begin
                        atomic_sc_o = 1'b1;
                    end
                endcase
            end

            DEF: begin
                trap_detected_o = valid_i;
                trap_cause_o    = 6'd2; // Illegal instr.
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
                csr_access_o     = 1'b0;
                trap_detected_o  = 1'b0;
                trap_cause_o     = 6'b0;
                trap_mret_o      = 1'b0;
                trap_sret_o      = 1'b0;
                load_instr_o     = 1'b0;
                atomic_lr_o      = 1'b0;
                atomic_sc_o      = 1'b0;
                atomic_amo_op_o  = 1'b0;
                atomic_alu_op_o  = 5'b0;
                fencei_o         = 1'b0;
                is_mdu_op_o      = 1'b0;
                is_mdu_word_op_o = 1'b0;
            end
        endcase
    end

endmodule
