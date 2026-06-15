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
    input  logic                     exc_detected_i,
    input  logic [              4:0] exc_cause_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic                     mem_block_we_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
    input  logic                     mmio_access_i,
    input  logic [DATA_WIDTH  - 1:0] mmio_rdata_i,
    input  logic                     log_trace_i,

    // Output interface.
    output logic [              2:0] result_src_o,
    output logic                     reg_we_o,
    output logic [ADDR_WIDTH  - 1:0] pc_plus4_o,
    output logic [ADDR_WIDTH  - 1:0] pc_target_addr_o,
    output logic [DATA_WIDTH  - 1:0] imm_ext_o,
    output logic [DATA_WIDTH  - 1:0] alu_result_o,
    output logic [DATA_WIDTH  - 1:0] read_data_o,
    output logic                     exc_detected_o,
    output logic [              4:0] exc_cause_o,
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
    logic [DATA_WIDTH - 1:0] read_mem_cache;
    logic [DATA_WIDTH - 1:0] read_mem;
    logic [DATA_WIDTH - 1:0] read_data;

    logic mem_we = mem_we_i && (~mmio_access_i);
    logic dcache_hit;
    logic reg_we;

    logic [1:0] store_type;

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
        .write_en_i      (mem_we        ),
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
        .read_data_o     (read_mem_cache)
    );

    // MUX for choosing mem read data source.
    mux2to1 MUX1 (
        .control_signal_i (mmio_access_i ),
        .mux_0_i          (read_mem_cache),
        .mux_1_i          (mmio_rdata_i  ),
        .mux_o            (read_mem      )
    );

    // Load MUX.
    load_mux LMUX0 (
        .func3_i        (func3_i           ),
        .data_i         (read_mem          ),
        .addr_offset_i  (alu_result_i [2:0]),
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
    assign exc_detected_o   = exc_detected_i;
    assign exc_cause_o      = exc_cause_i;
    assign rd_addr_o        = rd_addr_i;
    assign dcache_hit_o     = dcache_hit;

    // Log trace.
    assign pc_log_o         = pc_log_i;
    assign mem_addr_log_o   = alu_result_i;
    assign mem_we_log_o     = mem_we_i;
    assign mem_access_log_o = mem_access_i;
    assign log_trace_o      = log_trace_i & ((mem_access_i & dcache_hit) | (~mem_access_i) | (mmio_access_i));

    always_comb begin
        case (store_type)
            2'b11: mem_write_data_log_o = write_data_i;                // SD.
            2'b10: mem_write_data_log_o = {32'b0, write_data_i[31:0]}; // SW.
            2'b01: mem_write_data_log_o = {48'b0, write_data_i[15:0]}; // SH.
            2'b00: mem_write_data_log_o = {56'b0, write_data_i[ 7:0]}; // SB.
        endcase
    end

endmodule
