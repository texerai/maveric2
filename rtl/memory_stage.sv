/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 04/06/2025
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the memory stage.
// ----------------------------------------------------------------------------------------

module memory_stage
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter BLOCK_WIDTH = 512,
    parameter REG_ADDR_W  = 5
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic [              2:0] result_src_i,
    input  logic                     mem_we_i,
    input  logic                     reg_we_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_plus4_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_target_addr_i,
    input  logic [DATA_WIDTH  - 1:0] imm_ext_i,
    input  logic [DATA_WIDTH  - 1:0] alu_result_i,
    input  logic [DATA_WIDTH  - 1:0] write_data_i,
    input  logic [              1:0] forward_src_i,
    input  logic [              2:0] func3_i,
    input  logic                     mem_access_i,
    input  logic                     ecall_instr_i,
    input  logic [              3:0] cause_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic                     mem_block_we_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
    input  logic                     log_trace_i,

    // Output interface.
    output logic [              2:0] result_src_o,
    output logic                     reg_we_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [DATA_WIDTH  - 1:0] alu_result_o,
    output logic [DATA_WIDTH  - 1:0] read_data_o,
    output logic                     ecall_instr_o,
    output logic [              3:0] cause_o,
    output logic [REG_ADDR_W  - 1:0] rd_addr_o,
    output logic [DATA_WIDTH  - 1:0] forward_value_o,
    output logic                     dcache_hit_o,
    output logic                     dcache_dirty_o,
    output logic [ADDR_WIDTH  - 1:0] axi_addr_wb_o,
    output logic [BLOCK_WIDTH - 1:0] data_block_o,
    output logic [ADDR_WIDTH  - 1:0] pc_log_o,
    output logic [ADDR_WIDTH  - 1:0] mem_addr_log_o,
    output logic [DATA_WIDTH  - 1:0] mem_write_data_log_o,
    output logic                     mem_we_log_o,
    output logic                     mem_access_log_o,
    output logic                     log_trace_o
);

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [DATA_WIDTH - 1:0] read_mem;
    logic [DATA_WIDTH - 1:0] read_data;

    logic dcache_hit;
    logic reg_we;

    logic       load_addr_ma;
    logic [3:0] cause;
    logic       call_load_addr_ma;
    logic       ecall_instr;

    logic       store_addr_ma;
    logic [1:0] store_type;

    assign call_load_addr_ma = mem_access_i & load_addr_ma;
    assign ecall_instr       = ecall_instr_i | call_load_addr_ma | store_addr_ma;
    assign cause             = (ecall_instr_i) ? cause_i : (store_addr_ma) ? 4'd6 : 4'd4; // 6: Store addr misaligned, 4: Load address misaligned.

    assign reg_we = (reg_we_i & dcache_hit & mem_access_i) | (reg_we_i & (~ mem_access_i));

    assign store_type = func3_i [1:0];

    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Data memory.
    dcache # (
        .SET_WIDTH (BLOCK_WIDTH)
    ) DATA_CACHE (
        .clk_i           (clk_i         ),
        .arst_i          (arst_i        ),
        .write_en_i      (mem_we_i      ),
        .block_we_i      (mem_block_we_i),
        .mem_access_i    (mem_access_i  ),
        .store_type_i    (store_type    ),
        .addr_i          (alu_result_i  ),
        .data_block_i    (data_block_i  ),
        .write_data_i    (write_data_i  ),
        .hit_o           (dcache_hit    ),
        .dirty_o         (dcache_dirty_o),
        .addr_wb_o       (axi_addr_wb_o ),
        .data_block_o    (data_block_o  ),
        .store_addr_ma_o (store_addr_ma ),
        .read_data_o     (read_mem      )
    );

    // Load MUX.
    load_mux LMUX0 (
        .func3_i        (func3_i           ),
        .data_i         (read_mem          ),
        .addr_offset_i  (alu_result_i [2:0]),
        .load_addr_ma_o (load_addr_ma      ),
        .data_o         (read_data         )
    );

    // Forwarding value MUX.
    mux3to1 MUX0 (
        .control_signal_i (forward_src_i   ),
        .mux_0_i          (alu_result_i    ),
        .mux_1_i          (pc_target_addr_i),
        .mux_2_i          (imm_ext_i       ),
        .mux_o            (forward_value_o )
    );

    //--------------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------------
    assign result_src_o     = result_src_i;
    assign reg_we_o         = reg_we;
    assign pc_plus4_o       = pc_plus4_i;
    assign pc_target_addr_o = pc_target_addr_i;
    assign imm_ext_o        = imm_ext_i;
    assign alu_result_o     = alu_result_i;
    assign read_data_o      = read_data;
    assign ecall_instr_o    = ecall_instr;
    assign cause_o          = cause;
    assign rd_addr_o        = rd_addr_i;
    assign dcache_hit_o     = dcache_hit;

    // Log trace.
    assign pc_log_o         = pc_log_i;
    assign mem_addr_log_o   = alu_result_i;
    assign mem_we_log_o     = mem_we_i;
    assign mem_access_log_o = mem_access_i;
    assign log_trace_o      = log_trace_i & ((mem_access_i & dcache_hit) | (~mem_access_i));

    always_comb begin
        case (store_type)
            2'b11: mem_write_data_log_o = write_data_i;                // SD.
            2'b10: mem_write_data_log_o = {32'b0, write_data_i[31:0]}; // SW.
            2'b01: mem_write_data_log_o = {48'b0, write_data_i[15:0]}; // SH.
            2'b00: mem_write_data_log_o = {56'b0, write_data_i[ 7:0]}; // SB.
        endcase
    end

endmodule
