# MAVERIC Core 2.0

MAVERIC Core 2.0 is an open-source, 5-stage pipelined RISC-V processor written
in SystemVerilog. Earlier progress is logged at
https://github.com/olzhasnurman/maveric_core.git

This repository contains the design (RTL), verification environment, test
infrastructure, and helper scripts needed to simulate the core, run the
official RISC-V test suites against it, and check its behaviour both against
the Dromajo golden reference model (per-instruction co-simulation) and the
Spike commit log (trace comparison).

## Processor Overview

- ISA: 64-bit RISC-V — RV64IMA (the RV64I base plus the `M` multiply/divide
  extension, the `A` atomic extension, and the `W`-variant integer ops) with
  the `Zicsr` control/status registers, the `Zifencei` instruction-fetch
  fence (`FENCE` / `FENCE.I`), the `Zicntr` base counters
  (`cycle` / `time` / `instret`), and the `Sstc` supervisor timer-compare
  extension (`stimecmp`). `misa` reports `RV64AIMSU`.
- Data / address width: 64-bit addressing, 32-bit instructions.
- Pipeline depth: 5 stages — Fetch, Decode, Execute, Memory, Write-Back —
  with dedicated pipeline registers between every stage
  (`pipeline_reg_decode`, `pipeline_reg_execute`, `pipeline_reg_memory`,
  `pipeline_reg_write_back`).
- Register file: 32 × 64-bit integer registers with synchronous write and
  asynchronous read ports.
- Privilege levels: all three modes — **machine (M), supervisor (S), and
  user (U)** — with per-mode CSR access checking, trap delegation
  (`medeleg` / `mideleg`), and both `mret` and `sret` returns.
- Virtual memory: **Sv39** address translation through a hardware page-table
  walker and split 4-entry instruction/data TLBs, plus `SFENCE.VMA`.
- Protection: **16-entry PMP** (physical memory protection) checked on every
  instruction fetch and load/store.
- Traps / interrupts: synchronous exceptions (environment calls from U/S/M,
  breakpoint, illegal instruction, misaligned address, access fault, page
  fault) with correct priority when several arrive at once, and asynchronous
  machine/supervisor timer and software interrupts delivered by an on-chip
  CLINT and the `Sstc` `stimecmp` comparator.
- Configuration: widths, CSR addresses, privilege encodings, and trap causes
  are centralised in `rtl/maveric_pkg.sv` (`maveric_pkg` + `csr_pkg`).

## Microarchitecture

### Pipeline and Stage-by-Stage Behaviour

The core is a classic in-order 5-stage pipeline (IF → ID → EX → MEM → WB)
with one instruction issued per cycle when no hazard is present.

- **Fetch (IF)** — `rtl/fetch_stage.sv` drives the PC, consults the I-cache,
  and asks the branch predictor for a next-PC override on taken branches /
  hit-in-BTB jumps. When translation is active the PC is first looked up in
  the **ITLB** (`rtl/itlb.sv`); the resulting physical address is screened by
  the fetch-side **PMP checker** (`rtl/pmp_check.sv`) before it reaches the
  I-cache. The predicted target, predicted direction, and BTB way flow down
  the pipeline alongside the instruction so that EX can validate them and
  drive training updates back to the predictor.
- **Decode (ID)** — `rtl/decode_stage.sv` splits the 32-bit instruction into
  fields via `instr_decoder`, derives all control signals from the
  `control_unit` (which wraps `main_decoder` + `alu_decoder` and also raises
  the `is_mdu_op` / `is_mdu_word_op` flags for the M extension), reads GPRs
  from `register_file`, and sign-/zero-extends the immediate through
  `extend_imm`. The decoder also recognises the privileged instructions
  (`mret`, `sret`, `sfence.vma`) and flags them for the back-end.
