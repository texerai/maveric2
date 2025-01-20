/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Master module implementation for communication with outside memory for read operations.
// ------------------------------------------------------------------------------------------------------------

module axi4_lite_master_read
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    // Control signals.
    input  logic                          clk,
    input  logic                          arst,

    // Input interface.
    input  logic [ AXI_ADDR_WIDTH - 1:0 ] i_addr,
    input  logic                          i_start_read,

    // Output interface. 
    output logic [ AXI_DATA_WIDTH - 1:0 ] o_data,
    output logic                          o_access_fault,
    output logic                          o_done,

    //--------------------------------------
    // AXI Interface signals: READ CHANNEL
    //--------------------------------------

    // Read Channel: Address. Ignored AR_ID for now.
    input  logic                            AR_READY,
    output logic                            AR_VALID,
    output logic [ AXI_ADDR_WIDTH   - 1:0 ] AR_ADDR,
    output logic [                    2:0 ] AR_PROT,

    // Read Channel: Data. Ignored R_ID for now.
    input  logic [ AXI_DATA_WIDTH   - 1:0 ] R_DATA,
    input  logic [                    1:0 ] R_RESP, 
    input  logic                            R_VALID,
    output logic                            R_READY
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
    always_ff @( posedge clk, posedge arst ) begin 
        if ( arst ) begin
            PS <= IDLE;
        end
        else PS <= NS;
    end

    // FSM: Next State Logic.
    always_comb begin
        NS = PS;

        case ( PS )
            IDLE   : if ( i_start_read        ) NS = AR_READ;
            AR_READ: if ( AR_VALID & AR_READY ) NS = READ;
            READ   : if ( R_VALID & R_READY   ) NS = RESP;
            RESP   :                            NS = IDLE;
            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @( posedge clk, posedge arst ) begin
        if ( arst ) begin
            AR_VALID <= '0;
            AR_ADDR  <= '0;
            R_READY  <= '0;
            o_data   <= '0;
        end

        case ( PS )
            IDLE: if ( i_start_read ) begin
                AR_VALID <= '1;
                AR_ADDR  <= i_addr;
            end

            AR_READ: begin
                R_READY  <= '1;
                AR_VALID <= '0;
            end 

            READ: if ( R_VALID ) begin
                o_data <= R_DATA;
                R_READY <= '0;
            end 

            default: begin
                AR_VALID <= '0;
                AR_ADDR  <= i_addr;
                R_READY  <= '0;
            end
        endcase
    end

    // Output signals.
    assign o_access_fault = R_RESP[1];
    assign o_done         = ( PS == RESP );
    
endmodule