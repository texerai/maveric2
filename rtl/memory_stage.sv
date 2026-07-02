/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 30/06/2026
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the memory stage.
// ----------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"

module memory_stage
// Parameters.
#(
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        stall_mem_i,
    input  pipeline_stage_pkg::ex_mem_t ex_mem_i,
    input  logic                        mem_block_we_i,
    input  logic [BLOCK_WIDTH - 1:0]    data_block_i,
    input  logic [DATA_WIDTH  - 1:0]    mmio_rdata_i,
    input  logic                        fencei_wb_done_i,

    // Output interface.
    output pipeline_stage_pkg::mem_wb_t mem_wb_o,
    output logic [DATA_WIDTH     - 1:0] forward_value_o,
    output logic                        dcache_hit_o,
    output logic                        dcache_dirty_o,
    output logic                        fencei_wb_start_o,
    output logic [ADDR_WIDTH     - 1:0] axi_addr_wb_o,
    output logic [BLOCK_WIDTH    - 1:0] data_block_o,
    output logic                        mmio_access_o,
    output logic                        mmio_access_type_o,
    output logic [DATA_WIDTH     - 1:0] mmio_wdata_o,
    output logic [                 3:0] mmio_wstrb_o,
    output logic                        clint_access_o,
    output logic [DATA_WIDTH     - 1:0] mtime_val_o,
    output logic                        timer_irq_o,
    output logic                        software_irq_o
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
    logic [DATA_WIDTH - 1:0] rdata_mem_cache;
    logic [DATA_WIDTH - 1:0] rdata_mem;
    logic [DATA_WIDTH - 1:0] wdata_cache;
    logic [DATA_WIDTH - 1:0] rdata_clint;
    logic [DATA_WIDTH - 1:0] rdata;

    logic mem_we;
    logic dcache_hit;
    logic reg_we;
    logic store_instr;

    logic [1:0] store_type;

    logic trap_detected;


    assign store_type = ex_mem_i.func3[1:0];

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
    assign mem_we   = (ex_mem_i.mem_we | ex_mem_i.atomic_amo_op) & (~mmio_access) & (~clint_access) & (~stall_mem_i) & (~trap_detected);
    assign clint_we = ex_mem_i.mem_we & clint_access & (~trap_detected);
    assign reg_we   = (ex_mem_i.reg_we & dcache_hit & ex_mem_i.mem_access) | (ex_mem_i.reg_we & (~ ex_mem_i.mem_access)) | (ex_mem_i.reg_we & (mmio_access | clint_access)) & (~trap_detected);

    assign store_instr = ex_mem_i.mem_we | ex_mem_i.atomic_amo_op;

    assign trap_detected_access_fault = (clint_access | mmio_access) & (ex_mem_i.atomic_lr | ex_mem_i.atomic_sc | ex_mem_i.atomic_amo_op);
    assign trap_cause_access_fault = ex_mem_i.atomic_sc ? 6'd7 : 6'd5;

    assign wdata_cache = ex_mem_i.atomic_amo_op ? amo_result : (ex_mem_i.atomic_sc ? ex_mem_i.rs2_data : ex_mem_i.wdata);


    //-------------------------------------------------------------
    // MMIO access.
    //-------------------------------------------------------------
    assign mmio_addr_space    = (ex_mem_i.alu_result >= DEVICE_BASE);
    assign clint_addr_space   = (ex_mem_i.alu_result >= CLINT_BASE) & (ex_mem_i.alu_result < CLINT_BOUND);
    assign mmio_access        = ex_mem_i.mem_access && (mmio_addr_space);
    assign clint_access       = ex_mem_i.mem_access && (clint_addr_space);
    assign mmio_access_type_o = ex_mem_i.mem_we; // 0 - read, 1 - write;
    assign mmio_access_o      = mmio_access;
    assign clint_access_o     = clint_access;

    assign clint_addr = ex_mem_i.alu_result[15:0];

    always_comb begin
        // Default value.
        mmio_wstrb_o = 4'b0;
        mmio_wdata_o = '0;

        case (ex_mem_i.func3[1:0])
            2'b00: begin // Byte access.
                mmio_wstrb_o = 4'b0001 << ex_mem_i.alu_result[1:0];
                mmio_wdata_o = {56'b0, ex_mem_i.wdata[7:0]} << ex_mem_i.alu_result[1:0];
            end
            2'b01: begin // Half-word access.
                mmio_wstrb_o = 4'b0011 << ex_mem_i.alu_result[1];
                mmio_wdata_o = {48'b0, ex_mem_i.wdata[15:0]} << ex_mem_i.alu_result[1];
            end
            2'b10: begin // Word accesss.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = ex_mem_i.wdata;
            end
            2'b11: begin // Double-word access: treated as word access.
                mmio_wstrb_o = 4'b1111;
                mmio_wdata_o = ex_mem_i.wdata;
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
        .clk_i             (clk_i              ),
        .arst_i            (arst_i             ),
        .we_i              (mem_we             ),
        .block_we_i        (mem_block_we_i     ),
        .mem_access_i      (ex_mem_i.mem_access),
        .store_type_i      (store_type         ),
        .addr_i            (ex_mem_i.alu_result),
        .data_block_i      (data_block_i       ),
        .wdata_i           (wdata_cache        ),
        .atomic_lr_i       (ex_mem_i.atomic_lr ),
        .atomic_sc_i       (ex_mem_i.atomic_sc ),
        .fencei_i          (ex_mem_i.fencei    ),
        .fencei_wb_done_i  (fencei_wb_done_i   ),
        .hit_o             (dcache_hit         ),
        .dirty_o           (dcache_dirty_o     ),
        .fencei_wb_start_o (fencei_wb_start_o  ),
        .reserve_valid_o   (reserve_valid      ),
        .addr_wb_o         (axi_addr_wb_o      ),
        .data_block_o      (data_block_o       ),
        .rdata_o           (rdata_mem_cache    )
    );

    // CLINT.
    clint CLINT_MMIO_0 (
        .clk_i          (clk_i              ),
        .arst_i         (arst_i             ),
        .we_i           (clint_we           ),
        .addr_i         (clint_addr         ),
        .wdata_i        (ex_mem_i.wdata     ),
        .rdata_o        (rdata_clint        ),
        .mtime_val_o    (mtime_val_o        ),
        .timer_irq_o    (timer_irq_o        ),
        .software_irq_o (software_irq_o     )
    );

    amo_alu AMO_ALU_0 (
        .amo_op_i     (ex_mem_i.atomic_alu_op),
        .mem_rdata_i  (rdata                 ),
        .rs2_i        (ex_mem_i.rs2_data     ),
        .amo_result_o (amo_result            )
    );

    // Memory access addr ma exception detection module.
    mem_exc_detect MEM_EXC_DETECT (
        .mem_access_i  (ex_mem_i.mem_access     ),
        .store_instr_i (store_instr             ),
        .access_type_i (ex_mem_i.func3[1:0]     ),
        .addr_offset_i (ex_mem_i.alu_result[2:0]),
        .exc_addr_ma_o (trap_detected_addr_ma   ),
        .trap_cause_o  (trap_cause_addr_ma      )
    );

    // MUX for choosing mem read data source.
    mux3to1 MUX1 (
        .control_signal_i ({clint_access, mmio_access}),
        .mux_0_i          (rdata_mem_cache            ),
        .mux_1_i          (mmio_rdata_i               ),
        .mux_2_i          (rdata_clint                ),
        .mux_o            (rdata_mem                  )
    );

    // Load MUX.
    load_mux LMUX0 (
        .func3_i        (ex_mem_i.func3          ),
        .data_i         (rdata_mem               ),
        .addr_offset_i  (ex_mem_i.alu_result[2:0]),
        .data_o         (rdata                   )
    );

    // Forwarding value MUX.
    mux3to1 MUX0 (
        .control_signal_i (ex_mem_i.forward_src   ),
        .mux_0_i          (ex_mem_i.alu_result    ),
        .mux_1_i          (ex_mem_i.pc_target_addr),
        .mux_2_i          (ex_mem_i.imm_ext       ),
        .mux_o            (forward_value_o        )
    );

    //--------------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------------
    assign trap_detected = ex_mem_i.trap_detected | trap_detected_access_fault | trap_detected_addr_ma;

    assign mem_wb_o.result_src      = ex_mem_i.result_src;
    assign mem_wb_o.reg_we          = reg_we;
    assign mem_wb_o.csr_we          = ex_mem_i.csr_we & (~trap_detected);
    assign mem_wb_o.pc_plus4        = ex_mem_i.pc_plus4;
    assign mem_wb_o.pc_target_addr  = ex_mem_i.pc_target_addr;
    assign mem_wb_o.imm_ext         = ex_mem_i.imm_ext;
    assign mem_wb_o.alu_result      = ex_mem_i.alu_result;
    assign mem_wb_o.rdata           = rdata;
    assign mem_wb_o.trap_detected   = trap_detected;
    assign mem_wb_o.trap_cause      = ex_mem_i.trap_detected ? ex_mem_i.trap_cause : (trap_detected_access_fault ? trap_cause_access_fault : trap_cause_addr_ma); // addr ma has lowest priority.
    assign mem_wb_o.trap_mret       = ex_mem_i.trap_mret;
    assign mem_wb_o.trap_sret       = ex_mem_i.trap_sret;
    assign mem_wb_o.rd_addr         = ex_mem_i.rd_addr;
    assign mem_wb_o.csr_waddr       = ex_mem_i.csr_waddr;
    assign mem_wb_o.csr_rdata       = ex_mem_i.csr_rdata;
    assign mem_wb_o.instruction_log = ex_mem_i.instruction_log;
    assign dcache_hit_o             = dcache_hit;

    // Log trace.
    assign mem_wb_o.pc_log         = ex_mem_i.pc_log;
    assign mem_wb_o.mem_addr_log   = ex_mem_i.alu_result;
    assign mem_wb_o.mem_we_log     = mem_we | ex_mem_i.mem_we | (ex_mem_i.atomic_sc & reserve_valid) & (~trap_detected);
    assign mem_wb_o.mem_access_log = ex_mem_i.mem_access & (~ex_mem_i.atomic_sc | (ex_mem_i.atomic_sc & reserve_valid));
    assign mem_wb_o.log_trace      = ex_mem_i.log_trace & ((ex_mem_i.mem_access & dcache_hit) | (~ex_mem_i.mem_access) | (mmio_access) | clint_access);

    always_comb begin
        case (store_type)
            2'b11: mem_wb_o.mem_wdata_log = wdata_cache;                // SD.
            2'b10: mem_wb_o.mem_wdata_log = {32'b0, wdata_cache[31:0]}; // SW.
            2'b01: mem_wb_o.mem_wdata_log = {48'b0, wdata_cache[15:0]}; // SH.
            2'b00: mem_wb_o.mem_wdata_log = {56'b0, wdata_cache[ 7:0]}; // SB.
        endcase
    end

endmodule
