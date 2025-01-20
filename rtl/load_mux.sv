/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// This is a module designed to take 64-bit data from memory & adjust it 
// based on different LOAD instruction requirements. 
// -----------------------------------------------------------------------

module load_mux 
#(
    parameter DATA_WIDTH = 64
) 
(
    // Input interface. 
    input  logic [              2:0 ] i_func3,
    input  logic [ DATA_WIDTH - 1:0 ] i_data,
    input  logic [              2:0 ] i_addr_offset,

    // Output interface
    output logic                      o_load_addr_ma,
    output logic [ DATA_WIDTH - 1:0 ] o_data
);

    logic [  7:0 ] s_byte;
    logic [ 15:0 ] s_half;
    logic [ 31:0 ] s_word;

    logic s_load_addr_ma_lh;
    logic s_load_addr_ma_lw;
    logic s_load_addr_ma_ld;

    assign s_load_addr_ma_lh = i_addr_offset [ 0 ];
    assign s_load_addr_ma_lw = | i_addr_offset [ 1:0 ];
    assign s_load_addr_ma_ld = | i_addr_offset;

    always_comb begin
        case ( i_addr_offset [ 2:0 ] )
            3'b000:  s_byte = i_data [ 7 :0  ];
            3'b001:  s_byte = i_data [ 15:8  ];
            3'b010:  s_byte = i_data [ 23:16 ];
            3'b011:  s_byte = i_data [ 31:24 ];
            3'b100:  s_byte = i_data [ 39:32 ];
            3'b101:  s_byte = i_data [ 47:40 ];
            3'b110:  s_byte = i_data [ 55:48 ];
            3'b111:  s_byte = i_data [ 63:56 ];
            default: s_byte = i_data [ 7 :0  ];
        endcase 

        case ( i_addr_offset [ 2:1 ] )
            2'b00:   s_half = i_data [ 15:0  ];
            2'b01:   s_half = i_data [ 31:16 ];
            2'b10:   s_half = i_data [ 47:32 ];
            2'b11:   s_half = i_data [ 63:48 ];
            default: s_half = i_data [ 15:0  ];
        endcase 

    end

    assign s_word = i_addr_offset [ 2 ] ? i_data [ 63:32 ] : i_data [ 31:0 ];


    always_comb begin
        // Default values.
        o_data         = '0;
        o_load_addr_ma = '0;

        case ( i_func3 )
            3'b000:  begin 
                o_data         = { { 56 { s_byte [ 7  ] } }, s_byte }; // LB  Instruction.
                o_load_addr_ma = 1'b0;
            end              
            3'b001:  begin 
                o_data         = { { 48 { s_half [ 15 ] } }, s_half }; // LH  Instruction.
                o_load_addr_ma = s_load_addr_ma_lh;
            end
            3'b010:  begin 
                o_data         = { { 32 { s_word [ 31 ] } }, s_word }; // LW  Instruction.
                o_load_addr_ma = s_load_addr_ma_lw;
            end
            3'b011:  begin 
                o_data         = i_data;                               // LD  Instruction.
                o_load_addr_ma = s_load_addr_ma_ld;
            end
            3'b100:  begin 
                o_data         = { { 56 { 1'b0 } }, s_byte };          // LBU Instruction.
                o_load_addr_ma = 1'b0;
            end 
            3'b101:  begin 
                o_data         = { { 48 { 1'b0 } }, s_half };          // LHU Instruction.
                o_load_addr_ma = s_load_addr_ma_lh;
            end
            3'b110:  begin 
                o_data         = { { 32 { 1'b0 } }, s_word };          // LWU Instruction.
                o_load_addr_ma = s_load_addr_ma_lw;
            end
            default: begin 
                o_data = '0;
            end
        endcase
    end
    
endmodule