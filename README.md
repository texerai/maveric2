# MAVERIC Core 2.0

MAVERIC Core 2.0 is an open-source, 5-stage pipelined RISC-V processor written
in SystemVerilog. Earlier progress is logged at
https://github.com/olzhasnurman/maveric_core.git

This repository contains the design (RTL), verification environment, test
infrastructure, and helper scripts needed to simulate the core, run the
official RISC-V test suites against it, and compare its behaviour against the
Spike golden reference model.

## Processor Overview

- ISA: 64-bit RISC-V (RV64I base, plus the `W`-variant integer ops).
- Data / address width: 64-bit addressing, 32-bit instructions.
- Pipeline depth: 5 stages — Fetch, Decode, Execute, Memory, Write-Back —
  with dedicated pipeline registers between every stage
  (`pipeline_reg_decode`, `pipeline_reg_execute`, `pipeline_reg_memory`,
  `pipeline_reg_write_back`).
- Register file: 32 × 64-bit integer registers with synchronous write and
  asynchronous read ports.
- Privilege / exceptions: supports `ECALL` and cause-code generation via the
  main decoder; a software exception-handler routine is provided under
  `test/tests/docs/`.

## Microarchitecture

### Pipeline and Stage-by-Stage Behaviour

The core is a classic in-order 5-stage pipeline (IF → ID → EX → MEM → WB)
with one instruction issued per cycle when no hazard is present.

- **Fetch (IF)** — `rtl/fetch_stage.sv` drives the PC, consults the I-cache,
  and asks the branch predictor for a next-PC override on taken branches /
  hit-in-BTB jumps. The predicted target, predicted direction, and BTB way
  flow down the pipeline alongside the instruction so that EX can validate
  them and drive training updates back to the predictor.
- **Decode (ID)** — `rtl/decode_stage.sv` splits the 32-bit instruction into
  fields via `instr_decoder`, derives the ALU / memory / branch control
  signals from `main_decoder` + `alu_decoder`, reads GPRs from
  `register_file`, and sign-/zero-extends the immediate through
  `extend_imm`.
- **Execute (EX)** — `rtl/execute_stage.sv` houses the 64-bit `alu`, the
  forwarding mux tree (three-way: no-forward / EX-MEM / MEM-WB), and branch
  resolution. A misprediction detected here drives `branch_mispred_exec_o`,
  which flushes IF + ID and retargets the PC.
- **Memory (MEM)** — `rtl/memory_stage.sv` accesses the D-cache for loads
  and stores. Store widths are encoded as `00=SB`, `01=SH`, `10=SW`,
  `11=SD`; misaligned stores raise the `store_addr_ma` exception. Loads are
  re-aligned and sign-/zero-extended by `load_mux`.
- **Write-Back (WB)** — `rtl/write_back_stage.sv` selects between ALU result,
  load data, PC+4 (for JAL/JALR) and immediate sources, then commits to the
  register file on the next rising edge.

### Hazard, Forwarding, and Stall Logic

`rtl/hazard_unit.sv` centralises all pipeline-control policy:

- **RAW forwarding**: each source register has a 2-bit select — `10`
  forwards from EX/MEM, `01` from MEM/WB, `00` uses the regfile read. Both
  `rs1` and `rs2` are handled independently, prioritising the younger
  producer (EX/MEM over MEM/WB).
- **Load-use interlock**: when an EX-stage load's destination matches a
  decode-stage source, the unit stalls IF/ID and bubbles EX for one cycle.
- **Flushes**: a branch misprediction in EX flushes ID and EX; the front-end
  is redirected to the correct target computed by `adder` in EX.
- **Cache stalls**: `stall_cache_i` from the cache FSM freezes every stage
  during an I-cache or D-cache miss.

### Branch Prediction

`rtl/branch_pred_unit.sv` couples a Branch Target Buffer and a Branch
History Table so that taken branches / indirect jumps can be resolved in IF
without waiting for EX.

