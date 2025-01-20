/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------
// This is a top AXI4-Lite module that connects AXI master and slave interfaces.
// ------------------------------------------------------------------------------


module axi4_lite_top 
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    input logic clk,
    input logic arst,

    // Memory interface.
    input  logic [ AXI_DATA_WIDTH - 1:0 ] i_data_mem,
    input  logic                          i_successful_access,
    input  logic                          i_successful_read,
    input  logic                          i_successful_write,
    output logic [ AXI_DATA_WIDTH - 1:0 ] o_data_mem,
    output logic [ AXI_ADDR_WIDTH - 1:0 ] o_addr_mem,
    output logic                          o_we_mem,

    // Cache interface. 
    input  logic [ AXI_ADDR_WIDTH - 1:0 ] i_addr_cache,
    input  logic [ AXI_DATA_WIDTH - 1:0 ] i_data_cache,
    input  logic                          i_start_write,
    input  logic                          i_start_read,
    output logic [ AXI_DATA_WIDTH - 1:0 ] o_data_cache,
    output logic                          o_done,
    output logic                          o_read_fault,
    output logic                          o_write_fault
);



    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    logic                            AW_READY;
    logic                            AW_VALID;
    logic [                    2:0 ] AW_PROT;
    logic [ AXI_ADDR_WIDTH   - 1:0 ] AW_ADDR;

    // Write Channel: Data.
    logic                            W_READY;
    logic [ AXI_DATA_WIDTH   - 1:0 ] W_DATA;
    logic [ AXI_DATA_WIDTH/8 - 1:0 ] W_STRB;
    logic                            W_VALID;

    // Write Channel: Response.
    logic [                    1:0 ] B_RESP;
    logic                            B_VALID;
    logic                            B_READY;

    //--------------------------------------
    // AXI Interface signals: READ
    //--------------------------------------

    // Read Channel: Address.
    logic                            AR_READY;
    logic                            AR_VALID;
    logic [ AXI_ADDR_WIDTH   - 1:0 ] AR_ADDR;
    logic [                    2:0 ] AR_PROT;

    // Read Channel: Data.
    logic [ AXI_DATA_WIDTH   - 1:0 ] R_DATA;
    logic [                    1:0 ] R_RESP;
    logic                            R_VALID;
    logic                            R_READY;


    //-----------------------------------
    // Lower-level module instantiations.
    //-----------------------------------

    // AXI master instance.
    axi4_lite_master AXI4_LITE_M (
        .clk           ( clk           ),
        .arst          ( arst          ),
        .i_addr        ( i_addr_cache  ),
        .i_data        ( i_data_cache  ),
        .i_start_write ( i_start_write ),
        .i_start_read  ( i_start_read  ),
        .o_data        ( o_data_cache  ),
        .o_write_fault ( o_write_fault ),
        .o_read_fault  ( o_read_fault  ),
        .o_done        ( o_done        ),
        .AW_READY      ( AW_READY      ),
        .AW_VALID      ( AW_VALID      ),
        .AW_PROT       ( AW_PROT       ),
        .AW_ADDR       ( AW_ADDR       ),
        .W_READY       ( W_READY       ),
        .W_DATA        ( W_DATA        ),
        .W_STRB        ( W_STRB        ), 
        .W_VALID       ( W_VALID       ),
        .B_RESP        ( B_RESP        ), 
        .B_VALID       ( B_VALID       ),
        .B_READY       ( B_READY       ),
        .AR_READY      ( AR_READY      ),
        .AR_VALID      ( AR_VALID      ),
        .AR_ADDR       ( AR_ADDR       ),
        .AR_PROT       ( AR_PROT       ),
        .R_DATA        ( R_DATA        ),
        .R_RESP        ( R_RESP        ),
        .R_VALID       ( R_VALID       ),
        .R_READY       ( R_READY       )
    );


    // AXI slave instance.
    axi4_lite_slave AXI4_LITE_S (
        .clk                 ( clk                 ),
        .arst                ( arst                ),
        .i_data              ( i_data_mem          ),
        .i_start_read        ( i_start_read        ),
        .i_start_write       ( i_start_write       ),
        .i_successful_access ( i_successful_access ),
        .i_successful_read   ( i_successful_read   ),
        .i_successful_write  ( i_successful_write  ),
        .o_data              ( o_data_mem          ),
        .o_addr              ( o_addr_mem          ),
        .o_write_en          ( o_we_mem            ),
        .AR_READY            ( AR_READY            ),
        .AR_VALID            ( AR_VALID            ),
        .AR_ADDR             ( AR_ADDR             ),
        .AR_PROT             ( AR_PROT             ),
        .R_DATA              ( R_DATA              ),
        .R_RESP              ( R_RESP              ),
        .R_VALID             ( R_VALID             ),
        .R_READY             ( R_READY             ),
        .AW_READY            ( AW_READY            ),
        .AW_VALID            ( AW_VALID            ),
        .AW_PROT             ( AW_PROT             ),
        .AW_ADDR             ( AW_ADDR             ),
        .W_READY             ( W_READY             ),
        .W_DATA              ( W_DATA              ),
        .W_STRB              ( W_STRB              ), 
        .W_VALID             ( W_VALID             ),
        .B_RESP              ( B_RESP              ),
        .B_VALID             ( B_VALID             ),
        .B_READY             ( B_READY             )
    );

    
endmodule