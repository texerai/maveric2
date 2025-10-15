/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------------------------
// This is a top test environment module that connects top CPU, simlated memory & AXI4-Lite interface modules.
// ------------------------------------------------------------------------------------------------------------

module test_env
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32,
    parameter BLOCK_WIDTH    = 512
)
(
    input logic clk_i,
    input logic arst_i
);

    //------------------------
    // INTERNAL NETS.
    //------------------------

    // Memory module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] mem_addr_s;
    logic [AXI_DATA_WIDTH  - 1:0] mem_data_in_s;
    logic [AXI_DATA_WIDTH  - 1:0] mem_data_out_s;
    logic                         mem_we_s;
    logic                         read_request_s;
    logic                         successful_access_s;
    logic                         successful_read_s;
    logic                         successful_write_s;

    // Top module signals.
    logic                         count_done_s;
    logic                         start_read_s;
    logic                         start_write_s;
    logic [BLOCK_WIDTH     - 1:0] cache_data_in_s;
    logic [BLOCK_WIDTH     - 1:0] cache_data_out_s;
    logic [AXI_ADDR_WIDTH  - 1:0] cache_addr_s;

    // AXI module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] axi_addr_s;
    logic [AXI_DATA_WIDTH  - 1:0] axi_data_in_s;
    logic [AXI_DATA_WIDTH  - 1:0] axi_data_out_s;
    logic                         axi_done_s;

    // Signalling messages.
    /* verilator lint_off UNUSED */
    logic read_fault_s;
    logic write_fault_s;
    /* verilator lint_on UNUSED */

    logic start_read_axi_s;
    logic start_write_axi_s;

    assign start_read_axi_s  = start_read_s  & (~ count_done_s);
    assign start_write_axi_s = start_write_s & (~ count_done_s);


    //-----------------------------------
    // LOWER LEVEL MODULE INSTANTIATIONS.
    //-----------------------------------

    //--------------------------------
    // Top processing module Instance.
    //--------------------------------
    top # (
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) TOP_M (
        .clk_i             (clk_i           ),
        .arst_i            (arst_i          ),
        .axi_done_i        (count_done_s    ),
        .data_block_i      (cache_data_in_s ),
        .axi_addr_o        (cache_addr_s    ),
        .data_block_o      (cache_data_out_s),
        .axi_write_start_o (start_write_s   ),
        .axi_read_start_o  (start_read_s    )
    );


    //---------------------------
    // AXI module Instance.
    //---------------------------
    axi4_lite_top # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_T (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .data_mem_i          (mem_data_out_s     ),
        .successful_access_i (successful_access_s),
        .successful_read_i   (successful_read_s  ),
        .successful_write_i  (successful_write_s ),
        .data_mem_o          (mem_data_in_s      ),
        .addr_mem_o          (mem_addr_s         ),
        .we_mem_o            (mem_we_s           ),
        .read_request_o      (read_request_s     ),
        .addr_cache_i        (axi_addr_s         ),
        .data_cache_i        (axi_data_in_s      ),
        .start_write_i       (start_write_axi_s  ),
        .start_read_i        (start_read_axi_s   ),
        .data_cache_o        (axi_data_out_s     ),
        .done_o              (axi_done_s         ),
        .read_fault_o        (read_fault_s       ),
        .write_fault_o       (write_fault_s      )
    );

    //---------------------------
    // Memory Unit Instance.
    //---------------------------
    mem_simulated # (
        .DATA_WIDTH (AXI_DATA_WIDTH),
        .ADDR_WIDTH (AXI_ADDR_WIDTH)
    )
    MEM_M (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .write_en_i          (mem_we_s           ),
        .read_request_i      (read_request_s     ),
        .data_i              (mem_data_in_s      ),
        .addr_i              (mem_addr_s         ),
        .read_data_o         (mem_data_out_s     ),
        .successful_access_o (successful_access_s),
        .successful_read_o   (successful_read_s  ),
        .successful_write_o  (successful_write_s )
    );


    //------------------------------------
    // Cache data transfer unit instance.
    //------------------------------------
    cache_data_transfer # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .BLOCK_WIDTH    (BLOCK_WIDTH   )
    ) DATA_T0 (
        .clk_i              (clk_i            ),
        .arst_i             (arst_i           ),
        .start_read_i       (start_read_axi_s ),
        .start_write_i      (start_write_axi_s),
        .axi_done_i         (axi_done_s       ),
        .data_block_cache_i (cache_data_out_s ),
        .data_axi_i         (axi_data_out_s   ),
        .addr_cache_i       (cache_addr_s     ),
        .count_done_o       (count_done_s     ),
        .data_block_cache_o (cache_data_in_s  ),
        .data_axi_o         (axi_data_in_s    ),
        .addr_axi_o         (axi_addr_s       )
    );




endmodule
