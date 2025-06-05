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
    input  logic                    clk_i,
    input  logic                    arst_i,
    input  logic                    stall_fetch_i,
    input  logic                    branch_instr_i,
    input  logic                    branch_taken_i,
    input  logic [             1:0] way_write_i,
    input  logic [ADDR_WIDTH - 1:0] pc_i,
    input  logic [ADDR_WIDTH - 1:0] pc_exec_i,
    input  logic [ADDR_WIDTH - 1:0] pc_target_addr_exec_i,

    // Output logic.
    output logic                    branch_pred_taken_o,
    output logic [             1:0] way_write_o,
    output logic [ADDR_WIDTH - 1:0] pc_target_addr_pred_o
);

    //---------------------------------
    // Localparameters for BTB.
    //---------------------------------
    localparam SET_COUNT         = 16;
    localparam N                 = 4;
    localparam INDEX_WIDTH       = $clog2 (SET_COUNT);                           // 2 bit.
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
    localparam INDEX_WIDTH_BHT = $clog2(SET_COUNT_BHT);
    localparam SATUR_COUNT_W   = 2;



    //---------------------------------
    // Internal nets.
    //---------------------------------

    // BTB.
    logic [BIA_WIDTH   - 1:0] bia_write_s;
    logic [INDEX_WIDTH - 1:0] index_write_s;
    logic                     btb_hit_s;

    // BHT.
    logic bht_taken_s;



    //-----------------------------------
    // Continious assignments.
    //-----------------------------------
    assign bia_write_s   = pc_exec_i[BIA_MSB  :BIA_LSB  ];
    assign index_write_s = pc_exec_i[INDEX_MSB:INDEX_LSB];


    //----------------------------------
    // Lower Level Modules: BTB, BHT.
    //----------------------------------

    // BTB.
    btb # (
        .SET_COUNT   (SET_COUNT  ),
        .N           (N          ),
        .INDEX_WIDTH (INDEX_WIDTH),
        .BIA_WIDTH   (BIA_WIDTH  ),
        .ADDR_WIDTH  (ADDR_WIDTH )
    ) BTB0 (
        .clk_i          (clk_i                ),
        .arst_i         (arst_i               ),
        .stall_fetch_i  (stall_fetch_i        ),
        .branch_taken_i (branch_taken_i       ),
        .target_addr_i  (pc_target_addr_exec_i),
        .pc_i           (pc_i                 ),
        .way_write_i    (way_write_i          ),
        .bia_write_i    (bia_write_s          ),
        .index_write_i  (index_write_s        ),
        .hit_o          (btb_hit_s            ),
        .way_write_o    (way_write_o          ),
        .target_addr_o  (pc_target_addr_pred_o)
    );

    // BHT.
    bht # (
        .SET_COUNT     (SET_COUNT_BHT  ),
        .INDEX_WIDTH   (INDEX_WIDTH_BHT),
        .SATUR_COUNT_W (SATUR_COUNT_W  )
    ) BHT0 (
        .clk_i            (clk_i                            ),
        .arst_i           (arst_i                           ),
        .stall_fetch_i    (stall_fetch_i                    ),
        .bht_update_i     (branch_instr_i                   ),
        .branch_taken_i   (branch_taken_i                   ),
        .set_index_i      (pc_i      [INDEX_WIDTH_BHT + 1:2]),
        .set_index_exec_i (pc_exec_i [INDEX_WIDTH_BHT + 1:2]),
        .bht_pred_taken_o (bht_taken_s                      )
    );


    //----------------
    // Output logic.
    //----------------
    assign branch_pred_taken_o = btb_hit_s & bht_taken_s;


endmodule
