/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// ------------------------------------------------------------------------------------
// This is a branch prediction module. It comprises of BHT & BTB modules.
// ------------------------------------------------------------------------------------

module branch_pred_unit 
#(
    parameter ADDR_WIDTH = 64
)
(
    // Input interface.
    input  logic                      i_clk,
    input  logic                      i_arst,
    input  logic                      i_stall_fetch,
    input  logic                      i_branch_instr,
    input  logic                      i_branch_taken,
    input  logic [              1:0 ] i_way_write,
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc,
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc_exec,
    input  logic [ ADDR_WIDTH - 1:0 ] i_pc_target_exec,

    // Output logic.
    output logic                      o_branch_pred_taken,
    output logic [              1:0 ] o_way_write,
    output logic [ ADDR_WIDTH - 1:0 ] o_pc_target_pred
);

    //---------------------------------
    // Localparameters for BTB.
    //---------------------------------
    localparam SET_COUNT         = 16;
    localparam N                 = 4;
    localparam INDEX_WIDTH       = $clog2 ( SET_COUNT );                         // 2 bit.
    localparam BIA_WIDTH         = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET_WIDTH; // 60 bit.
    localparam BYTE_OFFSET_WIDTH = 2;
    
    localparam BIA_MSB   = ADDR_WIDTH - 1;              // 63.
    localparam BIA_LSB   = BIA_MSB - BIA_WIDTH + 1;     // 4.
    localparam INDEX_MSB = BIA_LSB - 1;                 // 3.
    localparam INDEX_LSB = INDEX_MSB - INDEX_WIDTH + 1; // 2.


    //---------------------------------
    // Localparams for BHT.
    //---------------------------------
    localparam SET_COUNT_BHT   = 64;
    localparam INDEX_WIDTH_BHT = $clog2 ( SET_COUNT_BHT );
    localparam SATUR_COUNT_W   = 2;



    //---------------------------------
    // Internal nets.
    //---------------------------------

    // BTB.
    logic [ BIA_WIDTH   - 1:0 ] s_bia_write; 
    logic [ INDEX_WIDTH - 1:0 ] s_index_write;
    logic                       s_btb_hit;

    // BHT.
    logic s_bht_taken;



    //-----------------------------------
    // Continious assignments.
    //-----------------------------------
    assign s_bia_write   = i_pc_exec [ BIA_MSB   : BIA_LSB   ];
    assign s_index_write = i_pc_exec [ INDEX_MSB : INDEX_LSB ];


    //----------------------------------
    // Lower Level Modules: BTB, BHT.
    //----------------------------------

    // BTB.
    btb # (
        .SET_COUNT   ( SET_COUNT   ),
        .N           ( N           ),
        .INDEX_WIDTH ( INDEX_WIDTH ),
        .BIA_WIDTH   ( BIA_WIDTH   ),
        .ADDR_WIDTH  ( ADDR_WIDTH  )
    ) BTB0 (
        .i_clk          ( i_clk            ),
        .i_arst         ( i_arst           ),
        .i_stall_fetch  ( i_stall_fetch    ),
        .i_branch_taken ( i_branch_taken   ),
        .i_target_addr  ( i_pc_target_exec ),
        .i_pc           ( i_pc             ),
        .i_way_write    ( i_way_write      ),
        .i_bia_write    ( s_bia_write      ),
        .i_index_write  ( s_index_write    ),
        .o_hit          ( s_btb_hit        ),
        .o_way_write    ( o_way_write      ),
        .o_target_addr  ( o_pc_target_pred )
    );

    // BHT.
    bht # (
        .SET_COUNT     ( SET_COUNT_BHT   ),
        .INDEX_WIDTH   ( INDEX_WIDTH_BHT ),
        .SATUR_COUNT_W ( SATUR_COUNT_W   )
    ) BHT0 (
        .i_clk            ( i_clk             ),
        .i_arst           ( i_arst            ),
        .i_stall_fetch    ( i_stall_fetch     ),
        .i_bht_update     ( i_branch_instr    ),
        .i_branch_taken   ( i_branch_taken    ),
        .i_set_index      ( i_pc      [ INDEX_WIDTH_BHT + 1:2 ] ),
        .i_set_index_exec ( i_pc_exec [ INDEX_WIDTH_BHT + 1:2 ] ),
        .o_bht_pred_taken ( s_bht_taken       )
    );


    //----------------
    // Output logic.
    //----------------
    assign o_branch_pred_taken = s_btb_hit & s_bht_taken;


endmodule