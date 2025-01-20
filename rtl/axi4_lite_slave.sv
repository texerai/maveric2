/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------
// This is a AXI4-Lite Slave module implementation for communication with outside memory.
// ---------------------------------------------------------------------------------------


module axi4_lite_slave
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    input  logic                         clk,
    input  logic                         arst,
    input  logic [ AXI_DATA_WIDTH - 1:0] i_data,
    input  logic                         i_start_read,
    input  logic                         i_start_write,
    input  logic                         i_successful_access,
    input  logic                         i_successful_read,
    input  logic                         i_successful_write,
    output logic [ AXI_DATA_WIDTH - 1:0] o_data,
    output logic [ AXI_ADDR_WIDTH - 1:0] o_addr,
    output logic                         o_write_en,


    //--------------------------------------
    // AXI Interface signals.
    //--------------------------------------

    // Read Channel: Address.
    output logic                            AR_READY,
    input  logic                            AR_VALID,
    input  logic [ AXI_ADDR_WIDTH   - 1:0 ] AR_ADDR,
    input  logic [                    2:0 ] AR_PROT,

    // Read Channel: Data.
    output logic [ AXI_DATA_WIDTH   - 1:0 ] R_DATA,
    output logic [                    1:0 ] R_RESP,
    output logic                            R_VALID,
    input  logic                            R_READY,


    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    output logic                            AW_READY,
    input  logic                            AW_VALID,
    input  logic [                    2:0 ] AW_PROT,
    input  logic [ AXI_ADDR_WIDTH   - 1:0 ] AW_ADDR,

    // Write Channel: Data.
    output logic                            W_READY,
    input  logic [ AXI_DATA_WIDTH   - 1:0 ] W_DATA,
    input  logic [ AXI_DATA_WIDTH/8 - 1:0 ] W_STRB, 
    input  logic                            W_VALID,

    // Write Channel: Response.
    output logic [                    1:0 ] B_RESP,
    output logic                            B_VALID,
    input  logic                            B_READY
);

    //-------------------------
    // Internal signals.
    //-------------------------
    logic [ AXI_ADDR_WIDTH - 1:0 ] s_addr_read;
    logic [ AXI_ADDR_WIDTH - 1:0 ] s_addr_write;

    //-------------------------
    // Module Instantiations.
    //-------------------------

    // AXI4-Lite Slave: Write.
    axi4_lite_slave_write AXI4_LITE_SLV_W (
        .clk                 ( clk                 ),
        .arst                ( arst                ),
        .i_start_write       ( i_start_write       ),
        .i_successful_access ( i_successful_access ),
        .i_successful_write  ( i_successful_write  ),
        .o_addr              ( s_addr_write         ),
        .o_data              ( o_data              ),
        .o_write_en          ( o_write_en          ),
        .AW_VALID            ( AW_VALID            ),
        .AW_PROT             ( AW_PROT             ),
        .AW_ADDR             ( AW_ADDR             ),
        .AW_READY            ( AW_READY            ),
        .W_DATA              ( W_DATA              ),
        .W_VALID             ( W_VALID             ),
        .W_STRB              ( W_STRB              ),
        .W_READY             ( W_READY             ),
        .B_READY             ( B_READY             ),
        .B_RESP              ( B_RESP              ),
        .B_VALID             ( B_VALID             )
    );

    // AXI4-Lite Slave: Read.
    axi4_lite_slave_read AXI4_LITE_SLV_R (
        .clk                 ( clk                 ),
        .arst                ( arst                ),
        .i_data              ( i_data              ),
        .i_start_read        ( i_start_read        ),
        .i_successful_access ( i_successful_access ),
        .i_successful_read   ( i_successful_read   ),
        .o_addr              ( s_addr_read         ),
        .AR_VALID            ( AR_VALID            ),
        .AR_ADDR             ( AR_ADDR             ),
        .AR_PROT             ( AR_PROT             ),
        .AR_READY            ( AR_READY            ),
        .R_READY             ( R_READY             ),
        .R_DATA              ( R_DATA              ),
        .R_RESP              ( R_RESP              ),
        .R_VALID             ( R_VALID             )
    );

    assign o_addr = i_start_read ? s_addr_read : s_addr_write;

endmodule
