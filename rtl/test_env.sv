/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 08/06/2025
//------------------------------

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
    logic [AXI_ADDR_WIDTH  - 1:0] mem_addr;
    logic [AXI_DATA_WIDTH  - 1:0] mem_data_in;
    logic [AXI_DATA_WIDTH  - 1:0] mem_data_out;
    logic                         mem_we;
    logic                         read_request;
    logic                         successful_access;
    logic                         successful_read;
    logic                         successful_write;

    // Top module signals.
    logic                         count_done;
    logic                         start_read;
    logic                         start_write;
    logic [BLOCK_WIDTH     - 1:0] cache_data_in;
    logic [BLOCK_WIDTH     - 1:0] cache_data_out;
    logic [AXI_ADDR_WIDTH  - 1:0] cache_addr;

    // AXI module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] axi_addr;
    logic [AXI_DATA_WIDTH  - 1:0] axi_data_in;
    logic [AXI_DATA_WIDTH  - 1:0] axi_data_out;
    logic                         axi_done;

    // Signalling messages.
    /* verilator lint_off UNUSED */
    logic read_fault;
    logic write_fault;
    /* verilator lint_on UNUSED */

    logic start_read_axi;
    logic start_write_axi;

    assign start_read_axi  = start_read  & (~ count_done);
    assign start_write_axi = start_write & (~ count_done);


    //-----------------------------------
    // LOWER LEVEL MODULE INSTANTIATIONS.
    //-----------------------------------

    //--------------------------------
    // Top processing module Instance.
    //--------------------------------
    top # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) TOP_M (
        .clk_i             (clk_i         ),
        .arst_i            (arst_i        ),
        .axi_done_i        (count_done    ),
        .data_block_i      (cache_data_in ),
        .axi_addr_o        (cache_addr    ),
        .data_block_o      (cache_data_out),
        .axi_write_start_o (start_write   ),
        .axi_read_start_o  (start_read    )
    );


    //---------------------------
    // AXI module Instance.
    //---------------------------
    axi4_lite_top # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_T (
        .clk_i               (clk_i            ),
        .arst_i              (arst_i           ),
        .data_mem_i          (mem_data_out     ),
        .successful_access_i (successful_access),
        .successful_read_i   (successful_read  ),
        .successful_write_i  (successful_write ),
        .data_mem_o          (mem_data_in      ),
        .addr_mem_o          (mem_addr         ),
        .we_mem_o            (mem_we           ),
        .read_request_o      (read_request     ),
        .addr_cache_i        (axi_addr         ),
        .data_cache_i        (axi_data_in      ),
        .start_write_i       (start_write_axi  ),
        .start_read_i        (start_read_axi   ),
        .data_cache_o        (axi_data_out     ),
        .done_o              (axi_done         ),
        .read_fault_o        (read_fault       ),
        .write_fault_o       (write_fault      )
    );

    //---------------------------
    // Memory Unit Instance.
    //---------------------------
    mem_simulated # (
        .DATA_WIDTH (AXI_DATA_WIDTH),
        .ADDR_WIDTH (AXI_ADDR_WIDTH)
    )
    MEM_M (
        .clk_i               (clk_i            ),
        .arst_i              (arst_i           ),
        .write_en_i          (mem_we           ),
        .read_request_i      (read_request     ),
        .data_i              (mem_data_in      ),
        .addr_i              (mem_addr         ),
        .read_data_o         (mem_data_out     ),
        .successful_access_o (successful_access),
        .successful_read_o   (successful_read  ),
        .successful_write_o  (successful_write )
    );


    //------------------------------------
    // Cache data transfer unit instance.
    //------------------------------------
    cache_data_transfer # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .BLOCK_WIDTH    (BLOCK_WIDTH   )
    ) DATA_T0 (
        .clk_i              (clk_i          ),
        .arst_i             (arst_i         ),
        .start_read_i       (start_read_axi ),
        .start_write_i      (start_write_axi),
        .axi_done_i         (axi_done       ),
        .data_block_cache_i (cache_data_out ),
        .data_axi_i         (axi_data_out   ),
        .addr_cache_i       (cache_addr     ),
        .count_done_o       (count_done     ),
        .data_block_cache_o (cache_data_in  ),
        .data_axi_o         (axi_data_in    ),
        .addr_axi_o         (axi_addr       )
    );




endmodule