- **Execute (EX)** — `rtl/execute_stage.sv` houses the 64-bit `alu`, the
  forwarding mux tree (three-way: no-forward / EX-MEM / MEM-WB), and branch
  resolution. It also hosts the multi-cycle **MDU** (`rtl/mdu.sv`, wrapping
  `multiplier.sv` + `divider.sv`) for the M extension and the **CSR file**
  (`rtl/csr_file.sv`) that services `Zicsr` reads/writes, tracks the current
  privilege mode, and performs trap entry/return. A misprediction detected
  here drives `branch_mispred_exec_o`, which flushes IF + ID and retargets
  the PC.
- **Memory (MEM)** — `rtl/memory_stage.sv` accesses the D-cache for loads
  and stores. Data addresses are translated by the **DTLB** (`rtl/dtlb.sv`)
  and screened by the LSU-side **PMP checker** (`rtl/pmp_check_lsu.sv`).
  Store widths are encoded as `00=SB`, `01=SH`, `10=SW`, `11=SD`;
  `mem_exc_detect.sv` flags misaligned accesses as load/store `addr_ma`
  exceptions. Loads are re-aligned and sign-/zero-extended by `load_mux`.
  This stage also hosts the memory-mapped **CLINT** (`rtl/clint.sv`) and the
  **AMO ALU** (`rtl/amo_alu.sv`) that computes read-modify-write results for
  the atomic extension (see *Atomic (A) Extension* below), muxing the CLINT
  register reads back into the load path.
- **Write-Back (WB)** — `rtl/write_back_stage.sv` selects between ALU result,
  load data, PC+4 (for JAL/JALR) and immediate sources, then commits to the
  register file on the next rising edge. Trap commit, `mret`/`sret`, and
  `sfence.vma` side effects take effect from here.

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
- **MMU stalls**: a TLB miss hands the pipeline to the page-table walker;
  `mmu_stall_i` (data side) and `mmu_stall_icache_i` (fetch side) hold the
  affected stages until the walk completes and the TLB is refilled.

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
  miss and fully invalidated on a `FENCE.I` (see *Instruction-Fetch Fence*
  below).
- **D-cache** (`rtl/dcache.sv`) — **4-way set-associative**, write-back /
  write-allocate, with a dirty bit per way. On an eviction of a dirty way
  the FSM transitions through the `WRITE_BACK` state before re-allocating.
  The MMU page-table walker shares the D-cache port, so page-table entries
  are cached like ordinary data.
- **Cache FSM** (`rtl/cache_fsm.sv`) — a controller whose core flow is
  `IDLE → ALLOCATE_I → IDLE`, `IDLE → ALLOCATE_D → IDLE`, and
  `IDLE → WRITE_BACK → ALLOCATE_D → IDLE`, plus a
  `WB_FENCEI → WB_FENCEI_DONE` path that drains every dirty D-cache line on a
  `FENCE.I` (see *Instruction-Fetch Fence* below). Data misses take priority
  over instruction misses to keep the pipeline from deadlocking on a load that
  sits behind a fetch.
- **Reconfigurability**: `run_tests.py -v` must be paired with `-s`, `-g`,
  or `-a`. It sweeps `BLOCK_WIDTH` from 128 b to 1024 b and `SET_COUNT` from
  2 to 16, regenerating the performance numbers for every combination.
  D-cache associativity is fixed at `N=4` (the design is not parameterized for
  other widths), so the sweep holds it at the saved default.

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
  `scripts/disasm2mem.py`. Accesses above the MMIO base are routed to the
  device window instead of the memory array, and UART writes are forwarded
  out of the simulation through the `pmem_write` DPI-C hook
  (`test/tb/pmem_write.c`) into `MAVERIC_PMEM_WRITE_FILE`.

### Privilege Modes, CSRs, and Traps

`rtl/csr_file.sv` implements the full M/S/U privilege machinery: it tracks
the current privilege mode, owns every CSR, and performs trap entry/return.
CSR addresses, privilege encodings, and trap-cause codes come from `csr_pkg`
in `rtl/maveric_pkg.sv`.

