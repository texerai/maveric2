/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 20/01/2025
// Last Revision: 15/07/2026
//------------------------------

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
    input  logic fencei_wb_start_i,
    input  logic axi_done_i,
    input  logic mem_access_i,
    input  logic other_stall_i,
    input  logic mmio_access_i,
    input  logic mmio_access_type_i,

    // Output interface.
    output logic stall_cache_o,
    output logic mmio_stall_o,
    output logic mmio_write_start_o,
    output logic mmio_read_start_o,
    output logic instr_we_o,
    output logic dcache_we_o,
    output logic fencei_wb_done_o,
    output logic fencei_wb_done_full_o,
    output logic axi_write_start_o,
    output logic axi_read_start_icache_o,
    output logic axi_read_start_dcache_o
);

    //------------------------------------
    // Internal nets.
    //------------------------------------
    logic stall_icache;
    logic stall_dcache;


    //------------------------------------
    // FSM.
    //------------------------------------

    // FSM states.
    typedef enum logic [2:0]
    {
        IDLE           = 3'b000,
        ALLOCATE_I     = 3'b001,
        ALLOCATE_D     = 3'b010,
        WRITE_BACK     = 3'b011,
        MMIO           = 3'b100,
        WB_FENCEI      = 3'b101,
        WB_FENCEI_DONE = 3'b110
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
                if (fencei_wb_start_i) begin
                    NS = WB_FENCEI;
                end
                else if (~ dcache_hit_i & mem_access_i) begin
                    if (dcache_dirty_i) NS = WRITE_BACK;
                    else                NS = ALLOCATE_D;
                end
                else if (mmio_access_i & ~mmio_grant) NS = MMIO;
                else if (other_stall_i              ) NS = PS;
                else if (~ icache_hit_i             ) NS = ALLOCATE_I;
                else                                  NS = PS;
            end
            ALLOCATE_I: if (axi_done_i) NS = IDLE;
            ALLOCATE_D: if (axi_done_i) NS = IDLE;
            WRITE_BACK: if (axi_done_i) NS = ALLOCATE_D;
            MMIO      : if (axi_done_i) begin
                if (~icache_hit_i) NS = ALLOCATE_I;
                else               NS = IDLE;
            end
            WB_FENCEI: begin
                if (~fencei_wb_start_i) NS = WB_FENCEI_DONE;
                else if (~dcache_dirty_i | axi_done_i) NS = IDLE;
            end
            WB_FENCEI_DONE: NS = IDLE;
            default: NS = PS;
        endcase
    end


    // FSM: Output logic.
    always_comb begin
        // Default values.
        stall_icache            = 1'b0;
        stall_dcache            = 1'b0;
        mmio_stall_o            = 1'b0;
        mmio_write_start_o      = 1'b0;
        mmio_read_start_o       = 1'b0;
        instr_we_o              = 1'b0;
        dcache_we_o             = 1'b0;
        fencei_wb_done_o        = 1'b0;
        axi_write_start_o       = 1'b0;
        axi_read_start_icache_o = 1'b0;
        axi_read_start_dcache_o = 1'b0;
        fencei_wb_done_full_o   = 1'b0;

        case ( PS )
            IDLE: begin
                stall_icache = (~ icache_hit_i) & (~other_stall_i) & (~mmio_access_i);
                stall_dcache = (~ dcache_hit_i & mem_access_i) | fencei_wb_start_i;
                mmio_stall_o = mmio_access_i & (~mmio_grant);
            end

            ALLOCATE_I: begin
                stall_icache            = 1'b1;
                instr_we_o              = axi_done_i;
                axi_read_start_icache_o = ~ axi_done_i;
            end

            ALLOCATE_D: begin
                stall_dcache            = 1'b1;
                dcache_we_o             = axi_done_i;
                axi_read_start_dcache_o = ~ axi_done_i;
            end

            WRITE_BACK: begin
                stall_dcache      = 1'b1;
                axi_write_start_o = ~ axi_done_i;
            end

            MMIO: begin
                stall_icache = axi_done_i & (~icache_hit_i);
                mmio_stall_o = (~axi_done_i);
                mmio_write_start_o = (~axi_done_i) & mmio_access_type_i;
                mmio_read_start_o  = (~axi_done_i) & (~mmio_access_type_i);
            end

            WB_FENCEI: begin
                stall_dcache      = 1'b1;
                axi_write_start_o = dcache_dirty_i & (~ axi_done_i);
                fencei_wb_done_o  = ~dcache_dirty_i | axi_done_i;
            end
            WB_FENCEI_DONE: begin
                fencei_wb_done_full_o = 1'b1;
            end
            default: begin
                stall_icache            = 1'b0;
                stall_dcache            = 1'b0;
                mmio_stall_o            = 1'b0;
                mmio_write_start_o      = 1'b0;
                mmio_read_start_o       = 1'b0;
                instr_we_o              = 1'b0;
                dcache_we_o             = 1'b0;
                axi_write_start_o       = 1'b0;
                axi_read_start_icache_o = 1'b0;
                axi_read_start_dcache_o = 1'b0;
                fencei_wb_done_full_o   = 1'b0;
            end
        endcase
    end


    logic mmio_grant;

    always_ff @(posedge clk_i, posedge arst_i) begin
        if      (arst_i    ) mmio_grant <= 1'b0;
        else if (axi_done_i) mmio_grant <= 1'b1;
        else if (PS == IDLE) mmio_grant <= 1'b0;
    end


    //------------------------------------
    // Output logic.
    //------------------------------------
    assign stall_cache_o = stall_icache | stall_dcache;

endmodule
