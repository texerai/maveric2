/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// --------------------------------------------------------------------------------------------
// This is cache fsm module that implements mechanism for caching data from main memory that
// reads and writes data to main memory by communication with them through AXI4-Lite interace. 
// --------------------------------------------------------------------------------------------

module cache_fsm
(
    // Input interface.
    input  logic i_clk,
    input  logic i_arst,
    input  logic i_icache_hit,
    input  logic i_dcache_hit,
    input  logic i_dcache_dirty,
    input  logic i_axi_done,
    input  logic i_mem_access,
    input  logic i_branch_mispred_exec,

    // Output interface.
    output logic o_stall_cache,
    output logic o_instr_we,
    output logic o_dcache_we,
    output logic o_axi_write_start,
    output logic o_axi_read_start_icache,
    output logic o_axi_read_start_dcache
);

    //------------------------------------
    // Internal nets.
    //------------------------------------
    logic s_stall_icache;
    logic s_stall_dcache;


    //------------------------------------
    // FSM.
    //------------------------------------

    // FSM states.
    typedef enum logic [ 1:0 ]
    {
        IDLE       = 2'b00,
        ALLOCATE_I = 2'b01,
        ALLOCATE_D = 2'b10,
        WRITE_BACK = 2'b11
    } t_state;

    t_state PS;
    t_state NS;


    // FSM: PS syncronization.
    always_ff @( posedge i_clk, posedge i_arst ) begin
        if ( i_arst ) PS <= IDLE;
        else          PS <= NS;
    end

    
    // FSM: NS logic.
    always_comb begin
        // Default value.
        NS = PS;

        case ( PS )
            IDLE    : begin
                if ( ~ i_dcache_hit & i_mem_access ) begin
                    if ( i_dcache_dirty )  NS = WRITE_BACK;
                    else                   NS = ALLOCATE_D;
                end
                else if ( i_branch_mispred_exec ) NS = PS;
                else if ( ~ i_icache_hit        ) NS = ALLOCATE_I;
                else                              NS = PS;
            end
            ALLOCATE_I: if ( i_axi_done  ) NS = IDLE;
            ALLOCATE_D: if ( i_axi_done  ) NS = IDLE;
            WRITE_BACK: if ( i_axi_done  ) NS = ALLOCATE_D;
            default : NS = PS; 
        endcase
    end


    // FSM: Output logic.
    always_comb begin
        // Default values.
        s_stall_icache          = 1'b0;
        s_stall_dcache          = 1'b0;
        o_instr_we              = 1'b0;
        o_dcache_we             = 1'b0;
        o_axi_write_start       = 1'b0;
        o_axi_read_start_icache = 1'b0;
        o_axi_read_start_dcache = 1'b0;

        case ( PS )
            IDLE: begin
                s_stall_icache = ( ~ i_icache_hit ) & ( ~ i_branch_mispred_exec );
                s_stall_dcache = ( ~ i_dcache_hit & i_mem_access );
            end

            ALLOCATE_I: begin
                s_stall_icache          = 1'b1;
                o_instr_we              = i_axi_done;
                o_axi_read_start_icache = ~ i_axi_done;              
            end 

            ALLOCATE_D: begin
                s_stall_dcache          = 1'b1;
                o_dcache_we             = i_axi_done;
                o_axi_read_start_dcache = ~ i_axi_done;              
            end 

            WRITE_BACK: begin
                s_stall_dcache    = 1'b1;
                o_axi_write_start = ~ i_axi_done;
            end

            default: begin
                s_stall_icache          = 1'b0;
                s_stall_dcache          = 1'b0;
                o_instr_we              = 1'b0;
                o_dcache_we             = 1'b0;
                o_axi_write_start       = 1'b0;
                o_axi_read_start_icache = 1'b0;
                o_axi_read_start_dcache = 1'b0; 
            end
        endcase
    end


    //------------------------------------
    // Output logic.
    //------------------------------------
    assign o_stall_cache = s_stall_icache | s_stall_dcache;
    
endmodule