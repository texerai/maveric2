// Multiply-Divide Unit (MDU): wraps the multi-cycle multiplier and divider.
//
// op[2:0] maps directly to the RISC-V M-extension func3 field:
//   000=MUL, 001=MULH, 010=MULHSU, 011=MULHU  (routed to multiplier)
//   100=DIV, 101=DIVU, 110=REM,    111=REMU    (routed to divider)
//
// Interface:
//   start  - indicates the start of an operation
//   done   - high when idle or when the current operation has just finished
//   busy   - combinational inverse of done; used to stall the pipeline

module mdu #(
    parameter XLEN = 64
) (
    input  logic            clk_i,
    input  logic            arst_i,
    input  logic            start,
    input  logic [2:0]      op,       // func3: 000-011 = mul ops, 100-111 = div ops
    input  logic            is_mdu_word_op_i,
    input  logic [XLEN-1:0] A,
    input  logic [XLEN-1:0] B,
    output logic [XLEN-1:0] C,
    output logic            busy
);

    logic done;

    // op[2]=0 -> multiplier, op[2]=1 -> divider
    logic is_div;
    assign is_div = op[2];

    // One-shot: convert a held start into a single-cycle pulse
    logic started_r;
    logic start_pulse;

    always_ff @(posedge clk_i or posedge arst_i) begin

        if (arst_i)           started_r <= 0;
        else if (start_pulse) started_r <= 1; // latch after first cycle
        else if (done)        started_r <= 0;
        
    end

    assign start_pulse = start & ~started_r;

    // Route start to exactly one submodule based on the live op[2].
    // The inactive submodule keeps start=0 and remains idle.
    logic mul_start, div_start;
    assign mul_start = start_pulse & ~op[2];
    assign div_start = start_pulse &  op[2];

    logic [XLEN-1:0] mul_C, div_C;
    logic            mul_done, div_done;

    multiplier #(.XLEN(XLEN)) u_mul (
        .clk                (clk_i),
        .rst                (arst_i),
        .start              (mul_start),
        .op                 (op[1:0]),
        .is_mdu_word_op     (is_mdu_word_op_i),
        .A                  (A),
        .B                  (B),
        .C                  (mul_C),
        .done               (mul_done)
    );

    divider #(.XLEN(XLEN)) u_div (
        .clk                (clk_i),
        .rst                (arst_i),
        .start              (div_start),
        .op                 (op[1:0]),
        .is_mdu_word_op     (is_mdu_word_op_i),
        .A                  (A),
        .B                  (B),
        .C                  (div_C),
        .done               (div_done)
    );

    // Steer outputs through the submodule that is (or was most recently) active.
    assign done = is_div ? div_done : mul_done;
    assign C    = is_div ? div_C    : mul_C;

    assign busy = ~done | start_pulse;
    // busy when started and during operation

endmodule
