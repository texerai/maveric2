/* Copyright (c) 2024-2026 Maveric NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
// Create Date  : 26/06/2026
// Last Revision: 30/06/2026
//------------------------------

`ifndef PIPELINE_STAGE_PKG_SV
`define PIPELINE_STAGE_PKG_SV

package pipeline_stage_pkg;

    localparam int unsigned ADDR_WIDTH  = 64;
    localparam int unsigned DATA_WIDTH  = 64;
    localparam int unsigned INSTR_WIDTH = 32;
    localparam int unsigned REG_ADDR_W  = 5;
    localparam int unsigned CSR_ADDR_W  = 12;

    typedef struct packed {
        logic [INSTR_WIDTH - 1:0] instruction;
        logic                     valid;
        logic [ADDR_WIDTH  - 1:0] pc_plus4;
        logic [ADDR_WIDTH  - 1:0] pc;
        logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred;
        logic [              1:0] btb_way;
        logic                     branch_pred_taken;
        logic                     log_trace;
    } if_id_t;

    typedef struct packed {
        logic [              2:0] result_src;
        logic [              4:0] alu_control;
        logic                     mem_we;
        logic                     reg_we;
        logic                     csr_we;
        logic                     alu_srcA;
        logic [              1:0] alu_srcB;
        logic                     branch;
        logic                     jump;
        logic                     pc_target_src;
        logic [ADDR_WIDTH  - 1:0] pc_plus4;
        logic [ADDR_WIDTH  - 1:0] pc;
        logic [DATA_WIDTH  - 1:0] imm_ext;
        logic [DATA_WIDTH  - 1:0] rs1_data;
        logic [DATA_WIDTH  - 1:0] rs2_data;
        logic [REG_ADDR_W  - 1:0] rs1_addr;
        logic [REG_ADDR_W  - 1:0] rs2_addr;
        logic [REG_ADDR_W  - 1:0] rd_addr;
        logic [CSR_ADDR_W  - 1:0] csr_addr;
        logic [              2:0] func3;
        logic [              1:0] forward_src;
        logic                     mem_access;
        logic                     csr_access;
        logic [ADDR_WIDTH  - 1:0] pc_target_addr_pred;
        logic [              1:0] btb_way;
        logic                     branch_pred_taken;
        logic [INSTR_WIDTH - 1:0] instruction_log;
        logic                     trap_detected;
        logic [              5:0] trap_cause;
        logic                     trap_mret;
        logic                     trap_sret;
        logic                     load_instr;
        logic                     atomic_lr;
        logic                     atomic_sc;
        logic                     atomic_amo_op;
        logic [              4:0] atomic_alu_op;
        logic                     fencei;
        logic                     is_mdu_op;
        logic                     is_mdu_word_op;
        logic                     log_trace;
    } id_ex_t;

    typedef struct packed {
        logic [              2:0] result_src;
        logic                     mem_we;
        logic                     reg_we;
        logic                     csr_we;
        logic [ADDR_WIDTH  - 1:0] pc_plus4;
        logic [ADDR_WIDTH  - 1:0] pc_target_addr;
        logic [DATA_WIDTH  - 1:0] imm_ext;
        logic [DATA_WIDTH  - 1:0] alu_result;
        logic [DATA_WIDTH  - 1:0] wdata;
        logic [              1:0] forward_src;
        logic [              2:0] func3;
        logic                     mem_access;
        logic [DATA_WIDTH  - 1:0] rs2_data;
        logic                     atomic_lr;
        logic                     atomic_sc;
        logic                     atomic_amo_op;
        logic [              4:0] atomic_alu_op;
        logic                     fencei;
        logic                     trap_detected;
        logic [              5:0] trap_cause;
        logic                     trap_mret;
        logic                     trap_sret;
        logic [REG_ADDR_W  - 1:0] rd_addr;
        logic [CSR_ADDR_W  - 1:0] csr_waddr;
        logic [DATA_WIDTH  - 1:0] csr_rdata;
        logic [INSTR_WIDTH - 1:0] instruction_log;
        logic [ADDR_WIDTH  - 1:0] pc_log;
        logic                     log_trace;
    } ex_mem_t;

    typedef struct packed {
        logic [              2:0] result_src;
        logic                     reg_we;
        logic                     csr_we;
        logic [ADDR_WIDTH  - 1:0] pc_plus4;
        logic [ADDR_WIDTH  - 1:0] pc_target_addr;
        logic [DATA_WIDTH  - 1:0] imm_ext;
        logic [DATA_WIDTH  - 1:0] alu_result;
        logic [DATA_WIDTH  - 1:0] rdata;
        logic                     trap_detected;
        logic [              5:0] trap_cause;
        logic                     trap_mret;
        logic                     trap_sret;
        logic [REG_ADDR_W  - 1:0] rd_addr;
        logic [CSR_ADDR_W  - 1:0] csr_waddr;
        logic [DATA_WIDTH  - 1:0] csr_rdata;
        logic [INSTR_WIDTH - 1:0] instruction_log;
        logic [ADDR_WIDTH  - 1:0] pc_log;
        logic [ADDR_WIDTH  - 1:0] mem_addr_log;
        logic [DATA_WIDTH  - 1:0] mem_wdata_log;
        logic                     mem_we_log;
        logic                     mem_access_log;
        logic                     log_trace;
    } mem_wb_t;

endpackage

`endif
