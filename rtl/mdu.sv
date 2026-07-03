/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------------------------------
// Multiply-Divide Unit (MDU): wraps the multi-cycle multiplier/divider.
// op_i[2:0] maps directly to the RISC-V M-extension func3 field:
//   000=MUL, 001=MULH, 010=MULHSU, 011=MULHU  (routed to multiplier)
//   100=DIV, 101=DIVU, 110=REM,    111=REMU    (routed to divider)
// -----------------------------------------------------------------------

`include "maveric_pkg.sv"

module mdu
// Parameters.
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN
)
// Port decleration.
(
    // Clock & reset.
    input  logic                    clk_i,
    input  logic                    arst_i,

    // Control signals.
    input  logic                    start_i,
    input  logic [2:0]              op_i,
    input  logic                    is_mdu_word_op_i,

    // Data inputs.
    input  logic [DATA_WIDTH - 1:0] a_i,
    input  logic [DATA_WIDTH - 1:0] b_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] c_o,
    output logic                    busy_o
);

    //-------------------------
    // Internal nets.
    //-------------------------
    logic is_div_s;
    assign is_div_s = op_i[2];

    // One-shot pulse: converts a held start_i into a single-cycle trigger.
    logic started_r;
    logic start_pulse_s;

    always_ff @(posedge clk_i or posedge arst_i) begin

        if      (arst_i        ) started_r <= 1'b0;
        else if (start_pulse_s ) started_r <= 1'b1;
        else if (done_s        ) started_r <= 1'b0;

    end

    assign start_pulse_s = start_i & ~started_r;

    // Route start to exactly one submodule based on live op_i[2].
    logic mul_start_s;
    logic div_start_s;
    assign mul_start_s = start_pulse_s & ~op_i[2];
    assign div_start_s = start_pulse_s &  op_i[2];

    logic [DATA_WIDTH - 1:0] mul_c_s;
    logic [DATA_WIDTH - 1:0] div_c_s;
    logic              mul_done_s;
    logic              div_done_s;
    logic              done_s;


    //-------------------------------------
    // Lower level modules.
    //-------------------------------------

    // Multiplier.
    multiplier #(.DATA_WIDTH(DATA_WIDTH)) MUL0 (
        .clk_i            (clk_i           ),
        .arst_i           (arst_i          ),
        .start_i          (mul_start_s     ),
        .op_i             (op_i[1:0]       ),
        .is_mdu_word_op_i (is_mdu_word_op_i),
        .a_i              (a_i             ),
        .b_i              (b_i             ),
        .c_o              (mul_c_s         ),
        .done_o           (mul_done_s      )
    );

    // Divider.
    divider #(.DATA_WIDTH(DATA_WIDTH)) DIV0 (
        .clk_i            (clk_i           ),
        .arst_i           (arst_i          ),
        .start_i          (div_start_s     ),
        .op_i             (op_i[1:0]       ),
        .is_mdu_word_op_i (is_mdu_word_op_i),
        .a_i              (a_i             ),
        .b_i              (b_i             ),
        .c_o              (div_c_s         ),
        .done_o           (div_done_s      )
    );


    //---------------------------------------
    // Continuous assignment of outputs.
    //---------------------------------------
    assign done_s  = is_div_s ? div_done_s : mul_done_s;
    assign c_o     = is_div_s ? div_c_s    : mul_c_s;
    assign busy_o  = ~done_s | start_pulse_s;

endmodule
