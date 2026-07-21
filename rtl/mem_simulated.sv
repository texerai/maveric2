/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 22/06/2026
//------------------------------

// --------------------------------------------------------------------------------------
// This is a instruction memory simulation file.
// --------------------------------------------------------------------------------------
`ifndef PATH_TO_MEM
`define PATH_TO_MEM "./build/instr/riscv-arch-test/lwu-align-riscv64-nemu.txt"
`endif
`include "maveric_pkg.sv"

module mem_simulated
// Parameters.
#(
    parameter DATA_WIDTH = maveric_pkg::AXI_DATA_WIDTH,
    parameter ADDR_WIDTH = maveric_pkg::AXI_ADDR_WIDTH
)
(
    // Input interface..
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    we_i,
    input  logic [             3:0] wstrb_i,
    input  logic                    read_request_i,
    input  logic [DATA_WIDTH - 1:0] wdata_i,
    input  logic [ADDR_WIDTH - 1:0] addr_i,

    // Output signals.
    output logic [DATA_WIDTH - 1:0] rdata_o,
    output logic                    successful_access_o,
    output logic                    successful_read_o,
    output logic                    successful_write_o
);
    logic [DATA_WIDTH - 1:0] mem [268435455:0];
    logic access;
    logic access_request;

    assign access_request = read_request_i | we_i;


    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) $readmemh(`PATH_TO_MEM, mem);
        else if (we_i && access && (addr_i < 64'ha0000000)) mem[addr_i[29:2]] <= (wdata_i & {{8{wstrb_i[3]}}, {8{wstrb_i[2]}}, {8{wstrb_i[1]}}, {8{wstrb_i[0]}}}) |
                                                                         (mem[addr_i[29:2]]  & (~{{8{wstrb_i[3]}}, {8{wstrb_i[2]}}, {8{wstrb_i[1]}}, {8{wstrb_i[0]}}}));
    end


    assign rdata_o            = access ? ((addr_i < 64'ha0000000) ? mem[addr_i[29:2]] : mmio_rdata) : '0;
    assign successful_read_o  = 1'b1;
    assign successful_write_o = 1'b1;


    // Simulating random multiple clock cycle memory access.
    logic [7:0] count_q;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i  )
            count_q <= '0;
        else if (access)
            count_q <= '0;
        else if (access_request)
            count_q <= count_q + 8'b1;
    end

    assign access = 1'b1;//            = (count_q == lfsr_q);
    assign successful_access_o = access;


    //---------------------------------------------
    // LFSR for generating pseudo-random sequence.
    //---------------------------------------------
    logic [7:0] lfsr_q;
    logic       lfsr_msb;

    assign lfsr_msb = lfsr_q [7] ^ lfsr_q [5] ^ lfsr_q [4] ^ lfsr_q [3];

    // Primitive Polynomial: x^8+x^6+x^5+x^4+1
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i  ) lfsr_q <= 8'b00010101; // Initial value.
        else if (access  ) lfsr_q <= {lfsr_msb, lfsr_q [7:1]};
    end


    //------------------------------------
    // UART mmio simulator.
    //------------------------------------
    logic [DATA_WIDTH - 1:0] mmio_rdata;
    assign mmio_rdata = '0;

    // DPI-C function pmem_write.
    import "DPI-C" function void pmem_write (
        longint  waddr,
        int      wdata,
        byte     wmask,
    );

    // import "DPI-C" function void pmem_read (
    //     longint  raddr,
    //     int      rdata
    // );

    always_comb begin
        if (we_i && access && (addr_i >= 64'ha0000000)) begin
           pmem_write (addr_i, wdata_i, {4'b0, wstrb_i});
        end
    end

    // always_comb begin
    //     pmem_read (addri_i, mmio_rdata);
    // end


endmodule
