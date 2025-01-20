/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------
// This is a main decoder module.
// --------------------------------

module main_decoder
(
    // Input interface.
    input  logic [ 6:0 ] i_op,
    input  logic         i_instr_25,

    // Output interface.
    output logic [ 2:0 ] o_imm_src,
    output logic [ 2:0 ] o_result_src,
    output logic [ 2:0 ] o_alu_op,
    output logic         o_mem_we,
    output logic         o_reg_we,
    output logic         o_alu_src,
    output logic         o_branch,
    output logic         o_jump,
    output logic         o_pc_target_src,
    output logic [ 1:0 ] o_forward_src,
    output logic         o_mem_access,
    output logic         o_ecall_instr,
    output logic [ 3:0 ] o_cause,
    output logic         o_load_instr        
);


    // import "DPI-C" function void check(byte a0, byte mcause);

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
        ECALL       = 4'b1110,
        DEF         = 4'b1111
    } t_instruction;

    // Instruction decoder signal. 
    t_instruction s_instr_type;

    //----------------------------
    // Instruction decoder logic.
    //---------------------- -----
    always_comb begin
        case ( i_op )
            7'b0000011: s_instr_type = I_Type;
            7'b0010011: s_instr_type = I_Type_ALU;
            7'b1100111: s_instr_type = I_Type_JALR;
            7'b0011011: s_instr_type = I_Type_ALUW;
            7'b0100011: s_instr_type = S_Type;
            7'b0110011: s_instr_type = i_instr_25 ? DEF : R_Type;
            7'b0111011: s_instr_type = i_instr_25 ? DEF : R_Type_W;
            7'b1100011: s_instr_type = B_Type;
            7'b1101111: s_instr_type = J_Type;
            7'b0010111: s_instr_type = U_Type_ALU;
            7'b0110111: s_instr_type = U_Type_LOAD;
            7'b1110011: s_instr_type = ECALL;
            default   : s_instr_type = DEF;
        endcase
    end

    instr_decoder INSTR_DEC (
        .i_instr   ( s_instr_type ),
        .o_imm_src ( o_imm_src    )
    );


    //----------------------------------------------
    // Decoder for output control signals.
    //----------------------------------------------
    /* verilator lint_off WIDTH */
    always_comb begin
        // Default values.
        o_result_src    = 3'b0; // 000 - ALUResult, 001 - ReadDataMem, 010 - PCPlus4, 011 - PCPlusImm, 100 - ImmExtended.
        o_alu_op        = 3'b0; // 000 - Add, 001 - Sub, 010 - I & R, I & R W.
        o_mem_we        = 1'b0;
        o_reg_we        = 1'b0;
        o_alu_src       = 1'b0; // 0 - Reg, 1 - Immediate.
        o_branch        = 1'b0;
        o_jump          = 1'b0;
        o_pc_target_src = 1'b0; // 0 - PC + IMM , 1 - ALUResult.
        o_forward_src   = 2'b0; // 00 - ALUResult, 01 - PCTarget, 10 - ImmExt. 
        o_mem_access    = 1'b0;
        o_ecall_instr   = 1'b0;
        o_cause         = 4'b0;
        o_load_instr    = 1'b0;

        case ( s_instr_type )
            I_Type: begin
                o_reg_we     = 1'b1;
                o_alu_src    = 1'b1;
                o_result_src = 3'b1;
                o_mem_access = 1'b1;
                o_load_instr = 1'b1;
            end
            I_Type_ALU: begin
                o_reg_we     = 1'b1;
                o_alu_src    = 1'b1;
                o_alu_op     = 3'b10;
            end
            I_Type_JALR: begin
                o_reg_we        = 1'b1;
                o_alu_src       = 1'b1; 
                o_jump          = 1'b1;
                o_result_src    = 3'b10;
                o_pc_target_src = 1'b1;
            end
            I_Type_ALUW: begin
                o_reg_we     = 1'b1;
                o_alu_src    = 1'b1;
                o_alu_op     = 3'b11; 
            end
            S_Type: begin
                o_mem_we     = 1'b1;
                o_alu_src    = 1'b1;
                o_mem_access = 1'b1;
            end
            R_Type: begin
                o_reg_we     = 1'b1;
                o_alu_op     = 3'b10;
            end
            R_Type_W: begin
                o_reg_we     = 1'b1;
                o_alu_op     = 3'b11;
            end
            B_Type: begin
                o_branch     = 1'b1;
                o_alu_op     = 3'b1;
            end
            J_Type: begin
                o_reg_we     = 1'b1;
                o_jump       = 1'b1;
                o_result_src = 3'b10;
            end
            U_Type_ALU: begin
                o_reg_we      = 1'b1;
                o_result_src  = 3'b11;
                o_forward_src = 2'b01;
            end
            U_Type_LOAD: begin
                o_reg_we      = 1'b1; 
                o_result_src  = 3'b100;
                o_forward_src = 2'b10; 
            end
            ECALL: begin
                o_ecall_instr = 1'b1;
                o_cause       = 4'b0011;
                //check(i_a0_reg_lsb, 3); // For now the cause will be registered as ecall.
                //$stop; // For simulation only.
                //$display("time =%0t", $time);
            end

            DEF: begin
                if ( i_op != 7'b0000000 ) begin
                    o_ecall_instr = 1'b1;
                    o_cause       = 4'b0010;
                    //check(i_a0_reg_lsb, 2);
                    //$stop; // For simulation only. 
                end 
            end
            default: begin
                o_result_src    = 3'b0;
                o_alu_op        = 3'b0;
                o_mem_we        = 1'b0;
                o_reg_we        = 1'b0;
                o_alu_src       = 1'b0;
                o_branch        = 1'b0;
                o_jump          = 1'b0; 
                o_pc_target_src = 1'b0;
                o_forward_src   = 2'b0;
                o_mem_access    = 1'b0;
                o_ecall_instr   = 1'b0;
                o_load_instr    = 1'b0;
            end
        /* verilator lint_off WIDTH */
        endcase
    end

   


endmodule