- **Machine-level CSRs**: information registers (`mvendorid`, `marchid`,
  `mimpid`, `mhartid`, all read-as-zero), trap setup (`mstatus`, `misa`,
  `medeleg`, `mideleg`, `mie`, `mtvec`, `mcounteren`), trap handling
  (`mscratch`, `mepc`, `mcause`, `mtval`, `mip`), configuration (`menvcfg`
  with writable `STCE` and `CDE` bits), memory protection (two 64-bit PMP
  configuration registers at `0x3A0` / `0x3A2` plus
  `pmpaddr0`–`pmpaddr15`), and counters (`mcycle`, `minstret`,
  `mcountinhibit`).
- **Supervisor-level CSRs**: `sstatus`, `sie`, `stvec`, `scounteren`,
  `scountinhibit`, `sscratch`, `sepc`, `scause`, `stval`, `sip`,
  `stimecmp` (`Sstc`), and `satp`. The `s*` views are the architecturally
  required subsets of their machine counterparts.
- **Unprivileged CSRs**: `cycle`, `time` (mirrored from the CLINT `mtime`),
  and `instret`, with reads from S/U mode gated by
  `mcounteren` / `scounteren` as the spec requires.
- **Access checking**: a CSR access from an insufficient privilege level, a
  write to a read-only CSR, or an access to an unimplemented address raises
  an illegal-instruction exception, so OS-style privilege-separation code
  behaves as on real hardware. `scountinhibit` accessibility is additionally
  gated by `menvcfg.CDE`.
- **Trap entry and delegation**: on an exception or interrupt the file
  latches `xepc` / `xcause` / `xtval` and redirects the front-end to the
  `mtvec` or `stvec` handler, choosing the destination privilege level via
  `medeleg` / `mideleg`. `mret` and `sret` restore the saved context
  (including the `mstatus.MPRV` drop on `mret` to a less-privileged mode).
  When several exceptions arrive in the same cycle the architecturally
  defined priority order picks the survivor.
- **Interrupts**: machine timer and software interrupts come from the CLINT
  (`mtimecmp` / `msip`); the supervisor timer interrupt is generated by the
  `Sstc` comparison `mtime >= stimecmp` (enabled by `menvcfg.STCE`); the
  supervisor software interrupt is raised by writing `sip.SSIP`. Pending
  bits are masked by `mie` / `sie` and the `mstatus` global-enable bits, and
  `mideleg` routes supervisor interrupts to S-mode. External-interrupt cause
  codes are defined, but no PLIC is integrated yet.

### Virtual Memory (Sv39 MMU)

The core translates addresses with the Sv39 scheme (39-bit virtual, 3-level
page tables) whenever the effective privilege level is S or U and
`satp.MODE = 8`:

- **ITLB / DTLB** (`rtl/itlb.sv`, `rtl/dtlb.sv`) — a 4-entry fully
  associative TLB in front of each cache. Entries are tagged with the VPN
  and the `satp` ASID and carry the PPN plus the R/W/X/U/A/D permission
  bits, so a hit checks permissions in the same cycle it translates.
- **Page-table walker** (`rtl/mmu_ptw.sv`) — a single hardware PTW shared by
  both TLBs. On a TLB miss it stalls the pipeline, walks the three page-table
  levels through the D-cache port (so PTEs are cached), refills the missing
  TLB entry, and re-runs the access. PTE permission violations — including
  `mstatus.MXR` / `mstatus.SUM` checks — surface as instruction / load /
  store page faults (causes 12 / 13 / 15) on the faulting instruction.
- **Effective privilege**: loads and stores honour `mstatus.MPRV`, i.e. when
  `MPRV=1` in M-mode the LSU translates and protection-checks with the
  privilege in `mstatus.MPP`, while instruction fetches always use the true
  current mode.
