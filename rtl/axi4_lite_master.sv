/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ---------------------------------------------------------------------------------------
// This is a AXI4-Lite Master module implementation for communication with outside memory.
// ---------------------------------------------------------------------------------------

module axi4_lite_master
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32
)
(
    // Control signals.
    input  logic                        clk_i,
    input  logic                        arst_i,

    // Input interface.
    input  logic [AXI_ADDR_WIDTH - 1:0] addr_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_i,
    input  logic                        start_write_i,
    input  logic                        start_read_i,

    // Output interface.
    output logic [AXI_DATA_WIDTH - 1:0] data_o,
    output logic                        write_fault_o,
    output logic                        read_fault_o,
    output logic                        done_o,

    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address.
    input  logic                          AW_READY,
    output logic                          AW_VALID,
    output logic [                   2:0] AW_PROT,
    output logic [AXI_ADDR_WIDTH   - 1:0] AW_ADDR,

    // Write Channel: Data.
    input  logic                          W_READY,
    output logic [AXI_DATA_WIDTH   - 1:0] W_DATA,
    output logic [AXI_DATA_WIDTH/8 - 1:0] W_STRB,
    output logic                          W_VALID,

    // Write Channel: Response.
    input  logic [                   1:0] B_RESP,
    input  logic                          B_VALID,
    output logic                          B_READY,

    //--------------------------------------
    // AXI Interface signals: READ
    //--------------------------------------

    // Read Channel: Address.
    input  logic                          AR_READY,
    output logic                          AR_VALID,
    output logic [AXI_ADDR_WIDTH   - 1:0] AR_ADDR,
    output logic [                   2:0] AR_PROT,

    // Read Channel: Data.
    input  logic [AXI_DATA_WIDTH   - 1:0] R_DATA,
    input  logic [                   1:0] R_RESP,
    input  logic                          R_VALID,
    output logic                          R_READY
);
    //-------------------------
    // Internal signals.
    //-------------------------
    logic done_write_s;
    logic done_read_s;

    assign done_o = done_read_s | done_write_s;


    //-------------------------
    // Module Instantiations.
    //-------------------------

    // AXI4-Lite Master: Write.
    axi4_lite_master_write # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_MST_W (
        .clk_i         (clk_i        ),
        .arst_i        (arst_i       ),
        .addr_i        (addr_i       ),
        .data_i        (data_i       ),
        .start_write_i (start_write_i),
        .done_o        (done_write_s ),
        .write_fault_o (write_fault_o),
        .AW_READY      (AW_READY     ),
        .AW_VALID      (AW_VALID     ),
        .AW_PROT       (AW_PROT      ),
        .AW_ADDR       (AW_ADDR      ),
        .W_READY       (W_READY      ),
        .W_DATA        (W_DATA       ),
        .W_VALID       (W_VALID      ),
        .W_STRB        (W_STRB       ),
        .B_RESP        (B_RESP       ),
        .B_VALID       (B_VALID      ),
        .B_READY       (B_READY      )
    );

    // AXI4-Lite Master: Read.
    axi4_lite_master_read # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_MST_R (
        .clk_i          (clk_i       ),
        .arst_i         (arst_i      ),
        .addr_i         (addr_i      ),
        .start_read_i   (start_read_i),
        .data_o         (data_o      ),
        .access_fault_o (read_fault_o),
        .done_o         (done_read_s ),
        .AR_READY       (AR_READY    ),
        .AR_VALID       (AR_VALID    ),
        .AR_ADDR        (AR_ADDR     ),
        .AR_PROT        (AR_PROT     ),
        .R_DATA         (R_DATA      ),
        .R_RESP         (R_RESP      ),
        .R_VALID        (R_VALID     ),
        .R_READY        (R_READY     )
    );

endmodule
