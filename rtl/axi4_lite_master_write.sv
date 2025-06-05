/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Master module implementation for communication with outside memory for write operations.
// -------------------------------------------------------------------------------------------------------------

module axi4_lite_master_write
// Parameters.
#(
    parameter AXI_ADDR_WIDTH = 64,
    parameter AXI_DATA_WIDTH = 32
) 
(
    // Control signals.
    input  logic                        clk_i,
    input  logic                        arst_i,

    // Input interface.
    input  logic [AXI_ADDR_WIDTH - 1:0] addr_i,
    input  logic [AXI_DATA_WIDTH - 1:0] data_i,
    input  logic                        start_write_i,

    // Output interface. 
    output logic                        done_o,
    output logic                        write_fault_o,

    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address. Ignored AW_ID for now.
    input  logic                          AW_READY,
    output logic                          AW_VALID,
    output logic [                   2:0] AW_PROT,
    output logic [AXI_ADDR_WIDTH   - 1:0] AW_ADDR,

    // Write Channel: Data.
    input  logic                          W_READY,
    output logic [AXI_DATA_WIDTH   - 1:0] W_DATA,
    output logic                          W_VALID,
    output logic [AXI_DATA_WIDTH/8 - 1:0] W_STRB,

    // Write Channel: Response. Ignored B_ID for now.
    input  logic [                   1:0] B_RESP,
    input  logic                          B_VALID,
    output logic                          B_READY
);

    //-------------------------
    // Continious assignments.
    //-------------------------
    assign AW_PROT  = 3'b100; // Random value. NOT FINAL VALUE.
    assign W_STRB   = 4'b1111; 


    //-------------------------
    // Write FSM.
    //-------------------------

    // FSM: States.
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        AW_WRITE  = 2'b10,
        WRITE     = 2'b01,
        RESP      = 2'b11
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
            IDLE    : if (start_write_i      ) NS = AW_WRITE;
            AW_WRITE: if (AW_READY & AW_VALID) NS = WRITE;
            WRITE   : if (W_READY  & W_VALID ) NS = RESP;
            RESP    : if (B_READY  & B_VALID ) NS = IDLE;

            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            AW_VALID <= 1'b0;
            AW_ADDR  <= '0;
            W_VALID  <= 1'b0;
            B_READY  <= 1'b0;
            W_DATA   <= '0;
        end

        case (PS)
            IDLE: if (start_write_i) begin
                AW_VALID <= 1'b1;
                AW_ADDR  <= addr_i;
            end

            AW_WRITE: begin
                W_VALID  <= 1'b1;
                AW_VALID <= 1'b0;
                W_DATA   <= data_i;
            end 

            WRITE: if (W_READY) begin
                W_VALID <= 1'b0;
                B_READY <= 1'b1;
            end

            RESP: if (B_VALID) B_READY <= 1'b0;
              
            default: begin
                AW_VALID <= 1'b0;
                AW_ADDR  <= addr_i;
                W_VALID  <= 1'b0;
                B_READY  <= 1'b0;
            end
        endcase
    end

    // Output signals.
    assign write_fault_o = B_RESP[1] & B_VALID;
    assign done_o        = (PS == RESP) & B_VALID;
    
endmodule