- **BTB** (`rtl/btb.sv`) — 4-way set-associative, 16 sets by default
  (`SET_COUNT=16`, `N=4`). Each entry stores a 60-bit branch instruction
  address (tag), the 64-bit target, and a valid bit. The BTB also returns
  the way that was hit so that EX can update the correct entry on a
  mispredict.
- **BHT** (`rtl/bht.sv`) — 64-entry table of 2-bit saturating counters
  (`00`=strongly not-taken, `11`=strongly taken). The counter is updated in
  EX based on actual branch outcome; IF consults it in parallel with the
  BTB lookup.
- **Resolution**: EX compares the predicted direction and target against
  the resolved values; on a mismatch `branch_mispred_exec_o` triggers a
  front-end flush and BTB/BHT training write-back.
- **Accuracy reporting**: every run prints total branches and
  mispredictions (see `test/tb/check.c`), so prediction quality can be
  tracked per test.

### Caches and Memory Hierarchy

Both caches share a 512-bit refill line by default (configurable at
elaboration time via `BLOCK_WIDTH`).

- **I-cache** (`rtl/icache.sv`) — direct-mapped, 16 blocks by default,
  read-only from the pipeline's perspective; refilled by the cache FSM on a
  miss.
- **D-cache** (`rtl/dcache.sv`) — **4-way set-associative**, write-back /
  write-allocate, with a dirty bit per way. On an eviction of a dirty way
  the FSM transitions through the `WRITE_BACK` state before re-allocating.
- **Cache FSM** (`rtl/cache_fsm.sv`) — a 4-state controller
  (`IDLE → ALLOCATE_I → IDLE`, `IDLE → ALLOCATE_D → IDLE`,
  `IDLE → WRITE_BACK → ALLOCATE_D → IDLE`). Data misses take priority over
  instruction misses to keep the pipeline from deadlocking on a load that
  sits behind a fetch.
- **Reconfigurability**: `run_tests.py -v` must be paired with `-s`, `-g`,
  or `-a`. It sweeps `BLOCK_WIDTH` from 128 b to 1024 b, `SET_COUNT` from
  2 to 16, and D-cache associativity `N` from 2-way to 8-way, regenerating
  the performance numbers for every combination.

### AXI4-Lite Memory Interface

- The core speaks AXI4-Lite as a master through `rtl/axi4_lite_master.sv`,
  which splits into `axi4_lite_master_read.sv` and
  `axi4_lite_master_write.sv`. A matching slave pair
  (`axi4_lite_slave_read.sv`, `axi4_lite_slave_write.sv`) is provided for
  simulation.
- Default widths: 64-bit address, 32-bit data per beat. Cache lines are
  streamed as `BLOCK_WIDTH / 32` beats by `cache_data_transfer.sv`, which
  also generates the beat counter and asserts `count_done` to close the
  transaction.
- External memory is modelled by `rtl/mem_simulated.sv`, which loads the
  test image from a `$readmemh`-style hex file produced by
  `scripts/disasm2mem.py`.

### Top-Level Integration

`rtl/top.sv` instantiates the full core:

- `datapath` — the pipelined data-path covering all five stages.
- `hazard_unit` — stall / flush / forward controller.
- `cache_fsm` — cache-miss and AXI transaction controller.

The testbench wrapper `rtl/test_env.sv` wires `top` to `mem_simulated` and
the AXI4-Lite bridge so that Verilator simulations can run complete
programs end-to-end.

## Repository Layout

```
rtl/           SystemVerilog source for the core, caches, and AXI interface
test/tb/       C/C++ Verilator testbench and trace-checking helpers
test/tests/    Prebuilt test binaries and test lists (am, rv-tests, rv-arch-test, snippy)
scripts/       Flow helpers: ELF→disasm, disasm→mem, Spike trace comparison
tools/snippy/  Snippy configuration and test-generation script
results/       Auto-populated with pass/fail and performance results
run_tests.py   Top-level driver that verilates, builds, runs, and grades tests
```

