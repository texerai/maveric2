/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------
// Trap Handler: Routes exceptions/interrupts
// Determines trap vector, manages trap entry/exit
// -----------------------------------------------

module trap_handler
#(
    parameter ADDR_WIDTH = 64,
    parameter PRIV_WIDTH = 2
)
(
    // Control signals.
    input  logic                       clk_i,
    input  logic                       arst_i,

    // Exception/Interrupt Signals (from execute stage & interrupt controller).
    input  logic                       trap_en_i,
    input  logic [              3:0]   trap_cause_i,

    // Trap vector addresses from CSR (mtvec, stvec).
    input  logic [ADDR_WIDTH - 1:0]    mtvec_i,     // Machine trap vector
    input  logic [ADDR_WIDTH - 1:0]    stvec_i,     // Supervisor trap vector

    // Trap return addresses from CSR (mepc, sepc).
    input  logic [ADDR_WIDTH - 1:0]    mepc_i,      // Machine exception PC
    input  logic [ADDR_WIDTH - 1:0]    sepc_i,      // Supervisor exception PC

    // Current privilege level (from privilege_mode.sv).
    input  logic [PRIV_WIDTH - 1:0]    priv_mode_i,

    // Return instructions (from execute stage decode).
    input  logic                       mret_i,      // MRET instruction
    input  logic                       sret_i,      // SRET instruction

    // Trap entry signal (to pipeline for stall/flush).
    output logic                       trap_entry_o,

    // Trap exit signal (end of handler).
    output logic                       trap_exit_o,

    // PC for trap entry (trap vector address).
    output logic [ADDR_WIDTH - 1:0]    trap_vector_pc_o,

    // PC for trap exit (return address from mepc/sepc).
    output logic [ADDR_WIDTH - 1:0]    trap_return_pc_o,

    // Control signals to CSR file (save exception state).
    output logic                       trap_exception_o,
    output logic [ADDR_WIDTH - 1:0]    trap_exception_pc_o,
    output logic [              3:0]   trap_exception_cause_o,

    // Output to privilege mode register (update privilege on trap entry).
    output logic                       trap_priv_update_o,
    output logic [PRIV_WIDTH - 1:0]    trap_priv_new_o
);

    //--------------------------------------------------------------------------
    // Privilege Modes
    //--------------------------------------------------------------------------
    localparam PRIV_U = 2'b00;
    localparam PRIV_S = 2'b01;
    localparam PRIV_M = 2'b11;

    //--------------------------------------------------------------------------
    // Exception Cause Codes (from RISC-V Privilege Spec)
    // Bit pattern: [3:0] = cause code, bit [63] indicates interrupt (set by execute stage)
    //--------------------------------------------------------------------------

    // Software Exceptions (not interrupts)
    localparam [3:0] CAUSE_INSTR_ADDR_MISALIGN = 4'h0;   // Instruction address misaligned
    localparam [3:0] CAUSE_INSTR_ACCESS_FAULT  = 4'h1;   // Instruction access fault
    localparam [3:0] CAUSE_ILLEGAL_INSTR       = 4'h2;   // Illegal instruction
    localparam [3:0] CAUSE_BREAKPOINT          = 4'h3;   // Breakpoint (EBREAK)
    localparam [3:0] CAUSE_LOAD_ADDR_MISALIGN  = 4'h4;   // Load address misaligned
    localparam [3:0] CAUSE_LOAD_ACCESS_FAULT   = 4'h5;   // Load access fault
    localparam [3:0] CAUSE_STORE_ADDR_MISALIGN = 4'h6;   // Store address misaligned
    localparam [3:0] CAUSE_STORE_ACCESS_FAULT  = 4'h7;   // Store access fault
    localparam [3:0] CAUSE_ECALL_U             = 4'h8;   // Environment call from U-mode
    localparam [3:0] CAUSE_ECALL_S             = 4'h9;   // Environment call from S-mode
    localparam [3:0] CAUSE_ECALL_M             = 4'hB;   // Environment call from M-mode
    localparam [3:0] CAUSE_INSTR_PAGE_FAULT    = 4'hC;   // Instruction page fault
    localparam [3:0] CAUSE_LOAD_PAGE_FAULT     = 4'hD;   // Load page fault
    localparam [3:0] CAUSE_STORE_PAGE_FAULT    = 4'hF;   // Store page fault

    // Interrupt Cause Codes (for reference, come from interrupt_controller)
    localparam [3:0] CAUSE_SOFT_INT_U  = 4'b0000;  // Software interrupt (U-mode)
    localparam [3:0] CAUSE_SOFT_INT_S  = 4'b0001;  // Software interrupt (S-mode)
    localparam [3:0] CAUSE_SOFT_INT_M  = 4'b0011;  // Software interrupt (M-mode)
    localparam [3:0] CAUSE_TIMER_INT_S = 4'b0101;  // Timer interrupt (S-mode)
    localparam [3:0] CAUSE_TIMER_INT_M = 4'b0111;  // Timer interrupt (M-mode)
    localparam [3:0] CAUSE_EXT_INT_S   = 4'b1001;  // External interrupt (S-mode)
    localparam [3:0] CAUSE_EXT_INT_M   = 4'b1011;  // External interrupt (M-mode)

    //--------------------------------------------------------------------------
    // FSM for Trap Entry/Exit Sequencing
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE         = 3'b000,
        TRAP_ENTRY   = 3'b001,  // Exception detected, jumping to handler
        TRAP_HANDLER = 3'b010,  // Inside handler
        TRAP_EXIT    = 3'b011,  // MRET/SRET detected, returning
        DONE         = 3'b100
    } trap_state_t;

    trap_state_t trap_ps, trap_ns;

    //--------------------------------------------------------------------------
    // Determine trap vector address based on privilege & trap type
    //
    // RISC-V mtvec/stvec format:
    //   [BASE] - Base address for trap handlers (typically aligned to 4 bytes)
    //   [1:0]  - Trap vector mode:
    //     00 = DIRECT: All traps jump to BASE
    //     01 = VECTORED: Traps jump to BASE + 4*cause
    //
    // For simplicity, this implementation assumes DIRECT mode.
    // Vectored mode can be added by OR-ing BASE with (cause << 2).
    //--------------------------------------------------------------------------

    logic [ADDR_WIDTH - 1:0] trap_vector_s;
    logic [ADDR_WIDTH - 1:0] trap_return_s;

    always_comb begin
        // Determine trap vector based on exception context
        // In this core, exceptions always trap to M-mode
        // So we always use mtvec unless delegated to S-mode

        // For now, use mtvec for all traps
        // Later, check delegation bits to use stvec
        trap_vector_s = mtvec_i;  // TODO: Check delegation & use stvec if needed

        // Trap return address depends on which mode we're returning from
        if (trap_cause_i[3:0] == CAUSE_ECALL_M ||
            (trap_cause_i[3] && trap_cause_i != CAUSE_TIMER_INT_S &&
             trap_cause_i != CAUSE_EXT_INT_S && trap_cause_i != CAUSE_SOFT_INT_S)) begin
            // M-mode trap: use mepc
            trap_return_s = mepc_i;
        end
        else begin
            // S-mode trap: use sepc
            trap_return_s = sepc_i;
        end
    end

    assign trap_vector_pc_o  = trap_vector_s;
    assign trap_return_pc_o  = trap_return_s;

    //--------------------------------------------------------------------------
    // Trap Entry Logic (Sequential)
    //
    // When trap_en_i asserts, the trap handler:
    // 1. Asserts trap_entry_o for one cycle
    // 2. Outputs trap vector address
    // 3. Signals CSR file to save exception info
    // 4. Transitions privilege mode
    //
    // The execute stage sees trap_entry_o and:
    // - Stalls decode/fetch to prevent new instructions
    // - Flushes execute stage
    // - Updates PC to trap_vector_pc_o
    // - Asserts trap_en to privilege_mode.sv
    //--------------------------------------------------------------------------

    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            trap_ps <= IDLE;
        end
        else begin
            trap_ps <= trap_ns;
        end
    end

    always_comb begin
        trap_ns = trap_ps;

        trap_entry_o = 1'b0;
        trap_exit_o = 1'b0;
        trap_exception_o = 1'b0;
        trap_priv_update_o = 1'b0;

        case (trap_ps)
            IDLE: begin
                if (trap_en_i) begin
                    // Exception detected
                    trap_ns = TRAP_ENTRY;
                end
            end

            TRAP_ENTRY: begin
                // One-cycle pulse: signal trap entry to pipeline
                trap_entry_o = 1'b1;

                // Notify CSR file to save exception state
                trap_exception_o = 1'b1;
                trap_exception_pc_o = '0;  // TODO: Get current PC from pipeline
                trap_exception_cause_o = trap_cause_i;

                // Signal privilege_mode.sv to elevate privilege
                trap_priv_update_o = 1'b1;
                trap_priv_new_o = PRIV_M;  // Always trap to M-mode (for now)

                // Move to handler state
                trap_ns = TRAP_HANDLER;
            end

            TRAP_HANDLER: begin
                // Inside trap handler
                // Waiting for MRET or SRET instruction

                if (mret_i) begin
                    trap_ns = TRAP_EXIT;
                end
                else if (sret_i) begin
                    trap_ns = TRAP_EXIT;
                end
            end

            TRAP_EXIT: begin
                // One-cycle pulse: signal trap exit
                trap_exit_o = 1'b1;

                // Return to original privilege mode
                // (privilege_mode.sv handles this via mret_en/sret_en)

                trap_ns = DONE;
            end

            DONE: begin
                trap_ns = IDLE;
            end

            default: trap_ns = IDLE;
        endcase
    end

endmodule
