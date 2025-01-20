/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ----------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Slave module implementation for communication with outside memory for read operations.
// ----------------------------------------------------------------------------------------------------------

module axi4_lite_slave_read
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    // Control signals.
    input  logic                          clk,
    input  logic                          arst,

    // Input interface.
    input  logic [ AXI_DATA_WIDTH - 1:0 ] i_data,
    input  logic                          i_start_read,
    input  logic                          i_successful_access,
    input  logic                          i_successful_read,

    // Output interface. 
    output logic [ AXI_ADDR_WIDTH - 1:0 ] o_addr,

    //--------------------------------------
    // AXI Interface signals: READ CHANNEL
    //--------------------------------------

    // Read Channel: Address.
    input  logic                            AR_VALID,
    input  logic [ AXI_ADDR_WIDTH   - 1:0 ] AR_ADDR,
    input  logic [                    2:0 ] AR_PROT,
    output logic                            AR_READY,

    // Read Channel: Data.
    input  logic                            R_READY,
    output logic [ AXI_DATA_WIDTH   - 1:0 ] R_DATA,
    output logic [                    1:0 ] R_RESP,
    output logic                            R_VALID
);

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
            IDLE   : if ( i_start_read                    ) NS = AR_READ;
            AR_READ: if ( AR_VALID & AR_READY             ) NS = READ;
            READ   : if ( i_successful_access & R_READY   ) NS = RESP;
            RESP   :                            NS = IDLE;
            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @( posedge clk, posedge arst ) begin
        if ( arst ) begin
            AR_READY <= '0;
            R_DATA   <= '0;
            R_VALID  <= '0;
            R_RESP   <= '0;
            o_addr   <= '0;
        end

        case ( PS )
            IDLE: if ( i_start_read ) begin
                AR_READY <= '1;
                R_RESP   <= 2'b00;
            end

            AR_READ: if ( AR_VALID ) begin
                o_addr   <= AR_ADDR;
                AR_READY <= '0;
            end 

            READ: if ( i_successful_access ) begin
                    R_VALID <= '1;
                    R_DATA  <= i_data;
                    if ( i_successful_read ) R_RESP <= 2'b00;
                    else                     R_RESP <= 2'b10;
                end

            default: begin
                R_RESP   <= R_RESP; 
                AR_READY <= '0;
                R_DATA   <= i_data;
                R_VALID  <= '0;
                o_addr   <= AR_ADDR;
            end 
        endcase
    end
    
endmodule