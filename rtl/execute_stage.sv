/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 18/06/2026
//------------------------------

// -------------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the execute stage.
// -------------------------------------------------------------------------------------------

module execute_stage
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter REG_ADDR_W  = 5,
    parameter CSR_ADDR_W  = 12
)
(
    // Input interface.
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic [             2:0] result_src_i,
    input  logic [             4:0] alu_control_i,
    input  logic                    mem_we_i,
    input  logic                    reg_we_i,
    input  logic                    csr_we_i,
    input  logic                    alu_srcA_i,
    input  logic [             1:0] alu_srcB_i,
    input  logic                    branch_i,
    input  logic                    jump_i,
    input  logic                    pc_target_src_i,
    input  logic [ADDR_WIDTH - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH - 1:0] pc_i,
    input  logic [DATA_WIDTH - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH - 1:0] rs1_data_i,
    input  logic [DATA_WIDTH - 1:0] rs2_data_i,
    input  logic [REG_ADDR_W - 1:0] rs1_addr_i,
    input  logic [REG_ADDR_W - 1:0] rs2_addr_i,
    input  logic [REG_ADDR_W - 1:0] rd_addr_i,
    input  logic [CSR_ADDR_W - 1:0] csr_read_addr_i,
    input  logic [             2:0] func3_i,
    input  logic [             1:0] forward_src_i,
    input  logic                    mem_access_i,
    input  logic [ADDR_WIDTH - 1:0] pc_target_addr_pred_i,
    input  logic [             1:0] btb_way_i,
    input  logic                    branch_pred_taken_i,
    input  logic                    trap_detected_i,
    input  logic [             5:0] trap_cause_i,
    input  logic                    trap_return_i,
    input  logic                    load_instr_i,
    input  logic                    is_mdu_op_i,
    input  logic                    is_mdu_word_op_i,
    input  logic [CSR_ADDR_W - 1:0] csr_write_addr_i,
    input  logic [DATA_WIDTH - 1:0] csr_write_data_i,
    input  logic                    csr_we_wb_i,
    input  logic [DATA_WIDTH - 1:0] result_i,
    input  logic [DATA_WIDTH - 1:0] forward_value_i,
    input  logic [             1:0] forward_rs1_ex_i,
    input  logic [             1:0] forward_rs2_ex_i,
    input  logic [DATA_WIDTH - 1:0] mepc_write_data_i,
    input  logic [             5:0] mcause_write_data_i,
    input  logic                    trap_taken_i,
    input  logic [DATA_WIDTH - 1:0] mtime_val_i,
    input  logic                    timer_irq_i,
    input  logic                    software_irq_i,
    input  logic                    log_trace_i,

    // Output interface.
    output logic [             2:0] result_src_o,
    output logic                    mem_we_o,
    output logic                    reg_we_o,
    output logic                    csr_we_o,
    output logic [ADDR_WIDTH - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH - 1:0] imm_ext_o,
    output logic [DATA_WIDTH - 1:0] alu_result_o,
    output logic [DATA_WIDTH - 1:0] write_data_o,
    output logic [             1:0] forward_src_o,
    output logic [             2:0] func3_o,
    output logic                    mem_access_o,
    output logic                    trap_detected_o,
    output logic [             5:0] trap_cause_o,
    output logic                    trap_return_o,
    output logic [REG_ADDR_W - 1:0] rd_addr_o,
    output logic [CSR_ADDR_W - 1:0] csr_write_addr_o,
    output logic [DATA_WIDTH - 1:0] csr_read_data_o,
    output logic [ADDR_WIDTH - 1:0] pc_log_o,
    output logic [ADDR_WIDTH - 1:0] pc_new_o,
    output logic [REG_ADDR_W - 1:0] rs1_addr_o,
    output logic [REG_ADDR_W - 1:0] rs2_addr_o,
    output logic                    branch_mispred_o,
    output logic                    branch_instr_ex_o,
    output logic                    branch_taken_ex_o,
    output logic [             1:0] btb_way_ex_o,
    output logic [ADDR_WIDTH - 1:0] pc_ex_o,
    output logic                    load_instr_o,
    output logic                    mdu_busy_o,
    output logic [ADDR_WIDTH - 1:0] csr_mtvec_read_o,
    output logic [ADDR_WIDTH - 1:0] csr_mepc_read_o,
    output logic                    log_trace_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [DATA_WIDTH - 1:0] alu_srcA;
    logic [DATA_WIDTH - 1:0] alu_srcB;
    logic [DATA_WIDTH - 1:0] forward_srcA;
    logic [DATA_WIDTH - 1:0] forward_srcB;
    logic [DATA_WIDTH - 1:0] write_data;
    logic [DATA_WIDTH - 1:0] csr_read_data;

    logic [DATA_WIDTH - 1:0] alu_result;
    logic [DATA_WIDTH - 1:0] mdu_result;
    logic [ADDR_WIDTH - 1:0] pc_plus_imm;
    logic [ADDR_WIDTH - 1:0] rs1_plus_imm;
    logic [ADDR_WIDTH - 1:0] pc_target_addr;

    logic zero_flag;
    logic lt_flag;
    logic ltu_flag;

    logic branch;

    logic [ADDR_WIDTH - 1:0] pc_new;
    logic                    branch_taken;
    logic                    branch_instr;

    logic       trap_detected_addr_ma;
    logic       trap_detected_clint;
    logic       trap_detected_clint_valid;
    logic [5:0] trap_cause_mem;
    logic [5:0] trap_cause_clint;


    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // ALU.
    alu ALU0 (
        .alu_control_i (alu_control_i),
        .src_1_i       (alu_srcA     ),
        .src_2_i       (alu_srcB     ),
        .alu_result_o  (alu_result   ),
        .zero_flag_o   (zero_flag    ),
        .lt_flag_o     (lt_flag      ),
        .ltu_flag_o    (ltu_flag     )
    );

    mdu MDU0 (
        .clk_i            (clk_i           ),
        .arst_i           (arst_i          ),
        .start_i          (is_mdu_op_i     ),
        .is_mdu_word_op_i (is_mdu_word_op_i),
        .op_i             (func3_i         ),
        .a_i              (alu_srcA        ),
        .b_i              (forward_srcB    ),
        .c_o              (mdu_result      ),
        .busy_o           (mdu_busy_o      )
    );

    // Memory access exception detection module.
    mem_exc_detect MEM_EXC_DETECT (
        .mem_access_i  (mem_access_i         ),
        .load_instr_i  (load_instr_i         ),
        .access_type_i (func3_i[1:0]         ),
        .addr_offset_i (alu_result[2:0]      ),
        .exc_addr_ma_o (trap_detected_addr_ma),
        .trap_cause_o  (trap_cause_mem       )
    );

    // CSR file.
    csr_file CSR_FILE0 (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .write_en_i          (csr_we_wb_i        ),
        .write_data_i        (csr_write_data_i   ),
        .read_addr_i         (csr_read_addr_i    ),
        .write_addr_i        (csr_write_addr_i   ),
        .mepc_write_data_i   (mepc_write_data_i  ),
        .mcause_write_data_i (mcause_write_data_i),
        .trap_taken_i        (trap_taken_i       ),
        .trap_return_i       (trap_return_i      ),
        .mtime_val_i         (mtime_val_i        ),
        .timer_irq_i         (timer_irq_i        ),
        .software_irq_i      (software_irq_i     ),
        .csr_mtvec_read_o    (csr_mtvec_read_o   ),
        .csr_mepc_read_o     (csr_mepc_read_o    ),
        .iqr_detected_o      (trap_detected_clint),
        .trap_cause_o        (trap_cause_clint   ),
        .read_data_o         (csr_read_data      )
    );
    assign trap_detected_clint_valid = trap_detected_clint & log_trace_i;

    // Adder for target pc value calculation.
    adder ADD_IMM0 (
        .input1_i (pc_i       ),
        .input2_i (imm_ext_i  ),
        .sum_o    (pc_plus_imm)
    );

    // 3-to-1 ALU SrcA Forwarding MUX.
    mux3to1 MUX_FORWARD_A0 (
        .control_signal_i (forward_rs1_ex_i),
        .mux_0_i          (rs1_data_i      ),
        .mux_1_i          (result_i        ),
        .mux_2_i          (forward_value_i ),
        .mux_o            (forward_srcA    )
    );

    // 2-to-1 ALU SrcA data MUX.
    mux2to1 MUX_ALU_SRC_A0 (
        .control_signal_i (alu_srcA_i),
        .mux_0_i          (forward_srcA), // Forward out.
        .mux_1_i          (imm_ext_i   ), // Imm ext.
        .mux_o            (alu_srcA    )
    );

    // 3-to-1 ALU SrcB Forwarding MUX.
    mux3to1 MUX_FORWARD_B0 (
        .control_signal_i (forward_rs2_ex_i),
        .mux_0_i          (rs2_data_i      ),
        .mux_1_i          (result_i        ),
        .mux_2_i          (forward_value_i ),
        .mux_o            (forward_srcB    )
    );
    assign write_data = forward_srcB;

    // 3-to-1 ALU SrcB MUX.
    mux3to1 MUX_ALU_SRC_B0 (
        .control_signal_i (alu_srcB_i  ),
        .mux_0_i          (forward_srcB),
        .mux_1_i          (imm_ext_i   ),
        .mux_2_i          (csr_read_data), // CSR Read.
        .mux_o            (alu_srcB    )
    );

    // 2-to-1 PC target src MUX that chooses between PC_PLUS_IMM & RS1_PLUS_IMM.
    assign rs1_plus_imm = {alu_result[DATA_WIDTH - 1:1], 1'b0};
    mux2to1 MUX3 (
        .control_signal_i (pc_target_src_i),
        .mux_0_i          (pc_plus_imm    ),
        .mux_1_i          (rs1_plus_imm   ),
        .mux_o            (pc_target_addr )
    );

    // 2-to-1 MUX that chooses between PC target calculated & PC_PLUS4.
    mux2to1 MUX4 (
        .control_signal_i (branch_taken  ),
        .mux_0_i          (pc_plus4_i    ),
        .mux_1_i          (pc_target_addr),
        .mux_o            (pc_new        )
    );


    //--------------------------------------------------
    // Branch decision & misprediction detection logic.
    //--------------------------------------------------

    // Branch decision logic.
    always_comb begin
        case (func3_i)
            3'd0:    branch = branch_i & zero_flag;     // beq.
            3'd1:    branch = branch_i & (~ zero_flag); // bne.
            3'd4:    branch = branch_i & lt_flag;       // blt.
            3'd5:    branch = branch_i & (~ lt_flag);   // bge.
            3'd6:    branch = branch_i & ltu_flag;      // bltu.
            3'd7:    branch = branch_i & (~ ltu_flag);  // breu.
            default: branch = 1'b0;
        endcase
    end

    assign branch_taken      = jump_i | branch;
    assign branch_instr      = jump_i | branch_i;
    assign branch_taken_ex_o = branch_taken;
    assign branch_instr_ex_o = branch_instr;

    // Branch misprediction detection logic.
    assign branch_mispred_o = (branch_pred_taken_i ^ branch_taken) | (branch_pred_taken_i & (pc_target_addr_pred_i != pc_target_addr));


    //--------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------
    assign result_src_o     = result_src_i;
    assign mem_we_o         = mem_we_i & (~trap_detected_o);
    assign reg_we_o         = reg_we_i & (~trap_detected_o);
    assign csr_we_o         = csr_we_i & (~trap_detected_o);
    assign pc_plus4_o       = pc_plus4_i;
    assign pc_target_addr_o = pc_target_addr;
    assign imm_ext_o        = imm_ext_i;
    assign alu_result_o     = is_mdu_op_i ? mdu_result : alu_result;
    assign write_data_o     = write_data;
    assign forward_src_o    = forward_src_i;
    assign func3_o          = func3_i;
    assign mem_access_o     = mem_access_i & (~trap_detected_o);
    assign trap_detected_o  = trap_detected_i | trap_detected_addr_ma | trap_detected_clint_valid;
    // If already detected keep that, otherwise mem trap_cause (low priority).
    // async trap (interrupt) has the lowest priority.
    assign trap_cause_o     = trap_detected_i ? trap_cause_i : (trap_detected_addr_ma ? trap_cause_mem : trap_cause_clint);
    assign trap_return_o    = trap_return_i;
    assign rd_addr_o        = rd_addr_i;
    assign csr_write_addr_o = csr_read_addr_i;
    assign csr_read_data_o  = csr_read_data;
    assign pc_log_o         = pc_i;
    assign pc_new_o         = pc_new;
    assign rs1_addr_o       = rs1_addr_i;
    assign rs2_addr_o       = rs2_addr_i;
    assign btb_way_ex_o     = btb_way_i;
    assign pc_ex_o          = pc_i;
    assign load_instr_o     = load_instr_i;

    // Log trace.
    assign log_trace_o = log_trace_i;

endmodule
