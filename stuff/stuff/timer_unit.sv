/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------
// Timer Unit: Implements RISC-V Timer
// Provides mtime counter and mtimecmp comparison
// -----------------------------------------------

module timer_unit
#(
    parameter DATA_WIDTH = 64,
    parameter TIMER_FREQ = 1  // Increment mtime every TIMER_FREQ cycles
)
(
    // Control signals.
    input  logic                     clk_i,
    input  logic                     arst_i,

    // CSR Interface (read/write from CSR file).
    input  logic                     mtime_we_i,      // Write enable for mtime
    input  logic                     mtimecmp_we_i,   // Write enable for mtimecmp
    input  logic [DATA_WIDTH - 1:0]  mtime_write_i,   // Data to write to mtime
    input  logic [DATA_WIDTH - 1:0]  mtimecmp_write_i, // Data to write to mtimecmp

    // CSR Interface (read from CSR file).
    output logic [DATA_WIDTH - 1:0]  mtime_read_o,
    output logic [DATA_WIDTH - 1:0]  mtimecmp_read_o,

    // Timer Interrupt Output (to interrupt controller).
    output logic                     timer_interrupt_o
);

    //--------------------------------------------------------------------------
    // Internal Registers
    //--------------------------------------------------------------------------
    logic [DATA_WIDTH - 1:0] mtime;      // Machine Time Counter (64-bit)
    logic [DATA_WIDTH - 1:0] mtimecmp;   // Timer Compare Register (64-bit)

    // Counter for frequency division (if TIMER_FREQ > 1).
    logic [$clog2(TIMER_FREQ) - 1:0] freq_counter;

    //--------------------------------------------------------------------------
    // mtime Counter Logic
    //
    // RISC-V spec: mtime is a 64-bit read-write register that counts upward.
    // It should increment at a constant rate (typically 1 MHz or 10 MHz).
    // On this core, we increment mtime every TIMER_FREQ clock cycles.
    //
    // Typical example:
    //   - CPU clock: 100 MHz
    //   - TIMER_FREQ = 100
    //   - mtime increments at 1 MHz (100 MHz / 100)
    //
    // For simplicity, TIMER_FREQ = 1 means mtime increments every cycle.
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            mtime <= 64'b0;
            freq_counter <= '0;
        end
        else if (mtime_we_i) begin
            // CSR write: directly set mtime (rare, usually in bootloader)
            mtime <= mtime_write_i;
            freq_counter <= '0;  // Reset frequency counter
        end
        else begin
            // Frequency-divided increment
            if (freq_counter == (TIMER_FREQ - 1)) begin
                mtime <= mtime + 1'b1;
                freq_counter <= '0;
            end
            else begin
                freq_counter <= freq_counter + 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // mtimecmp Register Logic
    //
    // mtimecmp is a 64-bit write-only register (readable via CSR).
    // When mtime >= mtimecmp, the timer interrupt is asserted.
    // Writing mtimecmp clears the interrupt (a write-then-clear pattern).
    //
    // Note: RISC-V allows both 32-bit and 64-bit writes.
    // On a 64-bit core, we use full 64-bit writes.
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF;  // Initialize to max (no interrupt at boot)
        end
        else if (mtimecmp_we_i) begin
            // CSR write: set comparison value
            mtimecmp <= mtimecmp_write_i;
        end
    end

    //--------------------------------------------------------------------------
    // Timer Interrupt Logic
    //
    // The timer interrupt is asserted when mtime >= mtimecmp.
    // This is a level-triggered interrupt (held high until cleared).
    // Interrupt is cleared by writing a new (larger) value to mtimecmp.
    //
    // RISC-V Privilege Spec:
    // - MIP[7] = Machine Timer Interrupt Pending
    // - SIP[5] = Supervisor Timer Interrupt Pending (if delegated)
    //
    // Combinatorial comparison ensures immediate assertion.
    //--------------------------------------------------------------------------
    assign timer_interrupt_o = (mtime >= mtimecmp);

    //--------------------------------------------------------------------------
    // CSR Read Interface
    //
    // mtime and mtimecmp are readable via CSR instructions (CSRR*).
    // The CSR file instantiates this module and reads these outputs.
    //--------------------------------------------------------------------------
    assign mtime_read_o    = mtime;
    assign mtimecmp_read_o = mtimecmp;

endmodule
