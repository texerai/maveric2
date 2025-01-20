/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------
// This is a instruction memory simulation file.
// --------------------------------------------------------------------------------------

`define PATH_TO_MEM "./test/tests/instr/am-kernels/add-riscv64-nemu.txt"

module mem_simulated
// Parameters.
#(
    parameter DATA_WIDTH = 32,
              ADDR_WIDTH = 64
)
(
    // Input interface..
    input  logic                      i_clk,
    input  logic                      i_arst,
    input  logic                      i_write_en,
    input  logic [ DATA_WIDTH - 1:0 ] i_data,
    input  logic [ ADDR_WIDTH - 1:0 ] i_addr,

    // Output signals.
    output logic [ DATA_WIDTH - 1:0 ] o_read_data,
    output logic                      o_successful_access,
    output logic                      o_successful_read,
    output logic                      o_successful_write
);
    logic [ DATA_WIDTH - 1:0 ] mem [ 524287:0];
    logic s_access;


    always_ff @( posedge i_clk, posedge i_arst ) begin
        if      ( i_arst     ) $readmemh(`PATH_TO_MEM, mem);
        else if ( i_write_en ) mem[ i_addr[ 20:2 ] ] <= i_data;
    end


    assign o_read_data         = mem[ i_addr [20:2] ];
    assign o_successful_read   = 1'b1;
    assign o_successful_write  = 1'b1;


    // Simulating random multiple clock cycle memory access.
    logic [ 7:0 ] s_count;

    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst    ) s_count <= '0;
        if ( s_access  ) s_count <= '0;
        else             s_count <= s_count + 8'b1;
    end

    assign s_access            = ( s_count == s_lfsr ); 
    assign o_successful_access = s_access; 


    //---------------------------------------------
    // LFSR for generating pseudo-random sequence.
    //---------------------------------------------
    logic [ 7:0 ] s_lfsr;
    logic         s_lfsr_msb;

    assign s_lfsr_msb = s_lfsr [ 7 ] ^ s_lfsr [ 5 ] ^ s_lfsr [ 4 ] ^ s_lfsr [ 3 ];

    // Primitive Polynomial: x^8+x^6+x^5+x^4+1
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if      ( i_arst   ) s_lfsr <= 8'b00010101; // Initial value.
        else if ( s_access ) s_lfsr <= { s_lfsr_msb, s_lfsr [ 7:1 ] };
    end

    
endmodule
