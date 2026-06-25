/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 22/06/2026
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
    input  logic [DATA_WIDTH  - 1:0] rs2_data_i,
    input  logic                     atomic_lr_i,
    input  logic                     atomic_sc_i,
    input  logic                     atomic_aq_i,
    input  logic                     atomic_rl_i,
    input  logic                     atomic_amo_op_i,
    input  logic [              4:0] atomic_alu_op_i,
    input  logic                     trap_detected_i,
    input  logic [              5:0] trap_cause_i,
    input  logic                     trap_return_i,
    input  logic [REG_ADDR_W  - 1:0] rd_addr_i,
    input  logic                     mem_block_we_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,
    input  logic [ADDR_WIDTH  - 1:0] pc_log_i,
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
    output logic                     trap_detected_o,
    output logic [              5:0] trap_cause_o,
    output logic                     trap_return_o,
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
    output logic                     mmio_access_o,
    output logic                     mmio_access_type_o,
    output logic [DATA_WIDTH  - 1:0] mmio_wdata_o,
    output logic [              3:0] mmio_wstrb_o,
    output logic                     clint_access_o,
    output logic [DATA_WIDTH  - 1:0] mtime_val_o,
    output logic                     timer_irq_o,
    output logic                     software_irq_o,
    output logic                     log_trace_o
);
    //-------------------------------------------------------------
    // Localparams.
    //-------------------------------------------------------------
    /* verilator lint_off UNUSED */
    localparam logic [ADDR_WIDTH - 1:0] RAM_ADDR    = 64'h80000000;
    localparam logic [ADDR_WIDTH - 1:0] DEVICE_BASE = 64'ha0000000;
    localparam logic [ADDR_WIDTH - 1:0] CLINT_BASE  = 64'h02000000;
    localparam logic [ADDR_WIDTH - 1:0] CLINT_BOUND = 64'h020C0000;
    /* verilator lint_on UNUSED */


    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [DATA_WIDTH - 1:0] read_mem_cache;
    logic [DATA_WIDTH - 1:0] read_mem;
    logic [DATA_WIDTH - 1:0] wdata_cache;
    logic [DATA_WIDTH - 1:0] rdata_clint;
    logic [DATA_WIDTH - 1:0] read_data;

    logic mem_we;
    logic dcache_hit;
    logic reg_we;
    logic store_instr;

    logic [1:0] store_type;


    assign store_type = func3_i [1:0];

    // MMIO management.
    logic mmio_addr_space;
    logic mmio_access;

    logic        clint_addr_space;
    logic        clint_we;
    logic        clint_access;
    logic [15:0] clint_addr;

    logic       trap_detected_addr_ma;
    logic       trap_detected_access_fault;
    logic [5:0] trap_cause_addr_ma;
    logic [5:0] trap_cause_access_fault;

    logic [DATA_WIDTH - 1:0] amo_result;
    logic reserve_valid;


    //-------------------------------------
    // Continious assignments.
    //-------------------------------------
    assign mem_we   = (mem_we_i | atomic_amo_op_i) & (~mmio_access) & (~clint_access);
    assign clint_we = mem_we_i & clint_access;
    assign reg_we   = (reg_we_i & dcache_hit & mem_access_i) | (reg_we_i & (~ mem_access_i)) | (reg_we_i & (mmio_access | clint_access));

    assign store_instr = mem_we_i | atomic_amo_op_i;

    assign trap_detected_access_fault = (clint_access | mmio_access) & (atomic_lr_i | atomic_sc_i | atomic_amo_op_i);
    assign trap_cause_access_fault = atomic_sc_i ? 6'd7 : 6'd5;

    assign wdata_cache = atomic_amo_op_i ? amo_result : (atomic_sc_i ? rs2_data_i : write_data_i);


    //-------------------------------------------------------------
    // MMIO access.
    //-------------------------------------------------------------
    assign mmio_addr_space    = (alu_result_i >= DEVICE_BASE);
    assign clint_addr_space   = (alu_result_i >= CLINT_BASE) & (alu_result_i < CLINT_BOUND);
    assign mmio_access        = mem_access_i && (mmio_addr_space);
    assign clint_access       = mem_access_i && (clint_addr_space);
    assign mmio_access_type_o = mem_we_i; // 0 - read, 1 - write;
    assign mmio_access_o      = mmio_access;
    assign clint_access_o     = clint_access;

    assign clint_addr = alu_result_i[15:0];

    always_comb begin
        // Default value.
        mmio_wstrb_o = 4'b0;
        mmio_wdata_o = '0;

        case (func3_i[1:0])
            2'b00: begin // Byte access.
                mmio_wstrb_o = 4'b0001 << alu_result_i[1:0];
                mmio_wdata_o = {56'b0, write_data_i[7:0]} << alu_result_i[1:0];
            end
            2'b01: begin // Half-word access.
                mmio_wstrb_o = 4'b0011 << alu_result_i[1];
                mmio_wdata_o = {48'b0, write_data_i[15:0]} << alu_result_i[1];
            end
            2'b10: begin // Word accesss.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = write_data_i;
            end
            2'b11: begin // Double-word access: treated as word access.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = write_data_i;
            end
            default: begin
                mmio_wstrb_o = 4'b0;
                mmio_wdata_o = '0;
            end
        endcase
    end


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
        .write_data_i    (wdata_cache   ),
        .atomic_lr_i     (atomic_lr_i   ),
        .atomic_sc_i     (atomic_sc_i   ),
        .hit_o           (dcache_hit    ),
        .dirty_o         (dcache_dirty_o),
        .reserve_valid_o (reserve_valid ),
        .addr_wb_o       (axi_addr_wb_o ),
        .data_block_o    (data_block_o  ),
        .read_data_o     (read_mem_cache)
    );

    // CLINT.
    clint CLINT_MMIO_0 (
        .clk_i          (clk_i         ),
        .arst_i         (arst_i        ),
        .write_en_i     (clint_we      ),
        .addr_i         (clint_addr    ),
        .wdata_i        (write_data_i  ),
        .rdata_o        (rdata_clint   ),
        .mtime_val_o    (mtime_val_o   ),
        .timer_irq_o    (timer_irq_o   ),
        .software_irq_o (software_irq_o)
    );

    amo_alu AMO_ALU_0 (
        .amo_op_i     (atomic_alu_op_i),
        .mem_rdata_i  (read_data      ),
        .rs2_i        (rs2_data_i     ),
        .amo_result_o (amo_result     )
    );

    // Memory access addr ma exception detection module.
    mem_exc_detect MEM_EXC_DETECT (
        .mem_access_i  (mem_access_i         ),
        .store_instr_i (store_instr          ),
        .access_type_i (func3_i[1:0]         ),
        .addr_offset_i (alu_result_i[2:0]    ),
        .exc_addr_ma_o (trap_detected_addr_ma),
        .trap_cause_o  (trap_cause_addr_ma   )
    );

    // MUX for choosing mem read data source.
    mux3to1 MUX1 (
        .control_signal_i ({clint_access, mmio_access}),
        .mux_0_i          (read_mem_cache             ),
        .mux_1_i          (mmio_rdata_i               ),
        .mux_2_i          (rdata_clint                ),
        .mux_o            (read_mem                   )
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
    assign trap_detected_o  = trap_detected_i | trap_detected_access_fault | trap_detected_addr_ma;
    assign trap_cause_o     = trap_detected_i ? trap_cause_i : (trap_detected_access_fault ? trap_cause_access_fault : trap_cause_addr_ma); // addr ma has lowest priority.
    assign trap_return_o    = trap_return_i;
    assign rd_addr_o        = rd_addr_i;
    assign dcache_hit_o     = dcache_hit;

    // Log trace.
    assign pc_log_o         = pc_log_i;
    assign mem_addr_log_o   = alu_result_i;
    assign mem_we_log_o     = mem_we | (atomic_sc_i & reserve_valid);
    assign mem_access_log_o = mem_access_i & (~atomic_sc_i | (atomic_sc_i & reserve_valid));
    assign log_trace_o      = log_trace_i & ((mem_access_i & dcache_hit) | (~mem_access_i) | (mmio_access) | clint_access);

    always_comb begin
        case (store_type)
            2'b11: mem_write_data_log_o = wdata_cache;                // SD.
            2'b10: mem_write_data_log_o = {32'b0, wdata_cache[31:0]}; // SW.
            2'b01: mem_write_data_log_o = {48'b0, wdata_cache[15:0]}; // SH.
            2'b00: mem_write_data_log_o = {56'b0, wdata_cache[ 7:0]}; // SB.
        endcase
    end

endmodule
