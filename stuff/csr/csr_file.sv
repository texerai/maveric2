// CSR File: Stores Machine and Supervisor CSRs

module csr_file
#(
    parameter DATA_WIDTH = 64,
    parameter CSR_ADDR_W = 12
)
(
    // Control signals.
    input  logic                     clk_i,
    input  logic                     arst_i,

    // Input interface.
    input  logic [            11:0]  csr_addr_read_i,
    input  logic [            11:0]  csr_addr_write_i,
    input  logic [DATA_WIDTH - 1:0]  csr_write_data_i,
    input  logic                     csr_we_i,
    input  logic [             1:0]  csr_op_i, // 0=RW, 1=RS, 2=RC
    input  logic [             1:0]  priv_mode_i,

    // Output interface.
    output logic [DATA_WIDTH - 1:0]  csr_read_data_o,
    output logic                     csr_illegal_access_o,

    // Interrupt signals.
    input  logic                     timer_interrupt_i,
    input  logic                     external_interrupt_i,

    // Exception info.
    input  logic                     exception_i,
    input  logic [DATA_WIDTH - 1:0]  exception_pc_i,
    input  logic [             3:0]  exception_cause_i,

    // Trap return addresses.
    output logic [DATA_WIDTH - 1:0]  mepc_o,
    output logic [DATA_WIDTH - 1:0]  sepc_o,
    output logic [DATA_WIDTH - 1:0]  mtvec_o,
    output logic [DATA_WIDTH - 1:0]  stvec_o,
    output logic [             1:0]  priv_mode_o,
    output logic                     mie_o,
    output logic                     sie_o
);

    // CSR Addresses (RISC-V Standard)

    // M-mode register addresses
    localparam logic [11:0] CSR_MSTATUS   = 12'h300;
    localparam logic [11:0] CSR_MISA      = 12'h301;
    localparam logic [11:0] CSR_MEDELEG   = 12'h302;
    localparam logic [11:0] CSR_MIDELEG   = 12'h303;
    localparam logic [11:0] CSR_MIE       = 12'h304;
    localparam logic [11:0] CSR_MTVEC     = 12'h305;

    localparam logic [11:0] CSR_MSCRATCH  = 12'h340;
    localparam logic [11:0] CSR_MEPC      = 12'h341;
    localparam logic [11:0] CSR_MCAUSE    = 12'h342;
    localparam logic [11:0] CSR_MTVAL     = 12'h343;
    localparam logic [11:0] CSR_MIP       = 12'h344;

    localparam logic [11:0] CSR_MCYCLE    = 12'hB00;
    localparam logic [11:0] CSR_MCYCLEH   = 12'hB80; // RV32 compatibility (optional)
    localparam logic [11:0] CSR_MTIME     = 12'hC01;
    localparam logic [11:0] CSR_MTIMECMP  = 12'h2C0;

    localparam logic [11:0] CSR_MCOUNTEREN = 12'h306;

    localparam logic [11:0] CSR_MHARTID   = 12'hF14;
    localparam logic [11:0] CSR_MVENDORID = 12'hF11;
    localparam logic [11:0] CSR_MARCHID   = 12'hF12;
    localparam logic [11:0] CSR_MIMPID    = 12'hF13;

    // S-mode register addresses
    localparam logic [11:0] CSR_SSTATUS   = 12'h100;
    localparam logic [11:0] CSR_SIE       = 12'h104;
    localparam logic [11:0] CSR_STVEC     = 12'h105;

    localparam logic [11:0] CSR_SSCRATCH  = 12'h140;
    localparam logic [11:0] CSR_SEPC      = 12'h141;
    localparam logic [11:0] CSR_SCAUSE    = 12'h142;
    localparam logic [11:0] CSR_STVAL     = 12'h143;
    localparam logic [11:0] CSR_SIP       = 12'h144;

    localparam logic [11:0] CSR_SCOUNTEREN = 12'h106;
    localparam logic [11:0] CSR_SATP      = 12'h180;
    
    // U-mode register addresses
    localparam logic [11:0] CSR_CYCLE    = 12'hC00;
    localparam logic [11:0] CSR_TIME     = 12'hC01;
    localparam logic [11:0] CSR_INSTRET  = 12'hC02;    

    // Internal CSR storage and logic.

    // Privilege Modes
    localparam PRIV_U = 2'b00;
    localparam PRIV_S = 2'b01;
    localparam PRIV_M = 2'b11;

    logic [             1:0] priv_mode; // Current privilege mode

    // CSR Storage (only essential subset for minimal Linux)
    
    // M-mode
    logic [DATA_WIDTH - 1:0] mstatus_r;  // Machine Status
    logic [DATA_WIDTH - 1:0] misa_r;     // Machine ISA Register
    logic [DATA_WIDTH - 1:0] medeleg_r;  // Machine Exception Delegation
    logic [DATA_WIDTH - 1:0] mideleg_r;  // Machine Interrupt Delegation
    logic [DATA_WIDTH - 1:0] mie_r;      // Machine Interrupt Enable
    logic [DATA_WIDTH - 1:0] mip_r;      // Machine Interrupt Pending
    logic [DATA_WIDTH - 1:0] mtvec_r;    // Machine Trap Vector
    logic [DATA_WIDTH - 1:0] mscratch_r; // Machine Scratch Register
    logic [DATA_WIDTH - 1:0] mepc_r;     // Machine Exception PC
    logic [DATA_WIDTH - 1:0] mcause_r;   // Machine Exception Cause
    logic [DATA_WIDTH - 1:0] mtval_r;    // Machine Trap Value (e.g. bad address)
    logic [DATA_WIDTH - 1:0] mcounteren_r; // Machine Counter Enable (for performance counters)
    logic [DATA_WIDTH - 1:0] mhartid_r;   // Machine Hart ID (read-only)
    logic [DATA_WIDTH - 1:0] mvendorid_r; // Machine Vendor ID (read-only)
    logic [DATA_WIDTH - 1:0] marchid_r;   // Machine Architecture ID (read-only)
    logic [DATA_WIDTH - 1:0] mimpid_r;    // Machine Implementation ID (read-only)

    logic [DATA_WIDTH - 1:0] mtimecmp_r; // Machine Timer Compare
    logic [DATA_WIDTH - 1:0] mtime_r;    // Machine Time (read-only, incremented externally)

    // S-mode
    logic [DATA_WIDTH - 1:0] sstatus_r;  // Supervisor Status
    logic [DATA_WIDTH - 1:0] sie_r;      // Supervisor Interrupt Enable
    logic [DATA_WIDTH - 1:0] sip_r;      // Supervisor Interrupt Pending
    logic [DATA_WIDTH - 1:0] stvec_r;    // Supervisor Trap Vector
    logic [DATA_WIDTH - 1:0] sscratch_r; // Supervisor Scratch Register
    logic [DATA_WIDTH - 1:0] sepc_r;     // Supervisor Exception PC
    logic [DATA_WIDTH - 1:0] scause_r;   // Supervisor Exception Cause
    logic [DATA_WIDTH - 1:0] stval_r;    // Supervisor Trap Value (e.g. bad address)

    logic [DATA_WIDTH - 1:0] scounteren_r; // Supervisor Counter Enable (for performance counters)
    logic [DATA_WIDTH - 1:0] satp_r;     // Supervisor Address Translation & Protection

    // U-mode
    logic [DATA_WIDTH - 1:0] cycle_r;    // User Cycle Counter (read-only)
    logic [DATA_WIDTH - 1:0] time_r;     // User Time Counter (read-only)
    logic [DATA_WIDTH - 1:0] instret_r;  // User Instruction Retired Counter (read-only)

    // mstatus Register Fields (RISC-V RV64)
    // [1:0]   = RESERVED
    // [2]     = SIE (Supervisor Interrupt Enable)
    // [3]     = MIE (Machine Interrupt Enable)
    // [5]     = SPIE (Supervisor Previous IE)
    // [7]     = MPIE (Machine Previous IE)
    // [8]     = SPP (Supervisor Previous Privilege)
    // [12:11] = MPP (Machine Previous Privilege)

    function logic [63:0] csr_apply_op;

        input logic [63:0] old_value;
        input logic [63:0] write_value;
        input logic [1:0]   op;   // 0=RW, 1=RS, 2=RC

        begin
            case (op)
                2'b00: csr_apply_op = write_value;               // CSRRW
                2'b01: csr_apply_op = old_value | write_value;  // CSRRS
                2'b10: csr_apply_op = old_value & ~write_value; // CSRRC
                default: csr_apply_op = write_value;
            endcase
        end

    endfunction

    logic [11:0] addr_r, addr_w;
    logic [63:0] data_w;
    logic        we_w;

    // combinational read
    assign csr_read_data_o = csr[csr_addr_read_i];

    // sequential write
    always_ff @(posedge clk_i or posedge arst_i) begin

        if (arst_i) begin
            
            integer i;
            for (i = 0; i < 4096; i++) csr[i] <= 64'b0;
        end

        else if (csr_we_i) begin

            logic [11:0] addr;
            logic [63:0] old;

            addr = csr_addr_write_i;
            old  = csr[addr];
            csr[addr] <= csr_apply_op(old, csr_write_data_i, csr_op_i);
            
        end

    end

    function logic is_trap_csr(input logic [11:0] addr);
        begin
            case (addr)

                12'h300, // mstatus
                12'h341, // mepc
                12'h342, // mcause
                12'h343, // mtval
                12'h100, // sstatus
                12'h141, // sepc
                12'h142:  // scause
                    return 1'b1;

                default:
                    return 1'b0;

            endcase
        end
    endfunction

    function logic is_mmu_csr(input logic [11:0] addr);
        begin
            case (addr)

                12'h180: // satp
                    return 1'b1;

                default:
                    return 1'b0;

            endcase
        end
    endfunction

    function logic is_irq_csr(input logic [11:0] addr);
        begin
            case (addr)

                12'h304, // mie
                12'h344, // mip
                12'h104, // sie
                12'h144:  // sip
                    return 1'b1;

                default:
                    return 1'b0;
                    
            endcase
        end
    endfunction

    function logic is_side_effect_csr(input logic [11:0] addr);
        begin

            if (is_trap_csr(addr)) return 1'b1;
            if (is_mmu_csr(addr))  return 1'b1;
            if (is_irq_csr(addr))  return 1'b1;

            return 1'b0;
            
        end
    endfunction

endmodule