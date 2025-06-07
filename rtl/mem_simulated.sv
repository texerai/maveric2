/* Copyright (c) 2024 Maveric NU. All rights reserved. */

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
    logic access_s;
    logic access_request_s;

    assign access_request_s = read_request_i | write_en_i;


    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) $readmemh(`PATH_TO_MEM, mem);
        else if (write_en_i) mem[addr_i[20:2]] <= data_i;
    end


    assign read_data_o         = access_s ? mem[addr_i[20:2]] : '0;
    assign successful_read_o   = 1'b1;
    assign successful_write_o  = 1'b1;


    // Simulating random multiple clock cycle memory access.
    logic [7:0] count_s;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i  )
            count_s <= '0;
        else if (access_s)
            count_s <= '0;
        else if (access_request_s)
            count_s <= count_s + 8'b1;
    end

    assign access_s            = (count_s == lfsr_s);
    assign successful_access_o = access_s;


    //---------------------------------------------
    // LFSR for generating pseudo-random sequence.
    //---------------------------------------------
    logic [7:0] lfsr_s;
    logic         lfsr_msb_s;

    assign lfsr_msb_s = lfsr_s [7] ^ lfsr_s [5] ^ lfsr_s [4] ^ lfsr_s [3];

    // Primitive Polynomial: x^8+x^6+x^5+x^4+1
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i  ) lfsr_s <= 8'b00010101; // Initial value.
        else if (access_s) lfsr_s <= {lfsr_msb_s, lfsr_s [7:1]};
    end


endmodule
