/* Copyright (c) 2024 Maveric NU. All rights reserved. */

// -----------------------------------------------
// Interrupt Controller
// Routes timer/external interrupts to CPU
// Respects privilege levels & interrupt enable bits
// -----------------------------------------------

module interrupt_controller
#(
    parameter PRIV_WIDTH = 2
)
(
    // Control signals.
    input  logic                      clk_i,
    input  logic                      arst_i,

    // Interrupt Sources
    input  logic                      timer_interrupt_i,      // From timer_unit
    input  logic                      external_interrupt_i,   // From platform (PLIC, etc.)
    input  logic                      software_interrupt_i,   // From IPI (inter-processor)

    // Privilege & Interrupt Enable from CSR
    input  logic [PRIV_WIDTH - 1:0]   priv_mode_i,            // Current privilege mode
    input  logic                      mie_i,                  // mstatus.MIE (M-mode interrupt enable)
    input  logic                      sie_i,                  // sstatus.SIE (S-mode interrupt enable)

    // CSR Interrupt Enable Masks
    input  logic [             3:0]   mie_mtimer_i,           // MIE[7] - M-mode timer
    input  logic [             3:0]   mie_mext_i,             // MIE[11] - M-mode external
    input  logic [             3:0]   mie_msoft_i,            // MIE[3] - M-mode software
    input  logic [             3:0]   sie_stimer_i,           // SIE[5] - S-mode timer
    input  logic [             3:0]   sie_sext_i,             // SIE[9] - S-mode external
    input  logic [             3:0]   sie_ssoft_i,            // SIE[1] - S-mode software

    // Interrupt Delegation (to S-mode)
    input  logic                      ideleg_timer_i,         // Delegate timer to S-mode
    input  logic                      ideleg_ext_i,           // Delegate external to S-mode
    input  logic                      ideleg_soft_i,          // Delegate software to S-mode

    // Interrupt Pending Status (for CSR file)
    output logic [             3:0]   mip_timer_o,            // MIP[7]
    output logic [             3:0]   mip_ext_o,              // MIP[11]
    output logic [             3:0]   mip_soft_o,             // MIP[3]
    output logic [             3:0]   sip_timer_o,            // SIP[5]
    output logic [             3:0]   sip_ext_o,              // SIP[9]
    output logic [             3:0]   sip_soft_o,             // SIP[1]

    // CPU Exception Signals (to execute stage)
    output logic                      interrupt_valid_o,      // Interrupt should be taken
    output logic [             3:0]   interrupt_cause_o       // Exception cause code
);

    //--------------------------------------------------------------------------
    // Privilege Modes
    //--------------------------------------------------------------------------
    localparam PRIV_U = 2'b00;
    localparam PRIV_S = 2'b01;
    localparam PRIV_M = 2'b11;

    //--------------------------------------------------------------------------
    // RISC-V Exception Cause Codes (Interrupt Codes)
    // Bit [63] = 1 indicates interrupt (vs exception)
    //--------------------------------------------------------------------------
    localparam [3:0] CAUSE_SOFT_INT_M  = 4'b0011;  // Software interrupt (M-mode)
    localparam [3:0] CAUSE_TIMER_INT_M = 4'b0111;  // Timer interrupt (M-mode)
    localparam [3:0] CAUSE_EXT_INT_M   = 4'b1011;  // External interrupt (M-mode)

    localparam [3:0] CAUSE_SOFT_INT_S  = 4'b0001;  // Software interrupt (S-mode)
    localparam [3:0] CAUSE_TIMER_INT_S = 4'b0101;  // Timer interrupt (S-mode)
    localparam [3:0] CAUSE_EXT_INT_S   = 4'b1001;  // External interrupt (S-mode)

    //--------------------------------------------------------------------------
    // Interrupt Pending Registers (latched from input signals)
    // Hardware automatically sets these on interrupt assertion
    // Software clears them (via CSR write or IPI acknowledgment)
    //--------------------------------------------------------------------------
    logic timer_pending_m;
    logic timer_pending_s;
    logic ext_pending_m;
    logic ext_pending_s;
    logic soft_pending_m;
    logic soft_pending_s;

    //--------------------------------------------------------------------------
    // Latch interrupt pending status
    // These remain high until cleared by software (via CSR write to mip/sip)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk_i, posedge arst_i) begin
        if (arst_i) begin
            timer_pending_m <= 1'b0;
            timer_pending_s <= 1'b0;
            ext_pending_m <= 1'b0;
            ext_pending_s <= 1'b0;
            soft_pending_m <= 1'b0;
            soft_pending_s <= 1'b0;
        end
        else begin
            // Timer interrupt: set in M-mode, may delegate to S-mode
            if (timer_interrupt_i) begin
                if (ideleg_timer_i) begin
                    timer_pending_s <= 1'b1;
                end
                else begin
                    timer_pending_m <= 1'b1;
                end
            end

            // External interrupt: set in M-mode, may delegate to S-mode
            if (external_interrupt_i) begin
                if (ideleg_ext_i) begin
                    ext_pending_s <= 1'b1;
                end
                else begin
                    ext_pending_m <= 1'b1;
                end
            end

            // Software interrupt: set in M-mode, may delegate to S-mode
            if (software_interrupt_i) begin
                if (ideleg_soft_i) begin
                    soft_pending_s <= 1'b1;
                end
                else begin
                    soft_pending_m <= 1'b1;
                end
            end

            // Software can clear pending bits via CSR writes to mip/sip
            // This would require additional CSR control signals (not shown here)
            // For now, interrupts remain pending until acknowledged
        end
    end

    //--------------------------------------------------------------------------
    // Output Interrupt Pending Status to CSR File
    //--------------------------------------------------------------------------
    assign mip_timer_o = {3'b0, timer_pending_m};
    assign mip_ext_o   = {3'b0, ext_pending_m};
    assign mip_soft_o  = {3'b0, soft_pending_m};
    assign sip_timer_o = {3'b0, timer_pending_s};
    assign sip_ext_o   = {3'b0, ext_pending_s};
    assign sip_soft_o  = {3'b0, soft_pending_s};

    //--------------------------------------------------------------------------
    // Interrupt Priority & Routing Logic
    //
    // Priority (highest to lowest):
    //   1. M-mode interrupts (if MTIE enabled and in context where they can fire)
    //   2. S-mode interrupts (if STIE enabled and in context where they can fire)
    //
    // Context rules (from RISC-V Privilege Spec):
    //   - M-mode interrupts can fire in any privilege mode
    //   - S-mode interrupts can only fire in S or U mode (not M-mode)
    //   - Interrupts only fire if global enable bit (MIE or SIE) is set
    //
    // Timeline: Interrupt is recognized on next cycle after CPU is ready
    //--------------------------------------------------------------------------

    logic m_timer_enabled_s;
    logic m_ext_enabled_s;
    logic m_soft_enabled_s;
    logic s_timer_enabled_s;
    logic s_ext_enabled_s;
    logic s_soft_enabled_s;

    // Check if specific interrupt is enabled in corresponding CSR
    assign m_timer_enabled_s = mie_mtimer_i[0];
    assign m_ext_enabled_s   = mie_mext_i[0];
    assign m_soft_enabled_s  = mie_msoft_i[0];
    assign s_timer_enabled_s = sie_stimer_i[0];
    assign s_ext_enabled_s   = sie_sext_i[0];
    assign s_soft_enabled_s  = sie_ssoft_i[0];

    //--------------------------------------------------------------------------
    // Interrupt Decision Logic (Combinatorial)
    //
    // Determine if interrupt should be taken and what cause code to use.
    // Priority order determines which interrupt is serviced first.
    //--------------------------------------------------------------------------
    always_comb begin
        interrupt_valid_o = 1'b0;
        interrupt_cause_o = 4'b0000;

        //--------------------------------------------------------------------
        // M-mode Context: Only M-mode interrupts can fire (SIE ignored)
        //--------------------------------------------------------------------
        if (priv_mode_i == PRIV_M) begin
            // Must have global M-mode interrupt enable
            if (mie_i) begin
                // Software interrupt (highest priority)
                if (soft_pending_m && m_soft_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_SOFT_INT_M;
                end
                // Timer interrupt (medium priority)
                else if (timer_pending_m && m_timer_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_TIMER_INT_M;
                end
                // External interrupt (lowest priority)
                else if (ext_pending_m && m_ext_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_EXT_INT_M;
                end
            end
        end
        //--------------------------------------------------------------------
        // S-mode or U-mode Context: Both M and S interrupts can fire
        // M-mode interrupts always take priority over S-mode (unless globally disabled)
        //--------------------------------------------------------------------
        else begin  // PRIV_S or PRIV_U
            // First, check M-mode interrupts (highest priority)
            if (mie_i) begin
                if (soft_pending_m && m_soft_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_SOFT_INT_M;
                end
                else if (timer_pending_m && m_timer_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_TIMER_INT_M;
                end
                else if (ext_pending_m && m_ext_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_EXT_INT_M;
                end
            end

            // If no M-mode interrupt, check S-mode interrupts
            if (~interrupt_valid_o && sie_i) begin
                if (soft_pending_s && s_soft_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_SOFT_INT_S;
                end
                else if (timer_pending_s && s_timer_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_TIMER_INT_S;
                end
                else if (ext_pending_s && s_ext_enabled_s) begin
                    interrupt_valid_o = 1'b1;
                    interrupt_cause_o = CAUSE_EXT_INT_S;
                end
            end
        end
    end

endmodule
