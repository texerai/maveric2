/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------
// This is a AXI4-Lite Slave module implementation for communication with outside memory.
// ---------------------------------------------------------------------------------------


module axi4_lite_slave
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32
)
(
    input  logic                        clk_i,
    input  logic                        arst_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_i,
    input  logic                        start_read_i,
    input  logic                        start_write_i,
    input  logic                        successful_access_i,
    input  logic                        successful_read_i,
    input  logic                        successful_write_i,
    output logic [AXI_DATA_WIDTH - 1:0] data_o,
    output logic [AXI_ADDR_WIDTH - 1:0] addr_o,
    output logic                        write_en_o,


    //--------------------------------------
    // AXI Interface signals.
    //--------------------------------------

    // Read Channel: Address.
    output logic                          AR_READY,
    input  logic                          AR_VALID,
    input  logic [AXI_ADDR_WIDTH   - 1:0] AR_ADDR,
    input  logic [                   2:0] AR_PROT,

    // Read Channel: Data.
    output logic [AXI_DATA_WIDTH   - 1:0] R_DATA,
    output logic [                   1:0] R_RESP,
    output logic                          R_VALID,
    input  logic                          R_READY,


    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    output logic                          AW_READY,
    input  logic                          AW_VALID,
    input  logic [                   2:0] AW_PROT,
    input  logic [AXI_ADDR_WIDTH   - 1:0] AW_ADDR,

    // Write Channel: Data.
    output logic                          W_READY,
    input  logic [AXI_DATA_WIDTH   - 1:0] W_DATA,
    input  logic [AXI_DATA_WIDTH/8 - 1:0] W_STRB, 
    input  logic                          W_VALID,

    // Write Channel: Response.
    output logic [                   1:0] B_RESP,
    output logic                          B_VALID,
    input  logic                          B_READY
);

    //-------------------------
    // Internal signals.
    //-------------------------
    logic [AXI_ADDR_WIDTH - 1:0] addr_read_s;
    logic [AXI_ADDR_WIDTH - 1:0] addr_write_s;

    //-------------------------
    // Module Instantiations.
    //-------------------------

    // AXI4-Lite Slave: Write.
    axi4_lite_slave_write # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_SLV_W (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .start_write_i       (start_write_i      ),
        .successful_access_i (successful_access_i),
        .successful_write_i  (successful_write_i ),
        .addr_o              (addr_write_s       ),
        .data_o              (data_o             ),
        .write_en_o          (write_en_o         ),
        .AW_VALID            (AW_VALID           ),
        .AW_PROT             (AW_PROT            ),
        .AW_ADDR             (AW_ADDR            ),
        .AW_READY            (AW_READY           ),
        .W_DATA              (W_DATA             ),
        .W_VALID             (W_VALID            ),
        .W_STRB              (W_STRB             ),
        .W_READY             (W_READY            ),
        .B_READY             (B_READY            ),
        .B_RESP              (B_RESP             ),
        .B_VALID             (B_VALID            )
    );

    // AXI4-Lite Slave: Read.
    axi4_lite_slave_read # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_SLV_R (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .data_i              (data_i             ),
        .start_read_i        (start_read_i       ),
        .successful_access_i (successful_access_i),
        .successful_read_i   (successful_read_i  ),
        .addr_o              (addr_read_s        ),
        .AR_VALID            (AR_VALID           ),
        .AR_ADDR             (AR_ADDR            ),
        .AR_PROT             (AR_PROT            ),
        .AR_READY            (AR_READY           ),
        .R_READY             (R_READY            ),
        .R_DATA              (R_DATA             ),
        .R_RESP              (R_RESP             ),
        .R_VALID             (R_VALID            )
    );

    assign addr_o = start_read_i ? addr_read_s : addr_write_s;

endmodule
