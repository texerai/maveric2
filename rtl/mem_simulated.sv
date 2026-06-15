/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 07/06/2025
//------------------------------

// --------------------------------------------------------------------------------------
// This is a instruction memory simulation file.
// --------------------------------------------------------------------------------------

`define PATH_TO_MEM "./test/tests/instr/riscv-tests/rv64ui-p-xori.txt"

module mem_simulated
// Parameters.
#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 64
)
(
    // Input interface..
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    write_en_i,
    input  logic [             3:0] wstrb_i,
    input  logic                    read_request_i,
    input  logic [DATA_WIDTH - 1:0] data_i,
    input  logic [ADDR_WIDTH - 1:0] addr_i,

    // Output signals.
    output logic [DATA_WIDTH - 1:0] read_data_o,
    output logic                    successful_access_o,
    output logic                    successful_read_o,
    output logic                    successful_write_o
);
    logic [DATA_WIDTH - 1:0] mem [524287:0];
    logic access;
    logic access_request;

    assign access_request = read_request_i | write_en_i;


    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) $readmemh(`PATH_TO_MEM, mem);
        else if (write_en_i && access && (addr_i < 64'ha0000000)) mem[addr_i[20:2]] <= (data_i & {{8{wstrb_i[3]}}, {8{wstrb_i[2]}}, {8{wstrb_i[1]}}, {8{wstrb_i[0]}}}) |
                                                                         (mem[addr_i[20:2]]  & (~{{8{wstrb_i[3]}}, {8{wstrb_i[2]}}, {8{wstrb_i[1]}}, {8{wstrb_i[0]}}}));
    end


    assign read_data_o        = access ? mem[addr_i[20:2]] : '0;
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

    assign access              = (count_q == lfsr_q);
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

    // DPI-C function pmem_write.
    import "DPI-C" function void pmem_write (
        longint  waddr,
        int  wdata,
        byte     wmask,
    );

    always_comb begin
        if (write_en_i && access) begin
           pmem_write (addr_i, data_i, {4'b0, wstrb_i});
        end
    end

    // always_comb begin
    //     if (mmio_read_start) mmio_rdata = 64'd0;
    //     else                 mmio_rdata = 64'd0;
    // end


endmodule
