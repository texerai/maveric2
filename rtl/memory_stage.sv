/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 14/07/2026
//------------------------------

// ----------------------------------------------------------------------------------------
// This module contains instantiation of all functional units residing in the memory stage.
// ----------------------------------------------------------------------------------------

`include "pipeline_stage_pkg.sv"
`include "maveric_pkg.sv"

module memory_stage
// Parameters.
#(
    parameter XLEN        = maveric_pkg::XLEN,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic                        stall_mem_i,
    input  logic                        va_enabled_i,
    input  logic [                 1:0] priv_mode_i,
    input  logic                        mstatus_mxr_i,
    input  logic                        mstatus_sum_i,
    input  pipeline_stage_pkg::ex_mem_t ex_mem_i,
    input  logic                        mem_block_we_i,
    input  logic [BLOCK_WIDTH    - 1:0] data_block_i,
    input  logic [XLEN           - 1:0] mmio_rdata_i,
    input  logic                        fencei_wb_done_i,
    input  logic                        dtlb_we_i,
    input  logic [                15:0] satp_asid_i,
    input  logic [                45:0] dtlb_wtag_i,
    input  logic [                49:0] dtlb_wdata_i,
    input  logic [XLEN           - 1:0] mmu_dcache_addr_i,
    input  logic [XLEN           - 1:0] mmu_dcache_wdata_i,
    input  logic                        mmu_dcache_we_i,
    input  logic                        mmu_dcache_access_i,
    input  logic                        trap_detected_mmu_i,
    input  logic [                 5:0] trap_cause_mmu_i,
    input  logic                        sfence_i,
    input  csr_pkg::pmp_t               pmp_data_i,

    // Output interface.
    output pipeline_stage_pkg::mem_wb_t mem_wb_o,
    output logic [XLEN           - 1:0] forward_value_o,
    output logic                        dcache_hit_o,
    output logic                        dcache_dirty_o,
    output logic                        fencei_wb_start_o,
    output logic [XLEN           - 1:0] axi_raddr_data_o,
    output logic [XLEN           - 1:0] axi_addr_wb_o,
    output logic [BLOCK_WIDTH    - 1:0] data_block_o,
    output logic                        mmio_access_o,
    output logic                        mmio_access_type_o,
    output logic [XLEN           - 1:0] mmio_wdata_o,
    output logic [                 3:0] mmio_wstrb_o,
    output logic                        clint_access_o,
    output logic [XLEN           - 1:0] mtime_val_o,
    output logic                        timer_irq_o,
    output logic [XLEN           - 1:0] rdata_mem_dcache_o,
    output logic                        dtlb_hit_o,
    output logic                        trap_pmp_o,
    output logic                        software_irq_o
);
    //-------------------------------------------------------------
    // Localparams.
    //-------------------------------------------------------------
    /* verilator lint_off UNUSED */
    localparam logic [XLEN       - 1:0] RAM_ADDR    = 64'h80000000;
    localparam logic [XLEN       - 1:0] DEVICE_BASE = 64'ha0000000;
    localparam logic [XLEN       - 1:0] CLINT_BASE  = 64'h02000000;
    localparam logic [XLEN       - 1:0] CLINT_BOUND = 64'h020C0000;
    /* verilator lint_on UNUSED */


    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [XLEN       - 1:0] rdata_mem_cache;
    logic [XLEN       - 1:0] rdata_mem;
    logic [XLEN       - 1:0] wdata_cache;
    logic [XLEN       - 1:0] wdata_dcache;
    logic [XLEN       - 1:0] rdata_clint;
    logic [XLEN       - 1:0] rdata;

    // VA.
    logic [XLEN - 1:0] mem_addr;
    logic [XLEN - 1:0] dcache_addr;
    logic [XLEN - 1:0] mem_addr_pa;

    logic mem_we;
    logic dcache_we;
    logic dcache_mem_access;
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
    logic       trap_dtlb;
    logic       trap_dtlb_valid;
    logic       trap_pmp;
    logic       trap_pmp_valid;
    logic [5:0] trap_cause_addr_ma;
    logic [5:0] trap_cause_access_fault;
    logic [5:0] trap_cause;

    logic [XLEN       - 1:0] amo_result;
    logic reserve_valid;


    //-------------------------------------
    // Continious assignments.
    //-------------------------------------
    assign mem_we    = (ex_mem_i.mem_we) && (!stall_mem_i) && (!trap_detected);
    assign dcache_we = (mem_we & (~mmio_access) & (~clint_access)) || mmu_dcache_we_i;
    assign clint_we  = mem_we & clint_access;
    assign reg_we    = ((ex_mem_i.reg_we && dcache_hit && ex_mem_i.mem_access) || (ex_mem_i.reg_we && ((!ex_mem_i.mem_access) || mmio_access || clint_access))) & (!trap_detected);

    assign store_instr       = ex_mem_i.mem_we;
    assign dcache_mem_access = ex_mem_i.mem_access | mmu_dcache_access_i;

    assign trap_detected_access_fault = (clint_access | mmio_access) & (ex_mem_i.atomic_lr | ex_mem_i.atomic_sc | ex_mem_i.atomic_amo_op);
    assign trap_cause_access_fault = ex_mem_i.atomic_sc ? csr_pkg::EXC_STORE_ACCESS_FAULT : csr_pkg::EXC_LOAD_ACCESS_FAULT;

    assign wdata_cache = ex_mem_i.atomic_amo_op ? amo_result : (ex_mem_i.atomic_sc ? ex_mem_i.rs2_data : ex_mem_i.wdata);


    //-------------------------------------------------------------
    // MMIO access.
    //-------------------------------------------------------------
    assign mmio_addr_space    = (dcache_addr >= DEVICE_BASE);
    assign clint_addr_space   = (dcache_addr >= CLINT_BASE) & (dcache_addr < CLINT_BOUND);
    assign mmio_access        = ex_mem_i.mem_access && (mmio_addr_space)  && (va_enabled_i ? (dtlb_hit_o) : 1'b1);
    assign clint_access       = ex_mem_i.mem_access && (clint_addr_space) && (va_enabled_i ? (dtlb_hit_o) : 1'b1);
    assign mmio_access_type_o = ex_mem_i.mem_we; // 0 - read, 1 - write;
    assign mmio_access_o      = mmio_access;
    assign clint_access_o     = clint_access;

    assign clint_addr = dcache_addr[15:0];

    always_comb begin
        // Default value.
        mmio_wstrb_o = 4'b0;
        mmio_wdata_o = '0;

        case (ex_mem_i.func3[1:0])
            2'b00: begin // Byte access.
                mmio_wstrb_o = 4'b0001 << dcache_addr[1:0];
                mmio_wdata_o = {56'b0, ex_mem_i.wdata[7:0]} << dcache_addr[1:0];
            end
            2'b01: begin // Half-word access.
                mmio_wstrb_o = 4'b0011 << dcache_addr[1];
                mmio_wdata_o = {48'b0, ex_mem_i.wdata[15:0]} << dcache_addr[1];
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

    // DTLB module.
    dtlb DLTB0 (
        .clk_i         (clk_i              ),
        .arst_i        (arst_i             ),
        .priv_mode_i   (priv_mode_i        ),
        .invalidate_i  (sfence_i           ),
        .mem_store_i   (store_instr        ),
        .access_i      (ex_mem_i.mem_access),
        .tlb_we_i      (dtlb_we_i          ),
        .satp_asid_i   (satp_asid_i        ),
        .va_i          (ex_mem_i.alu_result),
        .tlb_wtag_i    (dtlb_wtag_i        ),
        .tlb_wdata_i   (dtlb_wdata_i       ),
        .mstatus_mxr_i (mstatus_mxr_i      ),
        .mstatus_sum_i (mstatus_sum_i      ),
        .trap_o        (trap_dtlb          ),
        .pa_o          (mem_addr_pa        ),
        .hit_o         (dtlb_hit_o         )
    );

    assign trap_dtlb_valid = trap_dtlb && dtlb_hit_o && va_enabled_i && ex_mem_i.mem_access;


    // Mux for VA and PA.
    mux2to1 MUX2 (
        .control_signal_i (va_enabled_i       ),
        .mux_0_i          (ex_mem_i.alu_result),
        .mux_1_i          (mem_addr_pa        ),
        .mux_o            (mem_addr           )
    );

    always_comb begin
        if (mmu_dcache_access_i) begin
            dcache_addr  = mmu_dcache_addr_i;
            wdata_dcache = mmu_dcache_wdata_i;
        end else begin
            dcache_addr  = mem_addr;
            wdata_dcache = wdata_cache;
        end
    end

    pmp_check_lsu PMP_CHECK (
        .addr_i       (dcache_addr      ),
        .pmp_data_i   (pmp_data_i       ),
        .priv_mode_i  (priv_mode_i      ),
        .mem_access_i (dcache_mem_access),
        .mem_store_i  (store_instr      ),
        .ls_type      (store_type       ),
        .trap_o       (trap_pmp         )
    );

    assign trap_pmp_valid = trap_pmp && ((!va_enabled_i) || (dtlb_hit_o && va_enabled_i));
    assign trap_pmp_o     = trap_pmp && mmu_dcache_access_i;

    // Data memory.
    dcache # (
        .SET_WIDTH (BLOCK_WIDTH)
    ) DATA_CACHE (
        .clk_i             (clk_i             ),
        .arst_i            (arst_i            ),
        .we_i              (dcache_we         ),
        .block_we_i        (mem_block_we_i    ),
        .mem_access_i      (dcache_mem_access ),
        .store_type_i      (store_type        ),
        .addr_i            (dcache_addr       ),
        .data_block_i      (data_block_i      ),
        .wdata_i           (wdata_dcache      ),
        .atomic_lr_i       (ex_mem_i.atomic_lr),
        .atomic_sc_i       (ex_mem_i.atomic_sc),
        .fencei_i          (ex_mem_i.fencei   ),
        .fencei_wb_done_i  (fencei_wb_done_i  ),
        .hit_o             (dcache_hit        ),
        .dirty_o           (dcache_dirty_o    ),
        .fencei_wb_start_o (fencei_wb_start_o ),
        .reserve_valid_o   (reserve_valid     ),
        .addr_wb_o         (axi_addr_wb_o     ),
        .data_block_o      (data_block_o      ),
        .rdata_o           (rdata_mem_cache   )
    );

    // CLINT.
    clint CLINT_MMIO_0 (
        .clk_i          (clk_i         ),
        .arst_i         (arst_i        ),
        .we_i           (clint_we      ),
        .addr_i         (clint_addr    ),
        .wdata_i        (ex_mem_i.wdata),
        .rdata_o        (rdata_clint   ),
        .mtime_val_o    (mtime_val_o   ),
        .timer_irq_o    (timer_irq_o   ),
        .software_irq_o (software_irq_o)
    );

    amo_alu AMO_ALU_0 (
        .amo_op_i     (ex_mem_i.atomic_alu_op),
        .mem_rdata_i  (rdata                 ),
        .rs2_i        (ex_mem_i.rs2_data     ),
        .amo_result_o (amo_result            )
    );

    // Memory access addr ma exception detection module.
    mem_exc_detect MEM_EXC_DETECT (
        .mem_access_i  (ex_mem_i.mem_access  ),
        .store_instr_i (store_instr          ),
        .access_type_i (ex_mem_i.func3[1:0]  ),
        .addr_offset_i (mem_addr[2:0]        ),
        .exc_addr_ma_o (trap_detected_addr_ma),
        .trap_cause_o  (trap_cause_addr_ma   )
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
        .func3_i        (ex_mem_i.func3),
        .data_i         (rdata_mem     ),
        .addr_offset_i  (mem_addr[2:0] ),
        .data_o         (rdata         )
    );

    // Forwarding value MUX.
    logic [1:0] forward_src;
    assign forward_src = (ex_mem_i.result_src == 3'b010) ? 2'b11 : ex_mem_i.forward_src;
    // mux4to1 MUX0 (
    //     .control_signal_i (forward_src            ),
    //     .mux_0_i          (ex_mem_i.alu_result    ),
    //     .mux_1_i          (ex_mem_i.pc_target_addr),
    //     .mux_2_i          (ex_mem_i.imm_ext       ),
    //     .mux_3_i          (ex_mem_i.pc_plus4      ),
    //     .mux_o            (forward_value_o        )
    // );
    always_comb begin
        case (forward_src)
            2'b00: forward_value_o = ex_mem_i.alu_result;
            2'b01: forward_value_o = ex_mem_i.pc_target_addr;
            2'b10: forward_value_o = ex_mem_i.imm_ext;
            2'b11: forward_value_o = ex_mem_i.pc_plus4;
            default: forward_value_o = '0;
        endcase
    end

    //--------------------------------------------
    // Continious assignment of outputs.
    //--------------------------------------------
    assign trap_detected = ex_mem_i.trap_detected || trap_detected_access_fault || trap_detected_addr_ma || trap_detected_mmu_i || trap_dtlb_valid || trap_pmp_valid;

    assign mem_wb_o.result_src      = ex_mem_i.result_src;
    assign mem_wb_o.reg_we          = reg_we;
    assign mem_wb_o.csr_we          = ex_mem_i.csr_we & (~trap_detected);
    assign mem_wb_o.pc_plus4        = ex_mem_i.pc_plus4;
    assign mem_wb_o.pc_target_addr  = ex_mem_i.pc_target_addr;
    assign mem_wb_o.imm_ext         = ex_mem_i.imm_ext;
    assign mem_wb_o.alu_result      = ex_mem_i.alu_result;
    assign mem_wb_o.rdata           = rdata;
    assign mem_wb_o.trap_detected   = trap_detected;
    assign mem_wb_o.trap_mret       = ex_mem_i.trap_mret;
    assign mem_wb_o.trap_sret       = ex_mem_i.trap_sret;
    assign mem_wb_o.rd_addr         = ex_mem_i.rd_addr;
    assign mem_wb_o.csr_waddr       = ex_mem_i.csr_waddr;
    assign mem_wb_o.csr_rdata       = ex_mem_i.csr_rdata;
    assign mem_wb_o.instruction_log = ex_mem_i.instruction_log;
    assign mem_wb_o.sfence          = ex_mem_i.sfence;
    assign dcache_hit_o             = dcache_hit;
    assign rdata_mem_dcache_o       = rdata_mem_cache;

    assign axi_raddr_data_o = dcache_addr;

    // Log trace.
    assign mem_wb_o.pc_log         = ex_mem_i.pc_log;
    assign mem_wb_o.mem_addr_log   = ex_mem_i.alu_result;
    assign mem_wb_o.mem_we_log     = (ex_mem_i.mem_we | (ex_mem_i.atomic_sc && reserve_valid)) && (!trap_detected);
    assign mem_wb_o.mem_access_log = (ex_mem_i.mem_access & (~ex_mem_i.atomic_sc | (ex_mem_i.atomic_sc & reserve_valid))) & (~trap_detected);
    assign mem_wb_o.log_trace      = ex_mem_i.log_trace & ((ex_mem_i.mem_access & dcache_hit) | (~ex_mem_i.mem_access) | (mmio_access) | clint_access)
                                     & (~trap_detected | (trap_detected & ((trap_cause == csr_pkg::EXC_BREAKPOINT) |
                                                                           (trap_cause == csr_pkg::EXC_U_ENV_CALL) |
                                                                           (trap_cause == csr_pkg::EXC_S_ENV_CALL) |
                                                                           (trap_cause == csr_pkg::EXC_M_ENV_CALL))));

    always_comb begin
        case (store_type)
            2'b11: mem_wb_o.mem_wdata_log = wdata_cache;                // SD.
            2'b10: mem_wb_o.mem_wdata_log = {32'b0, wdata_cache[31:0]}; // SW.
            2'b01: mem_wb_o.mem_wdata_log = {48'b0, wdata_cache[15:0]}; // SH.
            2'b00: mem_wb_o.mem_wdata_log = {56'b0, wdata_cache[ 7:0]}; // SB.
        endcase
    end


    always_comb begin
        trap_cause     = '0;
        mem_wb_o.xtval = '0;
        if (ex_mem_i.trap_detected) begin
            case (ex_mem_i.trap_cause)
                csr_pkg::EXC_INSTR_PAGE_FAULT,
                csr_pkg::EXC_INSTR_ADDR_MA,
                csr_pkg::EXC_ILLEGAL_INSTR,
                csr_pkg::EXC_BREAKPOINT,
                csr_pkg::EXC_U_ENV_CALL,
                csr_pkg::EXC_S_ENV_CALL,
                csr_pkg::EXC_M_ENV_CALL: begin
                    trap_cause     = ex_mem_i.trap_cause;
                    mem_wb_o.xtval = ex_mem_i.xtval;
                end
                csr_pkg::IRQ_S_TIMER,
                csr_pkg::IRQ_M_TIMER,
                csr_pkg::IRQ_S_SW,
                csr_pkg::IRQ_M_SW,
                csr_pkg::IRQ_S_EXT,
                csr_pkg::IRQ_M_EXT: begin
                    if (trap_detected_mmu_i) begin
                        trap_cause     = trap_cause_mmu_i;
                        mem_wb_o.xtval = ex_mem_i.alu_result;
                    end else if (trap_dtlb_valid) begin
                        trap_cause     = store_instr ? csr_pkg::EXC_STORE_PAGE_FAULT : csr_pkg::EXC_LOAD_PAGE_FAULT;
                        mem_wb_o.xtval = ex_mem_i.alu_result;
                    end else if (trap_pmp_valid) begin
                        trap_cause     = store_instr ? csr_pkg::EXC_STORE_ACCESS_FAULT : csr_pkg::EXC_LOAD_ACCESS_FAULT;
                        mem_wb_o.xtval = ex_mem_i.alu_result;
                    end else if (trap_detected_access_fault) begin
                        trap_cause     = trap_cause_access_fault;
                        mem_wb_o.xtval = ex_mem_i.alu_result;
                    end else if (trap_detected_addr_ma) begin
                        trap_cause     = trap_cause_addr_ma;
                        mem_wb_o.xtval = ex_mem_i.alu_result;
                    end else begin
                        trap_cause    = ex_mem_i.trap_cause;
                        mem_wb_o.xtval = ex_mem_i.xtval;
                    end
                end
                default: begin
                    trap_cause     = trap_detected_access_fault ? trap_cause_access_fault : trap_cause_addr_ma;
                    mem_wb_o.xtval = ex_mem_i.alu_result;
                end
            endcase
        end else begin
            if (trap_detected_mmu_i) begin
                trap_cause     = trap_cause_mmu_i;
                mem_wb_o.xtval = ex_mem_i.alu_result;
            end else if (trap_dtlb_valid) begin
                trap_cause     = store_instr ? csr_pkg::EXC_STORE_PAGE_FAULT : csr_pkg::EXC_LOAD_PAGE_FAULT;
                mem_wb_o.xtval = ex_mem_i.alu_result;
            end else if (trap_pmp_valid) begin
                trap_cause     = store_instr ? csr_pkg::EXC_STORE_ACCESS_FAULT : csr_pkg::EXC_LOAD_ACCESS_FAULT;
                mem_wb_o.xtval = ex_mem_i.alu_result;
            end else if (trap_detected_access_fault) begin
                trap_cause     = trap_cause_access_fault;
                mem_wb_o.xtval = ex_mem_i.alu_result;
            end else if (trap_detected_addr_ma) begin
                trap_cause     = trap_cause_addr_ma;
                mem_wb_o.xtval = ex_mem_i.alu_result;
            end else begin
                trap_cause     = ex_mem_i.trap_cause;
                mem_wb_o.xtval = ex_mem_i.xtval;
            end
        end
    end

    assign mem_wb_o.trap_cause = trap_cause;

endmodule
