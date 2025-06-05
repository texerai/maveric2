/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Master module implementation for communication with outside memory for read operations.
// ------------------------------------------------------------------------------------------------------------

module axi4_lite_master_read
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
    input  logic                        start_read_i,

    // Output interface. 
    output logic [AXI_DATA_WIDTH - 1:0] data_o,
    output logic                        access_fault_o,
    output logic                        done_o,

    //--------------------------------------
    // AXI Interface signals: READ CHANNEL
    //--------------------------------------

    // Read Channel: Address. Ignored AR_ID for now.
    input  logic                          AR_READY,
    output logic                          AR_VALID,
    output logic [AXI_ADDR_WIDTH   - 1:0] AR_ADDR,
    output logic [                   2:0] AR_PROT,

    // Read Channel: Data. Ignored R_ID for now.
    input  logic [AXI_DATA_WIDTH   - 1:0] R_DATA,
    input  logic [                   1:0] R_RESP,
    input  logic                          R_VALID,
    output logic                          R_READY
);

    //-------------------------
    // Continious assignments.
    //-------------------------
    assign AR_PROT  = 3'b100; // Random value. NOT FINAL VALUE.

    //-------------------------
    // Read FSM.
    //-------------------------

    // FSM: States.
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        AR_READ = 2'b01,
        READ    = 2'b10,
        RESP    = 2'b11
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
            IDLE   : if (start_read_i       ) NS = AR_READ;
            AR_READ: if (AR_VALID & AR_READY) NS = READ;
            READ   : if (R_VALID & R_READY  ) NS = RESP;
            RESP   :                          NS = IDLE;
            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            AR_VALID <= '0;
            AR_ADDR  <= '0;
            R_READY  <= '0;
            data_o   <= '0;
        end

        case (PS)
            IDLE: if (start_read_i) begin
                AR_VALID <= '1;
                AR_ADDR  <= addr_i;
            end

            AR_READ: begin
                R_READY  <= '1;
                AR_VALID <= '0;
            end 

            READ: if (R_VALID) begin
                data_o  <= R_DATA;
                R_READY <= '0;
            end 

            default: begin
                AR_VALID <= '0;
                AR_ADDR  <= addr_i;
                R_READY  <= '0;
            end
        endcase
    end

    // Output signals.
    assign access_fault_o = R_RESP[1];
    assign done_o         = (PS == RESP);
    
endmodule
