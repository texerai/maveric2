/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------------
// This is cache fsm module that implements mechanism for caching data from main memory that
// reads and writes data to main memory by communication with them through AXI4-Lite interace. 
// --------------------------------------------------------------------------------------------

module cache_fsm
(
    // Input interface.
    input  logic clk_i,
    input  logic arst_i,
    input  logic icache_hit_i,
    input  logic dcache_hit_i,
    input  logic dcache_dirty_i,
    input  logic axi_done_i,
    input  logic mem_access_i,
    input  logic branch_mispred_exec_i,

    // Output interface.
    output logic stall_cache_o,
    output logic instr_we_o,
    output logic dcache_we_o,
    output logic axi_write_start_o,
    output logic axi_read_start_icache_o,
    output logic axi_read_start_dcache_o
);

    //------------------------------------
    // Internal nets.
    //------------------------------------
    logic stall_icache_s;
    logic stall_dcache_s;


    //------------------------------------
    // FSM.
    //------------------------------------

    // FSM states.
    typedef enum logic [1:0]
    {
        IDLE       = 2'b00,
        ALLOCATE_I = 2'b01,
        ALLOCATE_D = 2'b10,
        WRITE_BACK = 2'b11
    } t_state;

    t_state PS;
    t_state NS;


    // FSM: PS syncronization.
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) PS <= IDLE;
        else        PS <= NS;
    end

    
    // FSM: NS logic.
    always_comb begin
        // Default value.
        NS = PS;

        case (PS)
            IDLE: begin
                if (~ dcache_hit_i & mem_access_i) begin
                    if (dcache_dirty_i) NS = WRITE_BACK;
                    else                NS = ALLOCATE_D;
                end
                else if (branch_mispred_exec_i) NS = PS;
                else if (~ icache_hit_i       ) NS = ALLOCATE_I;
                else                            NS = PS;
            end
            ALLOCATE_I: if (axi_done_i ) NS = IDLE;
            ALLOCATE_D: if (axi_done_i ) NS = IDLE;
            WRITE_BACK: if (axi_done_i ) NS = ALLOCATE_D;
            default: NS = PS;
        endcase
    end


    // FSM: Output logic.
    always_comb begin
        // Default values.
        stall_icache_s          = 1'b0;
        stall_dcache_s          = 1'b0;
        instr_we_o              = 1'b0;
        dcache_we_o             = 1'b0;
        axi_write_start_o       = 1'b0;
        axi_read_start_icache_o = 1'b0;
        axi_read_start_dcache_o = 1'b0;

        case ( PS )
            IDLE: begin
                stall_icache_s = (~ icache_hit_i) & (~ branch_mispred_exec_i);
                stall_dcache_s = (~ dcache_hit_i & mem_access_i);
            end

            ALLOCATE_I: begin
                stall_icache_s          = 1'b1;
                instr_we_o              = axi_done_i;
                axi_read_start_icache_o = ~ axi_done_i;
            end 

            ALLOCATE_D: begin
                stall_dcache_s          = 1'b1;
                dcache_we_o             = axi_done_i;
                axi_read_start_dcache_o = ~ axi_done_i;
            end 

            WRITE_BACK: begin
                stall_dcache_s    = 1'b1;
                axi_write_start_o = ~ axi_done_i;
            end

            default: begin
                stall_icache_s          = 1'b0;
                stall_dcache_s          = 1'b0;
                instr_we_o              = 1'b0;
                dcache_we_o             = 1'b0;
                axi_write_start_o       = 1'b0;
                axi_read_start_icache_o = 1'b0;
                axi_read_start_dcache_o = 1'b0;
            end
        endcase
    end


    //------------------------------------
    // Output logic.
    //------------------------------------
    assign stall_cache_o = stall_icache_s | stall_dcache_s;
    
endmodule
