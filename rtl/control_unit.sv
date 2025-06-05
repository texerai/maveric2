/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------------------
// This is a main control unit that decodes instructions and outputs control signals.
// -----------------------------------------------------------------------------------

module control_unit
(
    // Input interface.
    input  logic [6:0] op_i,
    input  logic [2:0] func3_i,
    input  logic       func7_5_i,
    input  logic       instr_25_i,

    // Output interface.
    output logic [2:0] imm_src_o,
    output logic [2:0] result_src_o,
    output logic [4:0] alu_control_o,
    output logic       mem_we_o,
    output logic       reg_we_o,
    output logic       alu_src_o,
    output logic       branch_o,
    output logic       jump_o,
    output logic       pc_target_src_o,
    output logic [1:0] forward_src_o,
    output logic       mem_access_o,
    output logic       ecall_instr_o,
    output logic [3:0] cause_o,
    output logic       load_instr_o
);

    //------------------
    // Internal nets.
    //------------------
    logic [2:0] alu_op_s;


    //----------------------
    // Lower level modules.
    //----------------------
    
    // Main decoder.
    main_decoder M_DEC (
        .op_i            (op_i           ),
        .instr_25_i      (instr_25_i     ),
        .imm_src_o       (imm_src_o      ),
        .result_src_o    (result_src_o   ),
        .alu_op_o        (alu_op_s       ),
        .mem_we_o        (mem_we_o       ),
        .reg_we_o        (reg_we_o       ),
        .alu_src_o       (alu_src_o      ),
        .branch_o        (branch_o       ),
        .jump_o          (jump_o         ),
        .pc_target_src_o (pc_target_src_o),
        .forward_src_o   (forward_src_o  ),
        .mem_access_o    (mem_access_o   ),
        .ecall_instr_o   (ecall_instr_o  ),
        .cause_o         (cause_o        ),
        .load_instr_o    (load_instr_o   )
    );

    // ALU decoder.
    alu_decoder ALU_DEC (
        .alu_op_i      (alu_op_s     ),
        .func3_i       (func3_i      ),
        .func7_5_i     (func7_5_i    ),
        .op_5_i        (op_i[5]      ),
        .alu_control_o (alu_control_o)
    );
    
endmodule
