/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------
// This is a top AXI4-Lite module that connects AXI master and slave interfaces.
// ------------------------------------------------------------------------------


module axi4_lite_top
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32
)
(
    input logic                         clk_i,
    input logic                         arst_i,

    // Memory interface.
    input  logic [AXI_DATA_WIDTH - 1:0] data_mem_i,
    input  logic                        successful_access_i,
    input  logic                        successful_read_i,
    input  logic                        successful_write_i,
    output logic [AXI_DATA_WIDTH - 1:0] data_mem_o,
    output logic [AXI_ADDR_WIDTH - 1:0] addr_mem_o,
    output logic                        we_mem_o,
    output logic                        read_request_o,

    // Cache interface.
    input  logic [AXI_ADDR_WIDTH - 1:0] addr_cache_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_cache_i,
    input  logic                        start_write_i,
    input  logic                        start_read_i,
    output logic [AXI_DATA_WIDTH - 1:0] data_cache_o,
    output logic                        done_o,
    output logic                        read_fault_o,
    output logic                        write_fault_o
);



    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    logic                          AW_READY;
    logic                          AW_VALID;
    logic [                   2:0] AW_PROT;
    logic [AXI_ADDR_WIDTH   - 1:0] AW_ADDR;

    // Write Channel: Data.
    logic                          W_READY;
    logic [AXI_DATA_WIDTH   - 1:0] W_DATA;
    logic [AXI_DATA_WIDTH/8 - 1:0] W_STRB;
    logic                          W_VALID;

    // Write Channel: Response.
    logic [                   1:0] B_RESP;
    logic                          B_VALID;
    logic                          B_READY;

    //--------------------------------------
    // AXI Interface signals: READ
    //--------------------------------------

    // Read Channel: Address.
    logic                          AR_READY;
    logic                          AR_VALID;
    logic [AXI_ADDR_WIDTH   - 1:0] AR_ADDR;
    logic [                   2:0] AR_PROT;

    // Read Channel: Data.
    logic [AXI_DATA_WIDTH   - 1:0] R_DATA;
    logic [                   1:0] R_RESP;
    logic                          R_VALID;
    logic                          R_READY;


    //-----------------------------------
    // Lower-level module instantiations.
    //-----------------------------------

    // AXI master instance.
    axi4_lite_master # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_M (
        .clk_i         (clk_i        ),
        .arst_i        (arst_i       ),
        .addr_i        (addr_cache_i ),
        .data_i        (data_cache_i ),
        .start_write_i (start_write_i),
        .start_read_i  (start_read_i ),
        .data_o        (data_cache_o ),
        .write_fault_o (write_fault_o),
        .read_fault_o  (read_fault_o ),
        .done_o        (done_o       ),
        .AW_READY      (AW_READY     ),
        .AW_VALID      (AW_VALID     ),
        .AW_PROT       (AW_PROT      ),
        .AW_ADDR       (AW_ADDR      ),
        .W_READY       (W_READY      ),
        .W_DATA        (W_DATA       ),
        .W_STRB        (W_STRB       ),
        .W_VALID       (W_VALID      ),
        .B_RESP        (B_RESP       ),
        .B_VALID       (B_VALID      ),
        .B_READY       (B_READY      ),
        .AR_READY      (AR_READY     ),
        .AR_VALID      (AR_VALID     ),
        .AR_ADDR       (AR_ADDR      ),
        .AR_PROT       (AR_PROT      ),
        .R_DATA        (R_DATA       ),
        .R_RESP        (R_RESP       ),
        .R_VALID       (R_VALID      ),
        .R_READY       (R_READY      )
    );


    // AXI slave instance.
    axi4_lite_slave # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_S (
        .clk_i               (clk_i              ),
        .arst_i              (arst_i             ),
        .data_i              (data_mem_i         ),
        .start_read_i        (start_read_i       ),
        .start_write_i       (start_write_i      ),
        .successful_access_i (successful_access_i),
        .successful_read_i   (successful_read_i  ),
        .successful_write_i  (successful_write_i ),
        .data_o              (data_mem_o         ),
        .addr_o              (addr_mem_o         ),
        .write_en_o          (we_mem_o           ),
        .read_request_o      (read_request_o     ),
        .AR_READY            (AR_READY           ),
        .AR_VALID            (AR_VALID           ),
        .AR_ADDR             (AR_ADDR            ),
        .AR_PROT             (AR_PROT            ),
        .R_DATA              (R_DATA             ),
        .R_RESP              (R_RESP             ),
        .R_VALID             (R_VALID            ),
        .R_READY             (R_READY            ),
        .AW_READY            (AW_READY           ),
        .AW_VALID            (AW_VALID           ),
        .AW_PROT             (AW_PROT            ),
        .AW_ADDR             (AW_ADDR            ),
        .W_READY             (W_READY            ),
        .W_DATA              (W_DATA             ),
        .W_STRB              (W_STRB             ),
        .W_VALID             (W_VALID            ),
        .B_RESP              (B_RESP             ),
        .B_VALID             (B_VALID            ),
        .B_READY             (B_READY            )
    );


endmodule
