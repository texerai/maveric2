/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 30/05/2025
//------------------------------

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
    // Common clock & reset signal.
    input  logic                    clk_i,
    input  logic                    arst_i,

    //Input interface.
    input  logic                    we_i,
    input  logic [DATA_WIDTH - 1:0] wdata_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] rdata_o
);

    // Write logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i) rdata_o <= RESET_VAL;
        else if (we_i  ) rdata_o <= wdata_i;
    end

endmodule