- **`SFENCE.VMA`** — decoded in ID and committed in WB, it invalidates both
  TLBs so page-table updates and `satp` switches take effect.

### Physical Memory Protection (PMP)

- **16 PMP entries**, programmed through two 64-bit configuration CSRs
  (`0x3A0`, `0x3A2`) and `pmpaddr0`–`pmpaddr15`. `rtl/pmp_range.sv` inside
  the CSR file pre-decodes every entry into a physical-address range;
  supported address-matching modes are `OFF`, `TOR`, and `NA4` (`NAPOT` is
  decoded but not implemented yet). The lock (`L`) bit enforces entries on
  M-mode as well.
- **Checks on both paths**: `rtl/pmp_check.sv` screens every instruction
  fetch and `rtl/pmp_check_lsu.sv` every load/store/AMO, after translation,
  against the decoded ranges. A violation raises the matching access-fault
  exception — cause 1 (fetch), 5 (load), or 7 (store/AMO).

### Counters (Zicntr)

`rtl/perf_counters.sv` tracks microarchitectural statistics for reporting,
while the architectural counters live in the CSR file: `mcycle` and
`minstret` count in hardware (suppressible per-counter via
`mcountinhibit` / `scountinhibit`), and the unprivileged `cycle` / `time` /
`instret` views are exposed to lower privilege levels under
`mcounteren` / `scounteren` control.

### CLINT and Memory-Mapped I/O

- **CLINT** (`rtl/clint.sv`) — the Core Local Interruptor, instantiated in the
  memory stage. It exposes `MSIP` (`0x0000`, machine software interrupt
  pending), `MTIMECMP` (`0x4000`), and the free-running `MTIME` (`0xBFF8`),
  and raises `timer_irq` / `software_irq` back into the CSR file.
- **MMIO routing**: stores to the device window (e.g. the UART) are issued by
  the memory stage and carried out over AXI4-Lite by the `test_env` MMIO FSM
  rather than to the cached memory array, so console output and CLINT register
  traffic stay coherent with the golden model during co-simulation.

### Atomic (A) Extension

The core implements the RV64A atomic instructions end-to-end:

- **Decode**: `main_decoder` recognises the atomic opcode (`0101111`) as its
  own instruction class and, from the full `func7`, raises the
  `atomic_lr` / `atomic_sc` / `atomic_amo_op` flags, the acquire/release bits
  (`aq` / `rl`), and a 5-bit `atomic_alu_op`. `alu_decoder` adds ALU op `101`,
  which bypasses `rs1` so the effective address arrives unmodified at MEM.
- **AMO ALU** (`rtl/amo_alu.sv`): in the memory stage the read-modify-write
  atomics (`amoswap`, `amoadd`, `amoxor`, `amoand`, `amoor`, `amomin[u]`,
  `amomax[u]`, in both `.w` and `.d` widths) combine the loaded value with
  `rs2`; the result is written back into the cache while the original loaded
  value is returned to `rd`. Word variants sign-extend the 32-bit result.
- **LR/SC reservation** (`rtl/dcache.sv`): `LR` records a reservation over the
  accessed word / double-word; `SC` succeeds only while that reservation is
  still valid — writing memory and returning `0` — and otherwise fails,
  returning `1` without writing. Any store landing in the reserved range
  clears the reservation.
- **Faults**: an atomic that targets the MMIO or CLINT window raises an access
  fault — cause `5` (load / AMO) or `7` (store / SC) — instead of touching the
  device.

### Instruction-Fetch Fence (FENCE / FENCE.I)

The core implements the `Zifencei` fences end-to-end:

- **Decode**: `main_decoder` recognises the fence opcode (`0001111`) and raises
  `fencei` only for `FENCE.I` (`func3[0]`); a plain `FENCE` retires as a NOP
  because the in-order pipeline already preserves memory ordering.
