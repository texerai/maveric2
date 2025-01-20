/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -------------------------------------------------------------------------------------------------------------
// This is a AXI4-Lite Slave module implementation for communication with outside memory for write operations.
// -------------------------------------------------------------------------------------------------------------

module axi4_lite_slave_write
#(
    parameter AXI_ADDR_WIDTH = 64,
              AXI_DATA_WIDTH = 32
) 
(
    // Control signals.
    input  logic                          clk,
    input  logic                          arst,

    // Input interface.
    input  logic                          i_start_write,
    input  logic                          i_successful_access,
    input  logic                          i_successful_write,

    // Output interface. 
    output logic [ AXI_ADDR_WIDTH - 1:0 ] o_addr,
    output logic [ AXI_DATA_WIDTH - 1:0 ] o_data,
    output logic                          o_write_en,

    //--------------------------------------
    // AXI Interface signals: WRITE
    //--------------------------------------

    // Write Channel: Address. Ignored AW_ID for now.
    input  logic                            AW_VALID,
    input  logic [                    2:0 ] AW_PROT,
    input  logic [ AXI_ADDR_WIDTH   - 1:0 ] AW_ADDR,
    output logic                            AW_READY,

    // Write Channel: Data.
    input  logic [ AXI_DATA_WIDTH   - 1:0 ] W_DATA,
    input  logic                            W_VALID,
    input  logic [ AXI_DATA_WIDTH/8 - 1:0 ] W_STRB,
    output logic                            W_READY,

    // Write Channel: Response. Ignored B_ID for now.
    input  logic                            B_READY,
    output logic [                    1:0 ] B_RESP,
    output logic                            B_VALID
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
            IDLE    : if ( i_start_write                   ) NS = AW_WRITE; 
            AW_WRITE: if ( AW_READY & AW_VALID             ) NS = WRITE;
            WRITE   : if ( W_READY  & W_VALID              ) NS = RESP;
            RESP    : if ( B_READY  & i_successful_access  ) NS = WAIT;  
            WAIT    :                                        NS = IDLE;

            default: NS = PS;
        endcase
    end

    // FSM: Output Logic.
    always_ff @( posedge clk, posedge arst ) begin
        if ( arst ) begin
            AW_READY   <= 1'b0;
            o_addr     <= '0;
            o_data     <= '0;
            o_write_en <= 1'b0;
            W_READY    <= 1'b0;
            B_VALID    <= 1'b0;
            B_RESP     <= 2'b0;
        end

        case ( PS )
            IDLE: if ( i_start_write ) begin
                AW_READY <= 1'b1;
            end

            AW_WRITE: if ( AW_VALID ) begin
                o_addr   <= AW_ADDR;
                W_READY  <= 1'b1;
                AW_READY <= 1'b0;
            end 

            WRITE: if ( W_VALID ) begin
                W_READY    <= 1'b0;
                o_write_en <= 1'b1;
                o_data     <= W_DATA;
            end

            RESP: if ( i_successful_access ) begin
                B_VALID    <= 1'b1;
                o_write_en <= 1'b0;
                if ( i_successful_write ) B_RESP <= 2'b00;
                else                      B_RESP <= 2'b10;
            end

            default: begin
                AW_READY   <= 1'b0;
                o_write_en <= 1'b0;
                W_READY    <= 1'b0;
                B_VALID    <= 1'b0;
                B_RESP     <= 2'b0;
            end

              
        endcase
    end
    
endmodule