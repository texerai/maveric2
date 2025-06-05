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
    input  logic                    clk_i,
    input  logic                    write_en_3_i,
    input  logic                    arst_i,

    // Input interface.
    input  logic [ADDR_WIDTH - 1:0] addr_1_i,
    input  logic [ADDR_WIDTH - 1:0] addr_2_i,
    input  logic [ADDR_WIDTH - 1:0] addr_3_i,
    input  logic [DATA_WIDTH - 1:0] write_data_3_i,
    
    // Output interface.
    output logic                    a0_reg_lsb_o,
    output logic [DATA_WIDTH - 1:0] read_data_1_o,
    output logic [DATA_WIDTH - 1:0] read_data_2_o
);

    // Register block.
    logic [DATA_WIDTH - 1:0] mem_block [REG_DEPTH - 1:0];


    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            for (int i = 0; i < REG_DEPTH; i++) begin
                mem_block [i] <= '0;
            end
        end
        else if (write_en_3_i) begin
            mem_block [addr_3_i] <= write_data_3_i;
        end
    end

    // Read logic.
    assign read_data_1_o = ((addr_1_i == addr_3_i) & write_en_3_i) ? write_data_3_i : mem_block[addr_1_i];
    assign read_data_2_o = ((addr_2_i == addr_3_i) & write_en_3_i) ? write_data_3_i : mem_block[addr_2_i];

    assign a0_reg_lsb_o = mem_block[10][0];


endmodule
