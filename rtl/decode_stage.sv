/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the decode stage.
// ----------------------------------------------------------------------------------------

module decode_stage
#(
    parameter ADDR_WIDTH  = 64,
              DATA_WIDTH  = 64,
              REG_ADDR_W  = 5,
              INSTR_WIDTH = 32
) 
(
    // Input interface.
    input  logic                       i_clk,
    input  logic                       i_arst,
    input  logic [ INSTR_WIDTH - 1:0 ] i_instruction,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_plus4,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc,
    input  logic [ DATA_WIDTH  - 1:0 ] i_rd_write_data,
    input  logic [ REG_ADDR_W  - 1:0 ] i_rd_addr,
    input  logic                       i_reg_we,
    input  logic [ ADDR_WIDTH  - 1:0 ] i_pc_target_addr_pred,
    input  logic [               1:0 ] i_btb_way,
    input  logic                       i_branch_pred_taken,
    input  logic                       i_log_trace,

    // Output interface.
    output logic [               2:0 ] o_func3,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_plus4,
    output logic [ DATA_WIDTH  - 1:0 ] o_rs1_data,
    output logic [ DATA_WIDTH  - 1:0 ] o_rs2_data,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs1_addr,
    output logic [ REG_ADDR_W  - 1:0 ] o_rs2_addr,
    output logic [ REG_ADDR_W  - 1:0 ] o_rd_addr,
    output logic [ DATA_WIDTH  - 1:0 ] o_imm_ext,
    output logic [               2:0 ] o_result_src,
    output logic [               4:0 ] o_alu_control,
    output logic                       o_mem_we,
    output logic                       o_reg_we,
    output logic                       o_alu_src,
    output logic                       o_branch,
    output logic                       o_jump,
    output logic                       o_pc_target_src,
    output logic [               1:0 ] o_forward_src,
    output logic                       o_mem_access,
    output logic [ ADDR_WIDTH  - 1:0 ] o_pc_target_addr_pred,
    output logic [               1:0 ] o_btb_way,
    output logic                       o_branch_pred_taken,
    output logic                       o_ecall_instr,
    output logic                       o_log_trace,
    output logic [ INSTR_WIDTH - 1:0 ] o_instruction_log,
    output logic [               3:0 ] o_cause,
    output logic                       o_a0_reg_lsb,
    output logic                       o_load_instr
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    
    // Control signals.
    logic [ 6 :0 ] s_op;
    logic [ 2 :0 ] s_func3;
    logic          s_func7_5;
    logic          s_instr_25;

    // 
    logic         s_reg_we;
    logic         s_rd_zero;
    
    // Extend imm signal.
    logic [             24:0 ] s_imm_data;
    logic [              2:0 ] s_imm_src;

    // Register file.
    logic [ REG_ADDR_W - 1:0 ] s_rs1_addr;
    logic [ REG_ADDR_W - 1:0 ] s_rs2_addr;
    logic [ REG_ADDR_W - 1:0 ] s_rd_addr;


    //-------------------------------------------
    // Continious assignments for internal nets.
    //-------------------------------------------
    assign s_op       = i_instruction [ 6 :0  ];
    assign s_func3    = i_instruction [ 14:12 ];
    assign s_func7_5  = i_instruction [ 30    ];
    assign s_instr_25 = i_instruction [ 25    ];
    assign s_imm_data = i_instruction [ 31:7  ];

    assign s_rs1_addr = i_instruction [ 19:15 ];
    assign s_rs2_addr = i_instruction [ 24:20 ]; 
    assign s_rd_addr  = i_instruction [ 11:7  ];

    // Check if the destination address is zero. If so don't enable we.
    assign s_rd_zero = | s_rd_addr;
    assign o_reg_we  = s_reg_we & s_rd_zero;

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Control unit.
    control_unit CU0 (
        .i_op            ( s_op            ),
        .i_func3         ( s_func3         ),
        .i_func7_5       ( s_func7_5       ),
        .i_instr_25      ( s_instr_25      ),
        .o_imm_src       ( s_imm_src       ),
        .o_result_src    ( o_result_src    ),
        .o_alu_control   ( o_alu_control   ),
        .o_mem_we        ( o_mem_we        ),
        .o_reg_we        ( s_reg_we        ),
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

    // Extend immediate module.
    extend_imm EI0 (
        .i_control_signal ( s_imm_src  ),
        .i_imm            ( s_imm_data ),
        .o_imm_ext        ( o_imm_ext  )
    );

    // Register file.
    register_file REG_FILE0 (
        .i_clk          ( i_clk           ),
        .i_write_en_3   ( i_reg_we        ),
        .i_arst         ( i_arst          ),
        .i_addr_1       ( s_rs1_addr      ),
        .i_addr_2       ( s_rs2_addr      ),
        .i_addr_3       ( i_rd_addr       ),
        .i_write_data_3 ( i_rd_write_data ),
        .o_a0_reg_lsb   ( o_a0_reg_lsb    ),
        .o_read_data_1  ( o_rs1_data      ),
        .o_read_data_2  ( o_rs2_data      )
    );


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign o_pc_plus4            = i_pc_plus4;
    assign o_pc                  = i_pc;
    assign o_rs1_addr            = s_rs1_addr;
    assign o_rs2_addr            = s_rs2_addr;
    assign o_rd_addr             = s_rd_addr;
    assign o_func3               = s_func3;
    assign o_pc_target_addr_pred = i_pc_target_addr_pred;
    assign o_btb_way             = i_btb_way;
    assign o_branch_pred_taken   = i_branch_pred_taken;
    
    // Log trace.
    assign o_log_trace       = i_log_trace;
    assign o_instruction_log = i_instruction;
endmodule
