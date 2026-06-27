/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 16/06/2026
//------------------------------

// ------------------------------------------------------------------------------------------------------------
// This is a top test environment module that connects top CPU, simlated memory & AXI4-Lite interface modules.
// ------------------------------------------------------------------------------------------------------------

module test_env
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32,
    parameter DATA_WIDTH     = 64,
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
    logic [AXI_DATA_WIDTH  - 1:0] mem_wdata;
    logic [AXI_DATA_WIDTH  - 1:0] mem_rdata;
    logic                         mem_we;
    logic [                  3:0] mem_wstrb;
    logic                         mem_read_request;
    logic                         mem_successful_access;
    logic                         mem_successful_read;
    logic                         mem_successful_write;

    // Top module signals.
    logic                         axi_access_done_cpu;
    logic                         count_done;
    logic                         cache_start_read_cpu;
    logic                         cache_start_write_cpu;
    logic [BLOCK_WIDTH     - 1:0] cache_rdata_cpu;
    logic [BLOCK_WIDTH     - 1:0] cache_wdata_cpu;
    logic [AXI_ADDR_WIDTH  - 1:0] axi_addr_cpu;

    // AXI module signals.
    logic [AXI_ADDR_WIDTH  - 1:0] axi_addr;
    logic [AXI_ADDR_WIDTH  - 1:0] axi_addr_cache;
    logic [AXI_DATA_WIDTH  - 1:0] axi_wdata;
    logic [AXI_DATA_WIDTH  - 1:0] axi_wdata_cache;
    logic [AXI_DATA_WIDTH  - 1:0] axi_rdata;
    logic                         axi_done;
    logic                         axi_done_cache;
    logic [                  3:0] axi_wstrb;

    // MMIO signals
    logic [DATA_WIDTH - 1:0] mmio_rdata_cpu;
    /* verilator lint_off UNUSED */
    logic [DATA_WIDTH - 1:0] mmio_wdata_cpu;
        /* verilator lint_on UNUSED */
    logic                    mmio_write_start_cpu;
    logic                    mmio_read_start_cpu;
    logic [             3:0] mmio_wstrb_cpu;

    // Signalling messages.
    /* verilator lint_off UNUSED */
    logic read_fault;
    logic write_fault;
    /* verilator lint_on UNUSED */

    logic axi_start_read;
    logic axi_start_write;
    logic axi_start_read_cache;
    logic axi_start_write_cache;

    assign axi_start_read_cache  = (cache_start_read_cpu  & (~ count_done));
    assign axi_start_write_cache = (cache_start_write_cpu & (~ count_done));


    //-----------------------------------
    // LOWER LEVEL MODULE INSTANTIATIONS.
    //-----------------------------------

    //--------------------------------
    // Top processing module Instance.
    //--------------------------------
    top # (
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) TOP_M (
        .clk_i              (clk_i                ),
        .arst_i             (arst_i               ),
        .axi_done_i         (axi_access_done_cpu  ),
        .data_block_i       (cache_rdata_cpu      ),
        .mmio_rdata_i       (mmio_rdata_cpu       ),
        .axi_addr_o         (axi_addr_cpu         ),
        .data_block_o       (cache_wdata_cpu      ),
        .mmio_wdata_o       (mmio_wdata_cpu       ),
        .mmio_write_start_o (mmio_write_start_cpu ),
        .mmio_read_start_o  (mmio_read_start_cpu  ),
        .mmio_wstrb_o       (mmio_wstrb_cpu       ),
        .axi_write_start_o  (cache_start_write_cpu),
        .axi_read_start_o   (cache_start_read_cpu )
    );


    //---------------------------
    // AXI module Instance.
    //---------------------------
    axi4_lite_top # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) AXI4_LITE_T (
        .clk_i               (clk_i                ),
        .arst_i              (arst_i               ),
        .data_mem_i          (mem_rdata            ),
        .successful_access_i (mem_successful_access),
        .successful_read_i   (mem_successful_read  ),
        .successful_write_i  (mem_successful_write ),
        .data_mem_o          (mem_wdata            ),
        .addr_mem_o          (mem_addr             ),
        .we_mem_o            (mem_we               ),
        .wstrb_o             (mem_wstrb            ),
        .read_request_o      (mem_read_request     ),
        .addr_cache_i        (axi_addr             ),
        .data_cache_i        (axi_wdata            ),
        .start_write_i       (axi_start_write      ),
        .start_read_i        (axi_start_read       ),
        .wstrb_i             (axi_wstrb            ),
        .data_cache_o        (axi_rdata            ),
        .done_o              (axi_done             ),
        .read_fault_o        (read_fault           ),
        .write_fault_o       (write_fault          )
    );

    //---------------------------
    // Memory Unit Instance.
    //---------------------------
    mem_simulated # (
        .DATA_WIDTH (AXI_DATA_WIDTH),
        .ADDR_WIDTH (AXI_ADDR_WIDTH)
    )
    MEM_M (
        .clk_i               (clk_i                ),
        .arst_i              (arst_i               ),
        .we_i                (mem_we               ),
        .wstrb_i             (mem_wstrb            ),
        .read_request_i      (mem_read_request     ),
        .wdata_i             (mem_wdata            ),
        .addr_i              (mem_addr             ),
        .rdata_o             (mem_rdata            ),
        .successful_access_o (mem_successful_access),
        .successful_read_o   (mem_successful_read  ),
        .successful_write_o  (mem_successful_write )
    );


    //------------------------------------
    // Cache data transfer unit instance.
    //------------------------------------
    cache_data_transfer # (
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .BLOCK_WIDTH    (BLOCK_WIDTH   )
    ) DATA_T0 (
        .clk_i              (clk_i                ),
        .arst_i             (arst_i               ),
        .start_read_i       (axi_start_read_cache ),
        .start_write_i      (axi_start_write_cache),
        .axi_done_i         (axi_done_cache       ),
        .data_block_cache_i (cache_wdata_cpu      ),
        .data_axi_i         (axi_rdata            ),
        .addr_cache_i       (axi_addr_cpu         ),
        .count_done_o       (count_done           ),
        .data_block_cache_o (cache_rdata_cpu      ),
        .data_axi_o         (axi_wdata_cache      ),
        .addr_axi_o         (axi_addr_cache       )
    );


    //------------------------------------
    // FSM.
    //------------------------------------

    // FSM states.
    typedef enum logic
    {
        CACHE = 1'b0,
        MMIO  = 1'b1
    } t_state;

    t_state PS;
    t_state NS;


    // FSM: PS syncronization.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) PS <= CACHE;
        else        PS <= NS;
    end


    // FSM: NS logic.
    always_comb begin
        // Default value.
        NS = PS;

        case (PS)
            CACHE: begin
                if (mmio_read_start_cpu | mmio_write_start_cpu) begin
                    NS = MMIO;
                end
            end
            MMIO: begin
                if (axi_done) NS = CACHE;
            end
            default: NS = PS;
        endcase
    end


    // FSM: Output logic.
    always_comb begin
        // Default values.
        axi_wstrb       = '0;
        axi_wdata       = '0;
        axi_addr        = '0;
        axi_start_read  = '0;
        axi_start_write = '0;

        axi_done_cache     = '0;
        axi_access_done_cpu = '0;

        case (PS)
            CACHE: begin
                axi_wstrb       = 4'b1111;
                axi_wdata     = axi_wdata_cache;
                axi_addr        = axi_addr_cache;
                axi_start_read  = axi_start_read_cache;
                axi_start_write = axi_start_write_cache;

                axi_done_cache  = axi_done;
                axi_access_done_cpu = count_done;
            end

            MMIO: begin
                axi_wstrb       = mmio_wstrb_cpu;
                axi_wdata       = mmio_wdata_cpu[AXI_DATA_WIDTH - 1:0];
                axi_addr        = {axi_addr_cpu[AXI_ADDR_WIDTH - 1:2], 2'b0};
                axi_start_read  = mmio_read_start_cpu;
                axi_start_write = mmio_write_start_cpu;

                axi_access_done_cpu = axi_done;
            end
            default: begin
                axi_wstrb       = '0;
                axi_wdata       = '0;
                axi_addr        = '0;
                axi_start_read  = '0;
                axi_start_write = '0;

                axi_done_cache      = '0;
                axi_access_done_cpu = '0;
            end
        endcase
    end

    assign mmio_rdata_cpu = {32'd0, axi_rdata};


endmodule
