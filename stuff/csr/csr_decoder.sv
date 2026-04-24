// CSR Instruction Decoder
// Decodes csrrw{i}, csrrs{i}, csrrc{i} instructions

/*

1. CSR decode in ID alongside main decode: a mux selects which decoder's outputs populate the ID/EX register based on the opcode
2. CSR read in EX, write committed in WB
3. Hazard unit stalls on CSR RAW (detect in ID when EX or MEM/WB stages hold a csr_we to the same address)
4. csr_illegal_o from your decoder gets OR'd into the exception vector in EX, raising an illegal instruction trap

The output signals from both decoders propagate through the pipeline.
In EX stage, CSR decoder's output signals are connected to the CSR file
and main decoder's output signals are wired as usual,
and depending on is_csr_instr_i either ALU or CSR File is activated

ID/EX register holds:
  from main_decoder:  alu_op, alu_src, reg_we, ...
  from csr_decoder:   csr_addr, csr_op, csr_we, ...
  shared:             rs1_data, rs2_data, rs1_uim, is_csr_instr

EX stage:
  is_csr_instr = 0 → ALU activated,      CSR file idle
  is_csr_instr = 1 → ALU idle,           CSR file activated
                      result mux ← ALU   result mux ← CSR read data

In future work, integrate CSR decoder into the main decoder for more efficient hardware sharing, but for now we keep it separate for clarity and modularity.
*/

module csr_decoder
(
    // Input interface.
    input  logic [           31:0]   instruction_i,
    input  logic                     is_csr_instr_i,

    // Output interface.
    output logic [           11:0]   csr_addr_o,
    output logic [            1:0]   csr_op_o,  // 01=RW, 10=RS, 11=RC
    output logic [            4:0]   rs1_uim_o,
    output logic                     csr_we_o,
    output logic                     csr_illegal_o
);

    // CSR Instruction Format (I-Type variant)
    // [31:20] = CSR Address
    // [19:15] = RS1 (or UIMM[4:0] for CSRR*I)
    // [14:12] = funct3 (CSR operation)
        // funct3[1:0]   -> operation: 01=W, 10=S, 11=C
        // funct3[2]     -> source: 0=RS1, 1=UIMM
    // [11:7]  = RD
    // [6:0]   = Opcode (1110011 = SYSTEM)

    logic       opcode_valid_s;
    logic [2:0] funct3_s;
    logic       is_imm_s; // CSRR*I variant
    logic [1:0] op_s; // funct3[1:0] maps directly to csr_op

    assign csr_addr_o = instruction_i[31:20];
    assign rs1_uim_o  = instruction_i[19:15];
    assign funct3_s   = instruction_i[14:12];

    assign opcode_valid_s = (instruction_i[6:0] == 7'b1110011);
    assign is_imm_s = funct3_s[2];
    assign op_s = funct3_s[1:0]; // 01=W, 10=S, 11=C

    // output logic (csr_op and csr_we_o, and csr_illegal_o)

    assign csr_op_o = op_s;

    // Write enable logic:
    // CSRRW/I -> always writes
    // CSRRS/I -> writes only if rs1_uim != 0 (otherwise read-only alias)
    // CSRCW/I -> writes only if rs1_uim != 0 (otherwise read-only alias)

    assign csr_we_o = is_csr_instr_i & ~csr_illegal_o &
                        ( (op_s == 2'b01) | (rs1_uim_o != 5'b0) );

    // Illegal: not a CSR instruction, bad opcode, or reserved funct3
    // funct3 = 000, 100 are unassigned in the CSR encoding space
    assign csr_illegal_o = ~is_csr_instr_i
                            | ~opcode_valid_s
                            | (op_s == 2'b00); // 00 is not a valid CSR operation

    


endmodule