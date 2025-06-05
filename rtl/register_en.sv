/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------
// This is a nonarchitectural register with write enable signal.
// -------------------------------------------------------------

module register_en
// Parameters.
#(
    parameter                        DATA_WIDTH = 64,
    parameter bit [DATA_WIDTH - 1:0] RESET_VAL = '0
)
// Port decleration.
(
    // Common clock & enable signal.
    input  logic                    clk_i,
    input  logic                    write_en_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic [DATA_WIDTH - 1:0] write_data_i,
    
    // Output interface.
    output logic [DATA_WIDTH - 1:0] read_data_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) read_data_o <= RESET_VAL;
        else if (write_en_i) read_data_o <= write_data_i;
    end

endmodule
