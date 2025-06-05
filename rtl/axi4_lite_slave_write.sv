/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Slave module implementation for communication with outside memory for write operations.
// -------------------------------------------------------------------------------------------------------------

module axi4_lite_slave_write
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32
)
(
    // Control signals.
    input  logic                        clk_i,
    input  logic                        arst_i,

    // Input interface.
    input  logic                        start_write_i,
    input  logic                        successful_access_i,
    input  logic                        successful_write_i,

    // Output interface. 
    output logic [AXI_ADDR_WIDTH - 1:0] addr_o,
    output logic [AXI_DATA_WIDTH - 1:0] data_o,
    output logic                        write_en_o,

    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address. Ignored AW_ID for now.
    input  logic                          AW_VALID,
    input  logic [                   2:0] AW_PROT,
    input  logic [AXI_ADDR_WIDTH   - 1:0] AW_ADDR,
    output logic                          AW_READY,

    // Write Channel: Data.
    input  logic [AXI_DATA_WIDTH   - 1:0] W_DATA,
    input  logic                          W_VALID,
    input  logic [AXI_DATA_WIDTH/8 - 1:0] W_STRB,
    output logic                          W_READY,

    // Write Channel: Response. Ignored B_ID for now.
    input  logic                          B_READY,
    output logic [                   1:0] B_RESP,
    output logic                          B_VALID
);

    //-------------------------
    // Write FSM.
    //-------------------------

    // FSM: States.
    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        AW_WRITE  = 3'b010,
        WRITE     = 3'b001,
        RESP      = 3'b011,
        WAIT      = 3'b100
    } t_state;

    t_state PS;
    t_state NS;
    
    // FSM: State Synchronization 
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            PS <= IDLE;
        end
        else PS <= NS;
    end

    // FSM: Next State Logic.
    always_comb begin
        NS = PS;

        case (PS)
            IDLE    : if (start_write_i                 ) NS = AW_WRITE;
            AW_WRITE: if (AW_READY & AW_VALID           ) NS = WRITE;
            WRITE   : if (W_READY  & W_VALID            ) NS = RESP;
            RESP    : if (B_READY  & successful_access_i) NS = WAIT;
            WAIT    :                                     NS = IDLE;

            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            AW_READY   <= 1'b0;
            addr_o     <= '0;
            data_o     <= '0;
            write_en_o <= 1'b0;
            W_READY    <= 1'b0;
            B_VALID    <= 1'b0;
            B_RESP     <= 2'b0;
        end

        case (PS)
            IDLE: if (start_write_i) begin
                AW_READY <= 1'b1;
            end

            AW_WRITE: if (AW_VALID) begin
                addr_o   <= AW_ADDR;
                W_READY  <= 1'b1;
                AW_READY <= 1'b0;
            end 

            WRITE: if (W_VALID) begin
                W_READY    <= 1'b0;
                write_en_o <= 1'b1;
                data_o     <= W_DATA;
            end

            RESP: if (successful_access_i) begin
                B_VALID    <= 1'b1;
                write_en_o <= 1'b0;
                if (successful_write_i) B_RESP <= 2'b00;
                else                    B_RESP <= 2'b10;
            end

            default: begin
                AW_READY   <= 1'b0;
                write_en_o <= 1'b0;
                W_READY    <= 1'b0;
                B_VALID    <= 1'b0;
                B_RESP     <= 2'b0;
            end

              
        endcase
    end
    
endmodule
