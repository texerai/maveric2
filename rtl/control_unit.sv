/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/06/2026
//------------------------------

// -----------------------------------------------------------------------------------
// This is a main control unit that decodes instructions and outputs control signals.
// -----------------------------------------------------------------------------------

module control_unit
(
    // Input interface.
    input  logic [6:0] op_i,
    input  logic [2:0] func3_i,
    input  logic [6:0] func7_i,
    input  logic [1:0] instr_21_20_i,

    // Output interface.
    output logic [2:0] imm_src_o,
    output logic [2:0] result_src_o,
    output logic [4:0] alu_control_o,
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
    output logic       trap_detected_o,
    output logic [5:0] trap_cause_o,
    output logic       trap_return_o,
    output logic       load_instr_o,
    output logic       atomic_lr_o,
    output logic       atomic_sc_o,
    output logic       atomic_aq_o,
    output logic       atomic_rl_o,
    output logic       atomic_amo_op_o,
    output logic [4:0] atomic_alu_op_o,
    output logic       is_mdu_op_o,
    output logic       is_mdu_word_op_o
);

    //------------------
    // Internal nets.
    //------------------
    logic [2:0] alu_op;


    //----------------------
    // Lower level modules.
    //----------------------

    // Main decoder.
    main_decoder M_DEC (
        .op_i             (op_i            ),
        .func3_i          (func3_i         ),
        .func7_i          (func7_i         ),
        .instr_21_20_i    (instr_21_20_i   ),
        .imm_src_o        (imm_src_o       ),
        .result_src_o     (result_src_o    ),
        .alu_op_o         (alu_op          ),
        .mem_we_o         (mem_we_o        ),
        .reg_we_o         (reg_we_o        ),
        .csr_we_o         (csr_we_o        ),
        .alu_srcA_o       (alu_srcA_o      ),
        .alu_srcB_o       (alu_srcB_o      ),
        .branch_o         (branch_o        ),
        .jump_o           (jump_o          ),
        .pc_target_src_o  (pc_target_src_o ),
        .forward_src_o    (forward_src_o   ),
        .mem_access_o     (mem_access_o    ),
        .trap_detected_o  (trap_detected_o ),
        .trap_cause_o     (trap_cause_o    ),
        .trap_return_o    (trap_return_o   ),
        .load_instr_o     (load_instr_o    ),
        .atomic_lr_o      (atomic_lr_o     ),
        .atomic_sc_o      (atomic_sc_o     ),
        .atomic_aq_o      (atomic_aq_o     ),
        .atomic_rl_o      (atomic_rl_o     ),
        .atomic_amo_op_o  (atomic_amo_op_o ),
        .atomic_alu_op_o  (atomic_alu_op_o ),
        .is_mdu_op_o      (is_mdu_op_o     ),
        .is_mdu_word_op_o (is_mdu_word_op_o)
    );

    // ALU decoder.
    alu_decoder ALU_DEC (
        .alu_op_i      (alu_op       ),
        .func3_i       (func3_i      ),
        .func7_5_i     (func7_i[5]   ),
        .op_5_i        (op_i[5]      ),
        .alu_control_o (alu_control_o)
    );

endmodule
