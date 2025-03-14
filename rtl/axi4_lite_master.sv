/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------
// This is a AXI4-Lite Master module implementation for communication with outside memory.
// ---------------------------------------------------------------------------------------

module axi4_lite_master
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    // Control signals.
    input  logic                          clk,
    input  logic                          arst,

    // Input interface.
    input  logic [ AXI_ADDR_WIDTH - 1:0 ] i_addr,
    input  logic [ AXI_DATA_WIDTH - 1:0 ] i_data,
    input  logic                          i_start_write,
    input  logic                          i_start_read,

    // Output interface. 
    output logic [ AXI_DATA_WIDTH - 1:0 ] o_data,
    output logic                          o_write_fault,
    output logic                          o_read_fault,
    output logic                          o_done,

    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    input  logic                            AW_READY,
    output logic                            AW_VALID,
    output logic [                    2:0 ] AW_PROT,
    output logic [ AXI_ADDR_WIDTH   - 1:0 ] AW_ADDR,

    // Write Channel: Data.
    input  logic                            W_READY,
    output logic [ AXI_DATA_WIDTH   - 1:0 ] W_DATA,
    output logic [ AXI_DATA_WIDTH/8 - 1:0 ] W_STRB, 
    output logic                            W_VALID,

    // Write Channel: Response.
    input  logic [                    1:0 ] B_RESP, 
    input  logic                            B_VALID,
    output logic                            B_READY,

    //--------------------------------------
    // AXI Interface signals: READ
    //--------------------------------------

    // Read Channel: Address.
    input  logic                            AR_READY,
    output logic                            AR_VALID,
    output logic [ AXI_ADDR_WIDTH   - 1:0 ] AR_ADDR,
    output logic [                    2:0 ] AR_PROT,

    // Read Channel: Data.
    input  logic [ AXI_DATA_WIDTH   - 1:0 ] R_DATA,
    input  logic [                    1:0 ] R_RESP,
    input  logic                            R_VALID,
    output logic                            R_READY
);
    //-------------------------
    // Internal signals.
    //-------------------------
    logic o_done_write;
    logic o_done_read;

    assign o_done = o_done_read | o_done_write;


    //-------------------------
    // Module Instantiations.
    //-------------------------

    // AXI4-Lite Master: Write.
    axi4_lite_master_write #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH )
    ) AXI4_LITE_MST_W (
        .clk           ( clk           ),
        .arst          ( arst          ),
        .i_addr        ( i_addr        ),
        .i_data        ( i_data        ),
        .i_start_write ( i_start_write ),
        .o_done        ( o_done_write  ),
        .o_write_fault ( o_write_fault ),
        .AW_READY      ( AW_READY      ),
        .AW_VALID      ( AW_VALID      ),
        .AW_PROT       ( AW_PROT       ),
        .AW_ADDR       ( AW_ADDR       ),
        .W_READY       ( W_READY       ),
        .W_DATA        ( W_DATA        ),
        .W_VALID       ( W_VALID       ),
        .W_STRB        ( W_STRB        ),
        .B_RESP        ( B_RESP        ),
        .B_VALID       ( B_VALID       ),
        .B_READY       ( B_READY       )
    );

    // AXI4-Lite Master: Read.
    axi4_lite_master_read #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH )
    ) AXI4_LITE_MST_R (
        .clk            ( clk            ),
        .arst           ( arst           ),
        .i_addr         ( i_addr         ),
        .i_start_read   ( i_start_read   ),
        .o_data         ( o_data         ),
        .o_access_fault ( o_read_fault   ),
        .o_done         ( o_done_read    ),
        .AR_READY       ( AR_READY       ),
        .AR_VALID       ( AR_VALID       ),
        .AR_ADDR        ( AR_ADDR        ),
        .AR_PROT        ( AR_PROT        ),
        .R_DATA         ( R_DATA         ),
        .R_RESP         ( R_RESP         ), 
        .R_VALID        ( R_VALID        ),
        .R_READY        ( R_READY        )
    );
    
endmodule