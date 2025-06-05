/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// This is a top module that contains all functional units in the design.
// -----------------------------------------------------------------------

module top
// Parameters.
#(
    parameter REG_ADDR_W  = 5,
    parameter ADDR_WIDTH  = 64,
    parameter WORD_WIDTH  = 32,
    parameter BLOCK_WIDTH = 512
)
(
    // Input interface.
    input  logic                     clk_i,
    input  logic                     arst_i,
    input  logic                     axi_done_i,
    input  logic [BLOCK_WIDTH - 1:0] data_block_i,

    // Output interface.
    output logic [ADDR_WIDTH  - 1:0] axi_addr_o,
    output logic [BLOCK_WIDTH - 1:0] data_block_o,
    output logic                     axi_write_start_o,
    output logic                     axi_read_start_o
);

    //-------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------
    logic                    stall_fetch_s;
    logic                    stall_dec_s;
    logic                    stall_exec_s;
    logic                    stall_mem_s;
    logic                    flush_dec_s;
    logic                    flush_exec_s;
    logic [             1:0] forward_rs1_s;
    logic [             1:0] forward_rs2_s;
    logic [REG_ADDR_W - 1:0] rs1_addr_dec_s;
    logic [REG_ADDR_W - 1:0] rs1_addr_exec_s;
    logic [REG_ADDR_W - 1:0] rs2_addr_dec_s;
    logic [REG_ADDR_W - 1:0] rs2_addr_exec_s;
    logic [REG_ADDR_W - 1:0] rd_addr_exec_s;
    logic [REG_ADDR_W - 1:0] rd_addr_mem_s;
    logic [REG_ADDR_W - 1:0] rd_addr_wb_s;
    logic                    reg_we_mem_s;
    logic                    reg_we_wb_s;
    logic                    branch_mispred_exec_s;
    logic                    load_instr_exec_s;

    logic [ADDR_WIDTH - 1:0] axi_read_addr_icache_s;
    logic [ADDR_WIDTH - 1:0] axi_read_addr_dcache_s;
    logic [ADDR_WIDTH - 1:0] axi_wb_addr_dcache_s;
    logic [ADDR_WIDTH - 1:0] axi_addr_s;

    logic axi_read_start_icache_s;
    logic axi_read_start_dcache_s;
    logic axi_write_start_s;


    // Cache FSM signals.
    logic instr_we_s;
    logic icache_hit_s;
    logic stall_cache_s;

    logic dcache_we_s;
    logic dcache_hit_s;
    logic dcache_dirty_s;
    logic mem_access_s;

    //-------------------------------------------------------------
    // Lower level modules.
    //-------------------------------------------------------------

    //-------------------------------------
    // Datapath module.
    //-------------------------------------
    datapath #(
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) DATAPATH0 (
        .clk_i                 (clk_i                 ),
        .arst_i                (arst_i                ),
        .stall_fetch_i         (stall_fetch_s         ),
        .stall_dec_i           (stall_dec_s           ),
        .stall_exec_i          (stall_exec_s          ),
        .stall_mem_i           (stall_mem_s           ),
        .flush_dec_i           (flush_dec_s           ),
        .flush_exec_i          (flush_exec_s          ),
        .forward_rs1_i         (forward_rs1_s         ),
        .forward_rs2_i         (forward_rs2_s         ),
        .instr_we_i            (instr_we_s            ),
        .dcache_we_i           (dcache_we_s           ),
        .data_block_i          (data_block_i          ),
        .rs1_addr_dec_o        (rs1_addr_dec_s        ),
        .rs1_addr_exec_o       (rs1_addr_exec_s       ),
        .rs2_addr_dec_o        (rs2_addr_dec_s        ),
        .rs2_addr_exec_o       (rs2_addr_exec_s       ),
        .rd_addr_exec_o        (rd_addr_exec_s        ),
        .rd_addr_mem_o         (rd_addr_mem_s         ),
        .rd_addr_wb_o          (rd_addr_wb_s          ),
        .reg_we_mem_o          (reg_we_mem_s          ),
        .reg_we_wb_o           (reg_we_wb_s           ),
        .branch_mispred_exec_o (branch_mispred_exec_s ),
        .icache_hit_o          (icache_hit_s          ),
        .axi_read_addr_instr_o (axi_read_addr_icache_s),
        .axi_read_addr_data_o  (axi_read_addr_dcache_s),
        .dcache_hit_o          (dcache_hit_s          ),
        .dcache_dirty_o        (dcache_dirty_s        ),
        .axi_addr_wb_o         (axi_wb_addr_dcache_s  ),
        .data_block_o          (data_block_o          ),
        .mem_access_o          (mem_access_s          ),
        .load_instr_exec_o     (load_instr_exec_s     )
    );

    //-------------------------------------
    // Hazard unit.
    //-------------------------------------
    hazard_unit H0 (
        .rs1_addr_dec_i        (rs1_addr_dec_s       ),
        .rs1_addr_exec_i       (rs1_addr_exec_s      ),
        .rs2_addr_dec_i        (rs2_addr_dec_s       ),
        .rs2_addr_exec_i       (rs2_addr_exec_s      ),
        .rd_addr_exec_i        (rd_addr_exec_s       ),
        .rd_addr_mem_i         (rd_addr_mem_s        ),
        .rd_addr_wb_i          (rd_addr_wb_s         ),
        .reg_we_mem_i          (reg_we_mem_s         ),
        .reg_we_wb_i           (reg_we_wb_s          ),
        .branch_mispred_exec_i (branch_mispred_exec_s),
        .load_instr_exec_i     (load_instr_exec_s    ),
        .stall_cache_i         (stall_cache_s        ),
        .stall_fetch_o         (stall_fetch_s        ),
        .stall_dec_o           (stall_dec_s          ),
        .stall_exec_o          (stall_exec_s         ),
        .stall_mem_o           (stall_mem_s          ),
        .flush_dec_o           (flush_dec_s          ),
        .flush_exec_o          (flush_exec_s         ),
        .forward_rs1_o         (forward_rs1_s        ),
        .forward_rs2_o         (forward_rs2_s        )
    );


    //-------------------------------------
    // Cache fsm unit.
    //-------------------------------------
    cache_fsm C_FSM (
        .clk_i                   (clk_i                  ),
        .arst_i                  (arst_i                 ),
        .icache_hit_i            (icache_hit_s           ),
        .dcache_hit_i            (dcache_hit_s           ),
        .dcache_dirty_i          (dcache_dirty_s         ),
        .axi_done_i              (axi_done_i             ),
        .mem_access_i            (mem_access_s           ),
        .branch_mispred_exec_i   (branch_mispred_exec_s  ),
        .stall_cache_o           (stall_cache_s          ),
        .instr_we_o              (instr_we_s             ),
        .dcache_we_o             (dcache_we_s            ),
        .axi_write_start_o       (axi_write_start_s      ),
        .axi_read_start_icache_o (axi_read_start_icache_s),
        .axi_read_start_dcache_o (axi_read_start_dcache_s)
    );


    //---------------------------------------------
    // Output continious assignments.
    //---------------------------------------------
    assign axi_write_start_o = axi_write_start_s;
    assign axi_read_start_o  = axi_read_start_icache_s | axi_read_start_dcache_s;

    localparam WORD_OFFSET_WIDTH = $clog2(BLOCK_WIDTH/WORD_WIDTH); // 4 bit.

    assign axi_addr_s = axi_write_start_s ? axi_wb_addr_dcache_s : (axi_read_start_dcache_s ? axi_read_addr_dcache_s : axi_read_addr_icache_s);
    assign axi_addr_o = {axi_addr_s[ADDR_WIDTH - 1:WORD_OFFSET_WIDTH + 2], {(WORD_OFFSET_WIDTH ){1'b0}}, 2'b0};

endmodule
