/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------------------
// This is a main control unit that decodes instructions and outputs control signals.
// -----------------------------------------------------------------------------------

module control_unit
(
    // Input interface.
    input  logic [ 6:0 ] i_op,
    input  logic [ 2:0 ] i_func3,
    input  logic         i_func7_5,
    input  logic         i_instr_25,

    // Output interface.
    output logic [ 2:0 ] o_imm_src,
    output logic [ 2:0 ] o_result_src,
    output logic [ 4:0 ] o_alu_control,
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

    //------------------
    // Internal nets.
    //------------------
    logic [ 2:0 ] s_alu_op;


    //----------------------
    // Lower level modules.
    //----------------------
    
    // Main decoder.
    main_decoder M_DEC (
        .i_op            ( i_op            ),
        .i_instr_25      ( i_instr_25      ),
        .o_imm_src       ( o_imm_src       ),
        .o_result_src    ( o_result_src    ),
        .o_alu_op        ( s_alu_op        ),
        .o_mem_we        ( o_mem_we        ),
        .o_reg_we        ( o_reg_we        ),
        .o_alu_src       ( o_alu_src       ),
        .o_branch        ( o_branch        ),
        .o_jump          ( o_jump          ),
        .o_pc_target_src ( o_pc_target_src ),
        .o_forward_src   ( o_forward_src   ),
        .o_mem_access    ( o_mem_access    ),
        .o_ecall_instr   ( o_ecall_instr   ),
        .o_cause         ( o_cause         ),
        .o_load_instr    ( o_load_instr    )
    );

    // ALU decoder.
    alu_decoder ALU_DEC (
        .i_alu_op      ( s_alu_op      ),
        .i_func3       ( i_func3       ),
        .i_func7_5     ( i_func7_5     ),
        .i_op_5        ( i_op [ 5 ]    ), 
        .o_alu_control ( o_alu_control )
    );
    
endmodule