- **Dirty write-back**: `FENCE.I` must make prior stores visible to instruction
  fetch, so in the memory stage the D-cache (`rtl/dcache.sv`) walks every set
  and way and writes each dirty line back to main memory. The cache FSM drives
  this multi-cycle drain through its dedicated `WB_FENCEI` / `WB_FENCEI_DONE`
  states.
- **I-cache invalidation**: once the write-back walk completes, the I-cache's
  valid bits are cleared (`invalidate_i`), forcing the next fetch to re-read
  instructions from the now-coherent memory.
- **Front-end redirect & stall**: `rtl/hazard_unit.sv` stalls IF/ID/EX and
  flushes ID + EX while the walk runs (`fencei_wb_start`); the fetch stage then
  redirects the PC to the instruction following the fence (`pc_fencei_mem`) so
  execution resumes with a freshly invalidated I-cache.

### Top-Level Integration

`rtl/top.sv` instantiates the full core:

- `datapath` — the pipelined data-path covering all five stages, plus the
  shared MMU page-table walker and the effective-privilege / translation
  enable logic.
- `hazard_unit` — stall / flush / forward controller (including MMU stalls).
- `cache_fsm` — cache-miss and AXI transaction controller.
- `perf_counters` — `rtl/perf_counters.sv`, which tracks cycles, retired
  instructions, stall cycles, I$/D$ hit/miss, and branch mispredictions, then
  emits them through the `report_perf` DPI-C hook when simulation ends.

The testbench wrapper `rtl/test_env.sv` wires `top` to `mem_simulated`, the
AXI4-Lite bridge, and the MMIO FSM so that Verilator simulations can run
complete programs end-to-end.

## Repository Layout

```
rtl/           SystemVerilog source for the core, MMU/PMP, caches, CLINT, and AXI interface
test/tb/       C/C++ Verilator testbench, Dromajo cosim, trace/self-check helpers
test/tests/    Prebuilt test binaries
scripts/       Test catalog and flow helpers: ELF→disasm, disasm→mem, Spike trace comparison
tools/snippy/  Snippy configuration and test-generation script
tools/dromajo/ Dromajo golden-model submodule (built into libdromajo_cosim.a)
results/       Auto-populated with pass/fail and performance results
run_tests.py   Top-level driver that verilates, builds, runs, and grades tests
```

Key `test/tb/` helpers: `tb_test_env.cpp` (Verilator harness),
`dromajo_cosim.cpp` (Dromajo co-simulation bridge), `check.c` (self-check),
`log_trace.c` (commit-log emitter), `report_perf.c` (performance dump), and
`pmem_write.c` (UART/MMIO write sink).

## Verification

Verification combines up to three independent checks: *Dromajo
co-simulation* that lock-steps the DUT against a golden model every retired
instruction, a *self-check* on the architectural end-state, and a
*trace-compare* against Spike's commit log. By default every applicable
check must agree for a run to be reported `PASS`; the test catalog marks a
handful of tests as cosim-only or no-tracecomp (see below), and the
`--cosim-only` / `--no-cosim` / `--no-tracecomp` flags let any run opt in or
out per check.

The catalog currently holds **378 tests across six suites** (37 AM,
83 riscv-arch-test, 101 riscv-tests physical, 85 riscv-tests virtual,
64 Snippy, 8 custom), and the full matrix passes: every applicable
self-check and trace-compare reports `PASS`, with the remainder N/A
(random Snippy programs) or skipped by design.

### Test Sources

