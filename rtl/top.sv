/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 14/03/2025
//------------------------------

// -----------------------------------------------------------------------
// This is a top module that contains all functional units in the design.
// -----------------------------------------------------------------------

module top
// Parameters.
#(
    parameter REG_ADDR_W  = 5,
    parameter ADDR_WIDTH  = 64,
    parameter WORD_WIDTH  = 32,
    parameter DATA_WIDTH  = 64,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     axi_done_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,
    input  logic [DATA_WIDTH  - 1:0] mmio_rdata_i,

    // Output interface.
    output logic [ADDR_WIDTH  - 1:0] axi_addr_o,
    output logic [BLOCK_WIDTH - 1:0] data_block_o,
    output logic [DATA_WIDTH  - 1:0] mmio_wdata_o,
    output logic                     mmio_write_start_o,
    output logic                     mmio_read_start_o,
    output logic                     axi_write_start_o,
    output logic                     axi_read_start_o
);

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------
    logic                    stall_if;
    logic                    stall_id;
    logic                    stall_ex;
    logic                    stall_mem;
    logic                    flush_id;
    logic                    flush_ex;
    logic [             1:0] forward_rs1;
    logic [             1:0] forward_rs2;
    logic [REG_ADDR_W - 1:0] rs1_addr_id;
    logic [REG_ADDR_W - 1:0] rs1_addr_ex;
    logic [REG_ADDR_W - 1:0] rs2_addr_id;
    logic [REG_ADDR_W - 1:0] rs2_addr_ex;
    logic [REG_ADDR_W - 1:0] rd_addr_ex;
    logic [REG_ADDR_W - 1:0] rd_addr_mem;
    logic [REG_ADDR_W - 1:0] rd_addr_wb;
    logic                    reg_we_mem;
    logic                    reg_we_wb;
    logic                    branch_mispred_ex;
    logic                    load_instr_ex;
    logic                    mdu_busy_ex;
    logic                    csr_stall;
    logic                    exc_stall;

    logic [ADDR_WIDTH - 1:0] axi_read_addr_icache;
    logic [ADDR_WIDTH - 1:0] axi_read_addr_dcache;
    logic [ADDR_WIDTH - 1:0] axi_wb_addr_dcache;
    /* verilator lint_off UNUSED */
    logic [ADDR_WIDTH - 1:0] axi_addr;
    /* verilator lint_on UNUSED */

    logic axi_read_start_icache;
    logic axi_read_start_dcache;
    logic axi_write_start;


    // Cache FSM signals.
    logic instr_we;
    logic icache_hit;
    logic stall_cache;

    logic dcache_we;
    logic dcache_hit;
    logic dcache_dirty;
    logic mem_access;
    logic mem_access_cache;

    // MMIO access.
    logic mmio_access;
    logic mmio_access_type;

    logic        log_trace_wb;

    /* verilator lint_off UNUSED */
    logic [63:0] perf_cycle_count;
    logic [63:0] perf_instr_count;
    logic [63:0] perf_stall_cycles;
    logic [63:0] perf_icache_hits;
    logic [63:0] perf_icache_misses;
    logic [63:0] perf_dcache_hits;
    logic [63:0] perf_dcache_misses;
    logic [63:0] perf_branch_mispred;
    /* verilator lint_on UNUSED */

    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Datapath module.
    //-------------------------------------
    datapath #(
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) DATAPATH0 (
        .clk_i                 (clk_i               ),
        .arst_i                (arst_i              ),
        .stall_if_i            (stall_if            ),
        .stall_id_i            (stall_id            ),
        .stall_ex_i            (stall_ex            ),
        .stall_mem_i           (stall_mem           ),
        .flush_id_i            (flush_id            ),
        .flush_ex_i            (flush_ex            ),
        .forward_rs1_i         (forward_rs1         ),
        .forward_rs2_i         (forward_rs2         ),
        .instr_we_i            (instr_we            ),
        .dcache_we_i           (dcache_we           ),
        .data_block_i          (data_block_i        ),
        .mmio_rdata_i          (mmio_rdata_i        ),
        .rs1_addr_id_o         (rs1_addr_id         ),
        .rs1_addr_ex_o         (rs1_addr_ex         ),
        .rs2_addr_id_o         (rs2_addr_id         ),
        .rs2_addr_ex_o         (rs2_addr_ex         ),
        .rd_addr_ex_o          (rd_addr_ex          ),
        .rd_addr_mem_o         (rd_addr_mem         ),
        .rd_addr_wb_o          (rd_addr_wb          ),
        .reg_we_mem_o          (reg_we_mem          ),
        .reg_we_wb_o           (reg_we_wb           ),
        .branch_mispred_ex_o   (branch_mispred_ex   ),
        .icache_hit_o          (icache_hit          ),
        .axi_read_addr_instr_o (axi_read_addr_icache),
        .axi_read_addr_data_o  (axi_read_addr_dcache),
        .dcache_hit_o          (dcache_hit          ),
        .dcache_dirty_o        (dcache_dirty        ),
        .axi_addr_wb_o         (axi_wb_addr_dcache  ),
        .data_block_o          (data_block_o        ),
        .mem_access_o          (mem_access          ),
        .load_instr_ex_o       (load_instr_ex       ),
        .mdu_busy_ex_o         (mdu_busy_ex         ),
        .csr_stall_o           (csr_stall           ),
        .exc_stall_o           (exc_stall           ),
        .mmio_access_o         (mmio_access         ),
        .mmio_access_type_o    (mmio_access_type    ),
        .mmio_wdata_o          (mmio_wdata_o        ),
        .log_trace_wb_o        (log_trace_wb        )
    );

    //-------------------------------------
    // Hazard unit.
    //-------------------------------------
    hazard_unit H0 (
        .rs1_addr_id_i       (rs1_addr_id      ),
        .rs1_addr_ex_i       (rs1_addr_ex      ),
        .rs2_addr_id_i       (rs2_addr_id      ),
        .rs2_addr_ex_i       (rs2_addr_ex      ),
        .rd_addr_ex_i        (rd_addr_ex       ),
        .rd_addr_mem_i       (rd_addr_mem      ),
        .rd_addr_wb_i        (rd_addr_wb       ),
        .reg_we_mem_i        (reg_we_mem       ),
        .reg_we_wb_i         (reg_we_wb        ),
        .branch_mispred_ex_i (branch_mispred_ex),
        .load_instr_ex_i     (load_instr_ex    ),
        .stall_cache_i       (stall_cache      ),
        .mdu_busy_ex_i       (mdu_busy_ex      ),
        .csr_stall_i         (csr_stall        ),
        .exc_stall_i         (exc_stall        ),
        .stall_if_o          (stall_if         ),
        .stall_id_o          (stall_id         ),
        .stall_ex_o          (stall_ex         ),
        .stall_mem_o         (stall_mem        ),
        .flush_id_o          (flush_id         ),
        .flush_ex_o          (flush_ex         ),
        .forward_rs1_o       (forward_rs1      ),
        .forward_rs2_o       (forward_rs2      )
    );


    //-------------------------------------
    // Cache fsm unit.
    //-------------------------------------
    cache_fsm C_FSM (
        .clk_i                   (clk_i                ),
        .arst_i                  (arst_i               ),
        .icache_hit_i            (icache_hit           ),
        .dcache_hit_i            (dcache_hit           ),
        .dcache_dirty_i          (dcache_dirty         ),
        .axi_done_i              (axi_done_i           ),
        .mem_access_i            (mem_access_cache     ),
        .branch_mispred_ex_i     (branch_mispred_ex    ),
        .stall_cache_o           (stall_cache          ),
        .instr_we_o              (instr_we             ),
        .dcache_we_o             (dcache_we            ),
        .axi_write_start_o       (axi_write_start      ),
        .axi_read_start_icache_o (axi_read_start_icache),
        .axi_read_start_dcache_o (axi_read_start_dcache)
    );


    //-------------------------------------
    // Performance counters.
    //-------------------------------------
    perf_counters PERF0 (
        .clk_i                  (clk_i                ),
        .arst_i                 (arst_i               ),
        .instr_retired_i        (log_trace_wb         ),
        .stall_i                (stall_if             ),
        .icache_hit_i           (icache_hit           ),
        .icache_req_i           (axi_read_start_icache),
        .dcache_hit_i           (dcache_hit           ),
        .dcache_req_i           (axi_read_start_dcache),
        .mem_access_i           (mem_access           ),
        .branch_mispred_i       (branch_mispred_ex    ),
        .cycle_count_o          (perf_cycle_count     ),
        .instr_count_o          (perf_instr_count     ),
        .stall_cycles_o         (perf_stall_cycles    ),
        .icache_hits_o          (perf_icache_hits     ),
        .icache_misses_o        (perf_icache_misses   ),
        .dcache_hits_o          (perf_dcache_hits     ),
        .dcache_misses_o        (perf_dcache_misses   ),
        .branch_mispred_count_o (perf_branch_mispred  )
    );


    //---------------------------------------------
    // Internal continious assignments.
    //---------------------------------------------
    assign mem_access_cache = mem_access && (~mmio_access);

    //---------------------------------------------
    // Output continious assignments.
    //---------------------------------------------
    assign axi_write_start_o = axi_write_start;
    assign axi_read_start_o  = axi_read_start_icache | axi_read_start_dcache;

    localparam WORD_OFFSET_WIDTH = $clog2(BLOCK_WIDTH/WORD_WIDTH); // 4 bit.

    assign axi_addr   = axi_write_start ? axi_wb_addr_dcache : (axi_read_start_dcache ? axi_read_addr_dcache : axi_read_addr_icache);
    assign axi_addr_o = mmio_access ? axi_read_addr_dcache : {axi_addr[ADDR_WIDTH - 1:WORD_OFFSET_WIDTH + 2], {(WORD_OFFSET_WIDTH ){1'b0}}, 2'b0};

    assign mmio_write_start_o = mmio_access && mmio_access_type;
    assign mmio_read_start_o  = mmio_access && (~mmio_access_type);

endmodule
