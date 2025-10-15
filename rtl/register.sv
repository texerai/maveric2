/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------
// This is a nonarchitectural register without write enable signal.
// ----------------------------------------------------------------

module register
// Parameters.
#(
    parameter DATA_WIDTH = 64
)
// Port decleration.
(
    // Common clock & enable signal.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic [DATA_WIDTH - 1:0] write_data_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] read_data_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) read_data_o <= '0;
        else        read_data_o <= write_data_i;
    end

endmodule
