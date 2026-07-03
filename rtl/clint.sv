/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 17/06/2026
// Last Revision: 18/06/2026
//------------------------------

// -------------------------------------------------------------
// This is a Core Local Interrupt (CLINT) module.
// -------------------------------------------------------------

`include "maveric_pkg.sv"

module clint
#(
    parameter DATA_WIDTH = maveric_pkg::XLEN,
    parameter MSIP_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)
(
    // Input interface.
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    we_i,
    input  logic [ADDR_WIDTH - 1:0] addr_i,
    input  logic [DATA_WIDTH - 1:0] wdata_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0] rdata_o,
    output logic [DATA_WIDTH - 1:0] mtime_val_o,
    output logic                    timer_irq_o,
    output logic                    software_irq_o
);
    //-------------------------------------------------------------
    // Localparams.
    //-------------------------------------------------------------
    localparam logic [ADDR_WIDTH - 1:0] CLINT_MSIP     = 16'h0000;
    localparam logic [ADDR_WIDTH - 1:0] CLINT_MTIMECMP = 16'h4000;
    localparam logic [ADDR_WIDTH - 1:0] CLINT_MTIME    = 16'hBFF8;

    //-------------------------------------
    // Internal nets.
    //-------------------------------------
    logic [MSIP_WIDTH - 1:0] msip_q;
    logic [DATA_WIDTH - 1:0] mtime_q;
    logic [DATA_WIDTH - 1:0] mtimecmp_q;

    //-------------------------------------
    // Write logic.
    //-------------------------------------
    always_ff @( posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            msip_q     <= '0; // MSIP.
            mtime_q    <= '0; // MTIME
            mtimecmp_q <= 64'hFFFFFFFFFFFFFFFF; // MTIMECMP.
        end
        else begin
            msip_q     <= msip_q;
            mtime_q    <= mtime_q + 64'b1;
            mtimecmp_q <= mtimecmp_q;

            if (we_i) begin // Architecture: Currently everything is written as store double word and no exception is raised.
                case (addr_i)
                    CLINT_MSIP    : msip_q     <= {{(MSIP_WIDTH - 1){1'b0}}, wdata_i[0]};
                    CLINT_MTIME   : mtime_q    <= wdata_i;
                    CLINT_MTIMECMP: mtimecmp_q <= wdata_i;
                    default: begin
                        msip_q     <= msip_q;
                        mtime_q    <= mtime_q + 64'b1;
                        mtimecmp_q <= mtimecmp_q;
                    end
                endcase
            end
        end
    end

    //-------------------------------------
    // Read logic.
    //-------------------------------------
    always_comb begin
        // Default value.
        rdata_o = '0;

        case (addr_i)
            CLINT_MSIP    : rdata_o = {{(MSIP_WIDTH){1'b0}}, msip_q};
            CLINT_MTIME   : rdata_o = mtime_q;
            CLINT_MTIMECMP: rdata_o = mtimecmp_q;
            default       : rdata_o = '0;
        endcase
    end

    //-------------------------------------
    // Output signals.
    //-------------------------------------
    assign mtime_val_o = mtime_q;

    assign timer_irq_o    = (mtime_q >= mtimecmp_q);
    assign software_irq_o = msip_q[0];


endmodule
