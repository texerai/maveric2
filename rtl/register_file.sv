/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------
// This is a register file component of processor based on RISC-V architecture.
// ----------------------------------------------------------------------------

module register_file
// Parameters.
#(
    parameter DATA_WIDTH = 64,
              ADDR_WIDTH = 5,
              REG_DEPTH  = 32
)
// Port decleration. 
(   
    // Common clock, enable & reset signal.
    input  logic                      i_clk,
    input  logic                      i_write_en_3,
    input  logic                      i_arst,

    //Input interface. 
    input  logic [ ADDR_WIDTH - 1:0 ] i_addr_1,
    input  logic [ ADDR_WIDTH - 1:0 ] i_addr_2,
    input  logic [ ADDR_WIDTH - 1:0 ] i_addr_3,
    input  logic [ DATA_WIDTH - 1:0 ] i_write_data_3,
    
    // Output interface.
    output logic                      o_a0_reg_lsb,
    output logic [ DATA_WIDTH - 1:0 ] o_read_data_1,
    output logic [ DATA_WIDTH - 1:0 ] o_read_data_2
);

    // Register block.
    logic [ DATA_WIDTH - 1:0 ] mem_block [ REG_DEPTH - 1:0 ];

    // Write enable logic.
    logic s_write_en_3;
    logic s_addr_3;
    
    //-----------------------------------------------------------------------------------------
    // NOTE: NEED TO REMOVE THIS PART SINCE IT ALREADY WAS HANDLED IN DECODE STAGE TOP MODULE.
    //-----------------------------------------------------------------------------------------
    assign s_addr_3    = | i_addr_3;
    assign s_write_en_3 = i_write_en_3 & ( s_addr_3 );

    // Write logic.
    always_ff @( posedge i_clk, posedge i_arst ) begin 
        if ( i_arst ) begin
            for ( int i = 0; i < REG_DEPTH; i++ ) begin
                mem_block [ i ] <= '0;
            end 
        end
        else if ( s_write_en_3 ) begin
            mem_block [ i_addr_3 ] <= i_write_data_3;
        end
    end

    // Read logic.
    assign o_read_data_1 = ( ( i_addr_1 == i_addr_3 ) & s_write_en_3 ) ? i_write_data_3 : mem_block [ i_addr_1 ];
    assign o_read_data_2 = ( ( i_addr_2 == i_addr_3 ) & s_write_en_3 ) ? i_write_data_3 : mem_block [ i_addr_2 ];

    assign o_a0_reg_lsb = mem_block [ 10 ][ 0 ];

    
endmodule