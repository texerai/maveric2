/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------------------------
// This is a top test environment module that connects top CPU, simlated memory & AXI4-Lite interface modules.
// ------------------------------------------------------------------------------------------------------------

module test_env 
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32,
              BLOCK_WIDTH    = 512
) 
(
    input logic i_clk,
    input logic i_arst
);

    //------------------------
    // INTERNAL NETS.
    //------------------------

    // Memory module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] s_mem_addr;
    logic [AXI_DATA_WIDTH  - 1:0] s_mem_data_in;
    logic [AXI_DATA_WIDTH  - 1:0] s_mem_data_out;
    logic                         s_mem_we;
    logic                         s_successful_access;
    logic                         s_successful_read;
    logic                         s_successful_write;

    // Top module signals.
    logic                         s_count_done;
    logic                         s_start_read;
    logic                         s_start_write;
    logic [BLOCK_WIDTH     - 1:0] s_cache_data_in;
    logic [BLOCK_WIDTH     - 1:0] s_cache_data_out;
    logic [AXI_ADDR_WIDTH  - 1:0] s_cache_addr;

    // AXI module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] s_axi_addr;
    logic [AXI_DATA_WIDTH  - 1:0] s_axi_data_in;
    logic [AXI_DATA_WIDTH  - 1:0] s_axi_data_out;
    logic                         s_axi_done;

    // Signalling messages.
    logic s_read_fault;
    logic s_write_fault;

    logic s_start_read_axi;
    logic s_start_write_axi;

    assign s_start_read_axi  = s_start_read  & (~ s_count_done);
    assign s_start_write_axi = s_start_write & (~ s_count_done);


    //-----------------------------------
    // LOWER LEVEL MODULE INSTANTIATIONS.
    //-----------------------------------

    //--------------------------------
    // Top processing module Instance.
    //--------------------------------
    top #(
        .BLOCK_WIDTH ( BLOCK_WIDTH )
    ) TOP_M (
        .i_clk             ( i_clk            ),
        .i_arst            ( i_arst           ),
        .i_axi_done        ( s_count_done     ),
        .i_data_block      ( s_cache_data_in  ),
        .o_axi_addr        ( s_cache_addr     ),
        .o_data_block      ( s_cache_data_out ),
        .o_axi_write_start ( s_start_write    ),
        .o_axi_read_start  ( s_start_read     )
    );


    //---------------------------
    // AXI module Instance.
    //---------------------------
    axi4_lite_top #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH )
    ) AXI4_LITE_T (
        .clk                 ( i_clk               ),
        .arst                ( i_arst              ),
        .i_data_mem          ( s_mem_data_out      ),
        .i_successful_access ( s_successful_access ),
        .i_successful_read   ( s_successful_read   ),
        .i_successful_write  ( s_successful_write  ),
        .o_data_mem          ( s_mem_data_in       ),
        .o_addr_mem          ( s_mem_addr          ),
        .o_we_mem            ( s_mem_we            ),
        .i_addr_cache        ( s_axi_addr          ),
        .i_data_cache        ( s_axi_data_in       ),
        .i_start_write       ( s_start_write_axi   ),
        .i_start_read        ( s_start_read_axi    ),
        .o_data_cache        ( s_axi_data_out      ),
        .o_done              ( s_axi_done          ),
        .o_read_fault        ( s_read_fault        ),
        .o_write_fault       ( s_write_fault       )
    );

    //---------------------------
    // Memory Unit Instance.
    //---------------------------
    mem_simulated #(
        .DATA_WIDTH ( AXI_DATA_WIDTH ),
        .ADDR_WIDTH ( AXI_ADDR_WIDTH )
    )
    MEM_M (
        .i_clk               ( i_clk               ),
        .i_arst              ( i_arst              ),
        .i_write_en          ( s_mem_we            ),
        .i_data              ( s_mem_data_in       ),
        .i_addr              ( s_mem_addr          ),
        .o_read_data         ( s_mem_data_out      ),
        .o_successful_access ( s_successful_access ),
        .o_successful_read   ( s_successful_read   ),
        .o_successful_write  ( s_successful_write  )
    );


    //------------------------------------
    // Cache data transfer unit instance.
    //------------------------------------
    cache_data_transfer # (
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .BLOCK_WIDTH    ( BLOCK_WIDTH    )
    ) DATA_T0 (
        .i_clk              ( i_clk             ),
        .i_arst             ( i_arst            ),
        .i_start_read       ( s_start_read_axi  ),
        .i_start_write      ( s_start_write_axi ),
        .i_axi_done         ( s_axi_done        ),
        .i_data_block_cache ( s_cache_data_out  ),
        .i_data_axi         ( s_axi_data_out    ),
        .i_addr_cache       ( s_cache_addr      ),
        .o_count_done       ( s_count_done      ),
        .o_data_block_cache ( s_cache_data_in   ),
        .o_data_axi         ( s_axi_data_in     ),
        .o_addr_axi         ( s_axi_addr        )
    );



    
endmodule