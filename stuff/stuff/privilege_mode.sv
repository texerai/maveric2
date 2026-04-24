/**
 * Current Privilege Mode (CPM) Register
 *
 * A 2-bit architectural register that defines the current privilege level.
 * Lives outside the main pipeline as a global state register.
 *
 * Privilege Levels (RISC-V standard):
 *   CPM[1:0] = 00 -> User Mode (U-mode)
 *   CPM[1:0] = 01 -> Supervisor Mode (S-mode) [for Linux kernel]
 *   CPM[1:0] = 10 -> Hypervisor Mode (H-mode) [unused on this core]
 *   CPM[1:0] = 11 -> Machine Mode (M-mode) [firmware/bootloader]
 *
 * Key Responsibilities:
 * 1. Output current privilege to all stages (decode, execute, CSR file)
 * 2. Elevate to M-mode on exceptions (trap entry)
 * 3. Restore privilege from CSR on MRET/SRET (trap return)
 * 4. Accept updates from CSR writes (direct privilege change)
 *
 * Integration with CSR File:
 * - On exception (trap_en asserted):
 *   1) CPM elevates to M-mode
 *   2) CSR file captures old CPM value → stores in mstatus.mpp[12:11]
 *   3) Exception handler runs in M-mode
 * - On MRET (mret_en asserted):
 *   1) CPM restores from mstatus.mpp (passed via mstatus_mpp_i)
 *   2) Control returns to previous privilege level
 * - Similar flow for SRET with sstatus.spp
 *
 * Timing: CPM updates are SYNCHRONOUS (on clock edge)
 * This ensures exception entry and CSR state capture happen atomically.
 */

module privilege_mode #(
    parameter PRIV_WIDTH = 2
) (
    input logic clk,
    input logic rst_n,

    // Current privilege mode output (broadcast to CSR, decode stage)
    output logic [PRIV_WIDTH-1:0] cpm_out,

    // Privilege mode input (for direct CSR writes via CSRRW)
    input logic [PRIV_WIDTH-1:0] cpm_in,
    input logic cpm_wr_en,           // Write enable for privilege mode update

    // Exception/Return Control Signals (from execute stage)
    input logic trap_en,             // Exception/trap detected, elevate privilege
    input logic mret_en,             // MRET instruction - restore from mstatus.mpp
    input logic sret_en,             // SRET instruction - restore from sstatus.spp

    // CSR Status Register Fields (for restoration on return)
    // mstatus.MPP: bits [12:11] - saved machine mode privilege
    input logic [PRIV_WIDTH-1:0] mstatus_mpp_i,

    // sstatus.SPP: bit [8] extended to 2 bits - saved supervisor mode privilege
    input logic [PRIV_WIDTH-1:0] sstatus_spp_i
);

// ----------------------------------------------------------------------------
// Privilege Level Constants
// ----------------------------------------------------------------------------

localparam logic [PRIV_WIDTH-1:0] PRIV_USER       = 2'b00;
localparam logic [PRIV_WIDTH-1:0] PRIV_SUPERVISOR = 2'b01;
localparam logic [PRIV_WIDTH-1:0] PRIV_HYPERVISOR = 2'b10;
localparam logic [PRIV_WIDTH-1:0] PRIV_MACHINE    = 2'b11;

// ----------------------------------------------------------------------------
// Internal Registers
// ----------------------------------------------------------------------------

logic [PRIV_WIDTH-1:0] cpm_q;
logic [PRIV_WIDTH-1:0] cpm_d;

// ----------------------------------------------------------------------------
// Privilege Transition Logic
//
// Priority (highest to lowest):
//   1. trap_en    - Exception: immediately elevate to M-mode
//   2. mret_en    - Return from M-mode trap: restore from mstatus.mpp
//   3. sret_en    - Return from S-mode trap: restore from sstatus.spp
//   4. cpm_wr_en  - Direct write (CSR write, initialization)
//   5. hold       - Default: maintain current privilege
//
// RISC-V Privilege Architecture Overview:
//   - Exceptions always trap to M-mode (on this core)
//   - MRET restores privilege from mstatus.MPP (bits [12:11])
//   - SRET restores privilege from sstatus.SPP (bit [8])
//   - Privilege transitions are ATOMIC: updated on next clock
// ----------------------------------------------------------------------------

always_comb begin
    cpm_d = cpm_q;  // Default: hold current value

    //------------------------------------------------------------------------
    // Exception Entry (Highest Priority)
    // When an exception occurs (page fault, illegal instruction, ECALL, etc.),
    // immediately elevate to machine mode where the trap handler runs.
    // The current privilege is saved by CSR file to mstatus.mpp.
    //------------------------------------------------------------------------
    if (trap_en) begin
        cpm_d = PRIV_MACHINE;
    end
    //------------------------------------------------------------------------
    // Machine Return Instruction (MRET)
    // MRET restores privilege from mstatus.mpp, which contains the privilege
    // level that was saved when the exception occurred.
    // Example flow:
    //   User-mode → exception → M-mode (cpm becomes PRIV_MACHINE)
    //   mstatus.mpp is set to PRIV_USER by CSR file
    //   MRET executes → cpm restored to PRIV_USER
    //------------------------------------------------------------------------
    else if (mret_en) begin
        cpm_d = mstatus_mpp_i;
    end
    //------------------------------------------------------------------------
    // Supervisor Return Instruction (SRET)
    // SRET restores privilege from sstatus.spp.
    // Used when running in S-mode (Linux kernel);
    // typically restores back to U-mode after handling system call/interrupt.
    // Example flow:
    //   User-mode → ECALL → S-mode (supervisor trap handler)
    //   sstatus.spp is set to PRIV_USER by CSR file
    //   SRET executes → cpm restored to PRIV_USER
    //------------------------------------------------------------------------
    else if (sret_en) begin
        cpm_d = sstatus_spp_i;
    end
    //------------------------------------------------------------------------
    // Direct Privilege Write
    // Used for:
    // 1. CSR writes: CSRRW mstatus to change privilege (rare, only M-mode)
    // 2. Boot code: initialization to establish privilege hierarchy
    // 3. Context switches: setting privilege for new task
    //------------------------------------------------------------------------
    else if (cpm_wr_en) begin
        cpm_d = cpm_in;
    end
    // else: Hold current privilege (cpm_d = cpm_q via default assignment)
end

// ----------------------------------------------------------------------------
// Sequential Logic (Privilege State Update)
//
// The current privilege mode is updated on every clock cycle.
// Since exceptions, returns, and CSR writes all decode in the same cycle,
// the priority logic (always_comb) ensures only one transition per cycle.
// ----------------------------------------------------------------------------

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset to machine mode (standard RISC-V: boot in M-mode)
        cpm_q <= PRIV_MACHINE;
    end
    else begin
        // Update privilege on next clock
        cpm_q <= cpm_d;
    end
end

// ----------------------------------------------------------------------------
// Output
// ----------------------------------------------------------------------------

assign cpm_out = cpm_q;

endmodule