- **AM** — Abstract Machine tests, small hand-written programs that cover
  ISA corner cases and elementary library routines from
  [NJU-ProjectN/am-kernels](https://github.com/NJU-ProjectN/am-kernels).
- **riscv-tests** — the classic per-instruction regression suite from the
  RISC-V community from
  [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests),
  in two builds: the `rv-tests-p` group runs the physical-memory (`-p`)
  binaries and the `rv-tests-v` group the virtual-memory (`-v`) binaries,
  which boot into Sv39 paging and exercise the MMU on every access. Both
  cover the RV64UI base, RV64UM (`M`), and RV64UA (`A` — the `amo*` and
  `lrsc` tests); the physical group additionally runs the RV64MI
  machine-mode tests (misaligned loads/stores, `ma_addr`, `sbreak`,
  `scall`, `zicntr`, `instret_overflow`) and the RV64SI supervisor-mode
  tests (`s-csr`, `s-dirty`, `s-icache-alias`, `s-sbreak`, `s-scall`).
- **riscv-arch-test** — the official RISC-V architectural compliance
  suite from
  [riscv/riscv-arch-test](https://github.com/riscv/riscv-arch-test).
- **Snippy** — randomly generated programs produced by LLVM Snippy from
  [syntacore/snippy](https://github.com/syntacore/snippy) via
  `tools/snippy/snippy_gen_tests.py` using `layout_base.yaml`. Each
  snippet is 500 instructions across 10 functions arranged in 2 call-graph
  layers, drawn from the full RV64I + M instruction histogram.
- **Custom** — local hand-written regressions exercising the privileged and
  interrupt features, including the CSR tests (`custom-csr-test`,
  `custom-csr-test-2`), `custom-ebreak-mret`, the CLINT interrupt suite
  (`custom-clint-msi-test`, `custom-clint-mti-test`, `custom-clint-msi-mti`,
  `custom-clint-mti-irq-regwrite`), and `custom-rtthread`, which boots the
  RT-Thread RTOS on the core. The `am` group likewise adds `am-yield-os`, a
  cooperative-scheduling smoke test.

Test groups and runner names are defined in `scripts/test_catalog.py`, which
also tags the tests that are checked by Dromajo cosim only (e.g.
`custom-rtthread`, `custom-clint-mti-irq-regwrite`, `am-yield-os`) or that
skip Spike tracecomp (the remaining CLINT tests and `custom-csr-test-2`),
because their interrupt timing or random scheduling does not line up with a
single deterministic Spike trace.

### Simulator and Reference Model

- **RTL simulator**: Verilator. The wrapper in `test/tb/tb_test_env.cpp`
  drives `test_env`, toggles the clock, and holds reset for the first 100
  cycles. Simulation terminates when the program reaches `ECALL` /
  `EBREAK` or hits `MAX_SIM_TIME`.
- **Golden reference (trace)**: Spike (`riscv-isa-sim`) is launched by
  `scripts/tracecomp.py` with `spike -d --log-commits` and
  `--isa=rv64imafv_zicntr_zihpm` — a superset of what the core implements.
  Only instructions the DUT actually executes are compared, so the superset
  is safe.
- **Golden reference (co-simulation)**: Dromajo (`tools/dromajo`, built as
  `libdromajo_cosim.a`) runs alongside the RTL. `test/tb/dromajo_cosim.cpp`
  initialises the model with the same ELF, and the write-back stage calls the
  `dromajo_step` DPI-C function once per *retired* instruction to advance the
  model and compare PC, instruction, destination register, and `mstatus`
  (with only the `MPP` field masked). A separate `dromajo_raise_trap` hook
  registers a pending interrupt so the model takes it before the next
  comparison; synchronous exceptions are left for the model to raise itself
  on the faulting instruction. Any mismatch fails the run and is surfaced
  via `dromajo_has_error`.

### Dromajo Co-Simulation Setup

Dromajo is vendored as a git submodule and must be checked out and built once
before co-simulation can run:

```bash
git submodule update --init --recursive
cd tools/dromajo && mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make
```

This produces `libdromajo_cosim.a` and `dromajo_cosim.h`, which the test
driver links into the Verilator harness.

### Commit-Log Format

The DUT emits one line per retiring instruction through
`test/tb/log_trace.c`:

```
PC: 0x<pc>, INSTR: 0x<opcode>, REG x<rd>: 0x<value>, MEM 0x<addr>: 0x<data>
```

Register-write, memory-read, and memory-write fields are only printed when
the corresponding enable is asserted, giving the same shape Spike's
`--log-commits` produces and making a line-by-line diff meaningful. CSR
writes append their own field, `c<addr>_<name>: 0x<value>`, with the
recognised M-mode and S-mode CSRs printed by name. Atomic ops emit both a
register-write and a memory-write field on the same line; `tracecomp.py`
parses Spike's matching `mem <addr> mem <addr> <value>` form so the two
traces stay aligned (and so a zero-`rd` AMO is not mis-read as a hex value).

`ECALL` / `EBREAK` retire as tagged `ecall` / `ebreak` lines and normally
end the trace. Under `-C` (continue-after-trap) the trace instead ends at
the first self-loop jump (`j .`) or — for riscv-tests — at the committing
store to `tohost` (`0x80001000`), which is the same event that stops Spike,
so both traces cover the identical retirement window.

### Self-Check (Architectural End-State)

`test/tb/check.c` is called once the simulation finishes and inspects:

- `a0` (return code): `0` → PASS, `1` → FAIL, anything else → undefined.
- `mcause`: reported by name for the full implemented set — environment
  calls from U/S/M and breakpoint for a standard exit, plus illegal
  instruction, instruction/load/store misalignment, access faults (PMP),
  page faults (MMU), and the machine/supervisor timer and software
  interrupt codes.
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
- Dromajo (the `tools/dromajo` submodule) built with CMake for co-simulation
- Python 3, GCC, Make, CMake

### Running Tests

The `run_tests.py` driver handles Verilator compilation, simulation, Dromajo
co-simulation, Spike comparison, and result aggregation. Invoked with no
operation flag it runs the default CLINT interrupt suite.

For normal `-s`, `-g`, and `-a` runs, the script uses the current saved
defaults from `rtl/test_env.sv` (`BLOCK_WIDTH`) and `rtl/dcache.sv`
(`SET_COUNT` and associativity `N`). A `-v` sweep temporarily overrides
`BLOCK_WIDTH` and `SET_COUNT` only — associativity `N` stays at its saved
default (`4`) because the D-cache is not parameterized for other widths — then
the original defaults are restored at the end of the run.

```bash
# Run the default CLINT interrupt suite (no operation flag)
python3 run_tests.py

# List every available test, grouped by suite with a per-group summary
python3 run_tests.py -l

# Run the full test matrix
python3 run_tests.py -a

# Run a single test and dump a waveform
python3 run_tests.py -s <test_name> -t

# Run only Dromajo co-simulation (skip self-check and Spike tracecomp)
python3 run_tests.py -s <test_name> --cosim-only

# Run without Dromajo co-simulation, keeping self-check and Spike tracecomp
python3 run_tests.py -s <test_name> --no-cosim

# Run without Spike trace logging/comparison (cosim + self-check still run)
python3 run_tests.py -s <test_name> --no-tracecomp

# Run every test past the ecall/ebreak trap instead of finishing on it
python3 run_tests.py -a -C

# Show Verilator warnings and the warning count during a test build
python3 run_tests.py -s <test_name> -w

# Run a group: am | rv-arch-test | rv-tests-p | rv-tests-v | snippy | custom
python3 run_tests.py -g rv-tests-v

# Lint one RTL module with Verilator
python3 run_tests.py -L <module_name>

# Sweep BLOCK_WIDTH and SET_COUNT (associativity held at N=4) for one test
python3 run_tests.py -s <test_name> -v

# Sweep the same cache parameters for a test group
python3 run_tests.py -g rv-tests-p -v

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
`BLOCK_WIDTH`, `SET_COUNT`, and associativity (fixed at `4`) for each sweep
point.
