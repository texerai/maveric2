/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 25/06/2026
// Last Revision: 25/06/2026
//------------------------------

// -------------------------------------------------------------------
// This is a ALU unit used in mem stage for atomic amo insttructions.
// -------------------------------------------------------------------

module amo_alu
// Parameters.
#(
    parameter DATA_WIDTH    = 64,
    parameter CONTROL_WIDTH = 5
)
// Port decleration.
(
    // ALU control signal.
    input  logic [CONTROL_WIDTH - 1:0] amo_op_i,

    // Input interface.
    input  logic [DATA_WIDTH    - 1:0] mem_rdata_i,
    input  logic [DATA_WIDTH    - 1:0] rs2_i,

    // Output interface.
    output logic [DATA_WIDTH    - 1:0] amo_result_o
);

    // ---------------
    // Operations.
    // ---------------
    localparam AMO_SWAPW = 5'b10000;
    localparam AMO_ADDW  = 5'b00000;
    localparam AMO_XORW  = 5'b00001;
    localparam AMO_ANDW  = 5'b00011;
    localparam AMO_ORW   = 5'b00010;
    localparam AMO_MINW  = 5'b00100;
    localparam AMO_MAXW  = 5'b00101;
    localparam AMO_MINUW = 5'b00110;
    localparam AMO_MAXUW = 5'b00111;

    localparam AMO_SWAPD = 5'b11000;
    localparam AMO_ADDD  = 5'b01000;
    localparam AMO_XORD  = 5'b01001;
    localparam AMO_ANDD  = 5'b01011;
    localparam AMO_ORD   = 5'b01010;
    localparam AMO_MIND  = 5'b01100;
    localparam AMO_MAXD  = 5'b01101;
    localparam AMO_MINUD = 5'b01110;
    localparam AMO_MAXUD = 5'b01111;

    //-------------------------
    // Internal nets.
    //-------------------------

    // ALU regular & immediate operation outputs.
    logic [DATA_WIDTH - 1:0] add_out;
    logic [DATA_WIDTH - 1:0] xor_out;
    logic [DATA_WIDTH - 1:0] and_out;
    logic [DATA_WIDTH - 1:0] or_out;

    logic less_than;
    logic less_than_w;
    logic less_than_u;
    logic less_than_uw;

    //---------------------------------
    // Arithmetic & Logic Operations.
    //---------------------------------

    // ALU regular & immediate operations.
    assign add_out      = mem_rdata_i + rs2_i;
    assign xor_out      = mem_rdata_i ^ rs2_i;
    assign and_out      = mem_rdata_i & rs2_i;
    assign or_out       = mem_rdata_i | rs2_i;
    assign less_than    = $signed(mem_rdata_i) < $signed(rs2_i);
    assign less_than_u  = mem_rdata_i < rs2_i;
    assign less_than_w  = $signed(mem_rdata_i[31:0]) < $signed(rs2_i[31:0]);
    assign less_than_uw = mem_rdata_i[31:0] < rs2_i[31:0];

    // ---------------------------
    // Output MUX.
    // ---------------------------
    always_comb begin
        // Default values.
        amo_result_o = '0;

        case (amo_op_i)
            AMO_SWAPW: amo_result_o = {{32{rs2_i[31]}}, rs2_i[31:0]};
            AMO_ADDW : amo_result_o = {{32{add_out[31]}}, add_out[31:0]};
            AMO_XORW : amo_result_o = {{32{xor_out[31]}}, xor_out[31:0]};
            AMO_ANDW : amo_result_o = {{32{and_out[31]}}, and_out[31:0]};
            AMO_ORW  : amo_result_o = {{32{or_out[31]}}, or_out[31:0]};
            AMO_MINW : amo_result_o = less_than_w  ? {{32{mem_rdata_i[31]}}, mem_rdata_i[31:0]} : {{32{rs2_i[31]}}, rs2_i[31:0]};
            AMO_MAXW : amo_result_o = less_than_w  ? {{32{rs2_i[31]}}, rs2_i[31:0]} : {{32{mem_rdata_i[31]}}, mem_rdata_i[31:0]};
            AMO_MINUW: amo_result_o = less_than_uw ? {32'b0, mem_rdata_i[31:0]} : {32'b0, rs2_i[31:0]};
            AMO_MAXUW: amo_result_o = less_than_uw ? {32'b0, rs2_i[31:0]} : {32'b0, mem_rdata_i[31:0]};

            AMO_SWAPD: amo_result_o = rs2_i;
            AMO_ADDD : amo_result_o = add_out;
            AMO_XORD : amo_result_o = xor_out;
            AMO_ANDD : amo_result_o = and_out;
            AMO_ORD  : amo_result_o = or_out;
            AMO_MIND : amo_result_o = less_than   ? mem_rdata_i : rs2_i;
            AMO_MAXD : amo_result_o = less_than   ? rs2_i       : mem_rdata_i;
            AMO_MINUD: amo_result_o = less_than_u ? mem_rdata_i : rs2_i;
            AMO_MAXUD: amo_result_o = less_than_u ? rs2_i       : mem_rdata_i;

            default: begin
                amo_result_o = '0;
            end
        endcase

    end
endmodule