## Verification

Verification is organised around two independent pass criteria that every
test must satisfy: a *self-check* on architectural end-state, and a
*trace-compare* against Spike on the full instruction stream. A run is
only reported `PASS` when both agree.

### Test Sources

- **AM** — Abstract Machine tests, small hand-written programs that cover
  ISA corner cases and elementary library routines from
  [NJU-ProjectN/am-kernels](https://github.com/NJU-ProjectN/am-kernels).
  Listed in
  `test/tests/list/list-am.txt`.
- **riscv-tests** — the classic per-instruction regression suite from the
  RISC-V community from
  [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests).
  Listed in `test/tests/list/list-rv-tests.txt`.
- **riscv-arch-test** — the official RISC-V architectural compliance
  suite from
  [riscv/riscv-arch-test](https://github.com/riscv/riscv-arch-test).
  Listed in `test/tests/list/list-rv-arch-test.txt`.
- **Snippy** — randomly generated programs produced by LLVM Snippy from
  [syntacore/snippy](https://github.com/syntacore/snippy) via
  `tools/snippy/snippy_gen_tests.py` using `layout_base.yaml`. Each
  snippet is 500 instructions across 10 functions arranged in 2 call-graph
  layers, drawn from the full RV64I + M instruction histogram. Listed in
  `test/tests/list/list-snippy.txt`.

### Simulator and Reference Model

- **RTL simulator**: Verilator. The wrapper in `test/tb/tb_test_env.cpp`
  drives `test_env`, toggles the clock, and holds reset for the first 100
  cycles. Simulation terminates when the program reaches `ECALL` /
  `EBREAK` or hits `MAX_SIM_TIME`.
- **Golden reference**: Spike (`riscv-isa-sim`) is launched by
  `scripts/tracecomp.py` with `spike -d --log-commits`. The ISA string
  enabled by default is
  `rv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0` — i.e.
  RV64IMAFD with Zicsr/Zifencei/Zmmul, which is a superset of what the
  core implements. Only instructions the DUT actually executes are
  compared, so the superset is safe.

### Commit-Log Format

The DUT emits one line per retiring instruction through
`test/tb/log_trace.c`:

```
PC: 0x<pc>, INSTR: 0x<opcode>, REG x<rd>: 0x<value>, MEM 0x<addr>: 0x<data>
```

`ECALL` (`0x73`) is suppressed so the final exit instruction does not
pollute the trace. Register-write, memory-read, and memory-write fields
are only printed when the corresponding enable is asserted, giving the
same shape Spike's `--log-commits` produces and making a line-by-line
diff meaningful.

### Self-Check (Architectural End-State)

`test/tb/check.c` is called once the simulation finishes and inspects:

- `a0` (return code): `0` → PASS, `1` → FAIL, anything else → undefined.
- `mcause`: `11`/`3` report a standard exit via `ECALL`/`EBREAK`; `2`
  flags an illegal instruction; `0`, `4`, `6` flag instruction / load /
  store address-misaligned faults respectively.
- Branch-predictor counters (`branch_total`, `branch_mispred`) are read
  out and accuracy is printed next to the pass/fail verdict, so
  predictor regressions show up immediately in the results log.

Snippy tests intentionally exercise random behaviour, so their
self-check status is reported as *Not Applicable* — they rely on
trace-compare instead.

### Trace-Compare Flow

`scripts/tracecomp.py` automates the reference run:

1. Spawns Spike in interactive commit-log mode on the same ELF the RTL is
   executing.
2. Streams Spike's log, stopping as soon as `ecall`, `ebreak`, or
   `exception trap` appears — this keeps the two traces bounded to the
   same retirement window.
3. Strips interactive shell noise (`(spike)`, `>>>>`, banner lines) and
   parses each commit into a dict of PC / instruction / register / value
   / memory address / memory value.
4. Writes the normalised Spike log to
   `spike_log_trace/<test>-log-trace.log`; the RTL log lands in
   `log_trace/<test>-log-trace.log`.
5. `run_tests.py` then runs `diff` between the two; the first mismatch
   (up to ten lines) is kept in `temp.txt` for debugging, and the test
   is flagged `Tracecomp: FAIL`.

### Coverage

`run_tests.py` coverage flags must be paired with a test-running command,
for example `python3 run_tests.py -a --coverage-all` (or `-s ... -cl`,
`-g ... -ct`). The driver re-verilates with coverage enabled, runs the
selected tests, and then invokes `verilator_coverage` to merge and
annotate the per-test `.dat` files into `coverage_annotated/`. Per-test
coverage files are written to `cov/` so that cache-parameter sweeps keep
their data separated.

### Verilator Diagnostics

Regular test runs keep successful Verilator stdout/stderr quiet so the
pass/fail output stays compact. Add `-w` / `--warnings` to any test-running
command when you want to see Verilator warnings and a `Verilator warnings:
<count>` summary. The `-L` / `--lint-module` operation runs a standalone
lint-only check for one RTL module and always prints the lint output and
warning count.

### Performance Counters

Alongside the pass/fail log, each run records microarchitectural
statistics into `results/perf_result.txt`: retired-instruction count,
total cycles, IPC, stall breakdown by source (load-use, cache-miss,
branch-flush), and the branch-predictor hit rate. Combined with
`-v` this is what lets the repository track the performance
impact of cache geometry changes.

### Requirements

- Verilator (with `--trace` and `--coverage` support)
- A RISC-V GNU toolchain (for the scripts that manipulate ELF/disassembly)
- Spike (`riscv-isa-sim`) for reference traces
- Python 3, GCC, Make

### Running Tests

The `run_tests.py` driver handles Verilator compilation, simulation, Spike
comparison, and result aggregation.

For normal `-s`, `-g`, and `-a` runs, the script uses the current saved
defaults from `rtl/test_env.sv` (`BLOCK_WIDTH`) and `rtl/dcache.sv`
(`SET_COUNT` and associativity `N`). It temporarily overrides those values
only when a `-v` sweep is requested, then restores the original defaults at
the end of the run.

```bash
# List every available test
python3 run_tests.py -l

# Run the full test matrix
python3 run_tests.py -a

# Run a single test and dump a waveform
python3 run_tests.py -s <test_name> -t

# Run only Dromajo co-simulation, skipping Spike trace comparison
python3 run_tests.py -s <test_name> --cosim-only

# Run without Dromajo co-simulation, keeping Spike trace comparison
python3 run_tests.py -s <test_name> --no-cosim

# Show Verilator warnings and the warning count during a test build
python3 run_tests.py -s <test_name> -w

# Run a group: am | rv-tests | rv-arch-test | snippy
python3 run_tests.py -g rv-arch-test

# Lint one RTL module with Verilator
python3 run_tests.py -L <module_name>

# Sweep BLOCK_WIDTH, SET_COUNT, and associativity for one test
python3 run_tests.py -s <test_name> -v

# Sweep the same cache parameters for a test group
python3 run_tests.py -g rv-tests -v

# Sweep the full test matrix
python3 run_tests.py -a -v

# Generate line + toggle coverage
python3 run_tests.py -a --coverage-all

# Remove generated build, trace, coverage, and prepared test artifacts
python3 run_tests.py -c

# Tidy the tree before a commit
python3 run_tests.py -p
```

Pass/fail summaries are written to `results/result.txt` and per-test
performance numbers (IPC, stall counts, etc.) to `results/perf_result.txt`.
For `-v` runs, both files also include cache-configuration headers showing
`BLOCK_WIDTH`, `SET_COUNT`, and associativity for each sweep point.
