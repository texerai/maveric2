# MAVERIC Core 2.0 — Technical Quick Reference

**Project**: Open-source 5-stage pipelined RISC-V processor (SystemVerilog)  
**Source**: https://github.com/olzhasnurman/maveric_core.git  
**Current ISA**: RV64I + W-variant ops; extensible to M, Zicsr, Zifencei, privilege modes

---

## 1. Core Architecture at a Glance

| Aspect | Specification |
|--------|---------------|
| **ISA** | 64-bit RISC-V (RV64I base + W ops) |
| **Address width** | 64-bit (32-bit instructions) |
| **Pipeline** | 5 stages: IF → ID → EX → MEM → WB |
| **Registers** | 32 × 64-bit GPRs (sync write, async read) |
| **BTB** | 4-way set-associative, 16 sets (configurable) |
| **BHT** | 64 entries, 2-bit saturating counters |
| **Caches** | I-cache (direct-mapped, 16 blocks), D-cache (4-way, write-back/allocate) |
| **Memory IF** | AXI4-Lite master (64-bit addr, 32-bit data) |

---

## 2. Pipeline Stages & Key Files

### **Fetch (IF)** — `rtl/fetch_stage.sv`
- Drives PC, consults I-cache
- Queries branch predictor for taken branches / BTB hits
- Predicted target, direction, and BTB way flow down pipeline for EX validation

### **Decode (ID)** — `rtl/decode_stage.sv`
- Instruction split via `instr_decoder`
- ALU / memory / branch control from `main_decoder` + `alu_decoder`
- GPR read from `register_file`
- Immediate sign-/zero-extend via `extend_imm`

### **Execute (EX)** — `rtl/execute_stage.sv`
- 64-bit ALU
- Three-way forwarding mux (no-forward / EX-MEM / MEM-WB)
- Branch resolution; misprediction flushes IF + ID, retargets PC
- **Mispred signal**: `branch_mispred_exec_o`

### **Memory (MEM)** — `rtl/memory_stage.sv`
- D-cache access (loads / stores)
- Store widths: `00`=SB, `01`=SH, `10`=SW, `11`=SD
- Misaligned stores raise `store_addr_ma` exception
- Load re-alignment & sign-/zero-extend via `load_mux`

### **Write-Back (WB)** — `rtl/write_back_stage.sv`
- Selects ALU result / load data / PC+4 / immediate
- Commits to register file on rising edge

---

## 3. Hazard Control & Forwarding

**File**: `rtl/hazard_unit.sv`

### **RAW Forwarding**
- Each source register: 2-bit select
  - `10` → forward from EX/MEM
  - `01` → forward from MEM/WB
  - `00` → use regfile read
- Both `rs1` and `rs2` independent; prioritise younger producer (EX/MEM over MEM/WB)

### **Load-Use Interlock**
- EX-stage load dest matches decode-stage source → stall IF/ID, bubble EX for 1 cycle

### **Flush Behaviour**
- Branch mispred in EX → flush ID + EX; front-end retargets to correct target

### **Cache Stalls**
- `stall_cache_i` from FSM freezes every stage during I/D-cache miss

---

## 4. Branch Prediction Unit

**File**: `rtl/branch_pred_unit.sv` + `rtl/btb.sv` + `rtl/bht.sv`

### **BTB** (Branch Target Buffer)
- 4-way set-associative, 16 sets (default: configurable `SET_COUNT`, `N=4`)
- Per entry: 60-bit tag (branch instr addr), 64-bit target, valid bit
- Returns way hit so EX can update correct entry on mispredict

### **BHT** (Branch History Table)
- 64 entries of 2-bit saturating counters
  - `00` = strongly not-taken
  - `11` = strongly taken
- Updated in EX based on actual outcome; IF consults in parallel with BTB

### **Resolution**
- EX compares predicted direction & target vs. resolved values
- Mismatch → `branch_mispred_exec_o` triggers front-end flush & BTB/BHT write-back

### **Reporting**
- Each run prints total branches and mispredictions (see `test/tb/check.c`)
- Prediction accuracy tracked per test

---

## 5. Cache Hierarchy & Memory

### **I-Cache** — `rtl/icache.sv`
- Direct-mapped
- 16 blocks (default, configurable `BLOCK_WIDTH`)
- Read-only from pipeline; refilled on miss by FSM

### **D-Cache** — `rtl/dcache.sv`
- 4-way set-associative, write-back / write-allocate
- Dirty bit per way
- Eviction of dirty way → `WRITE_BACK` state before re-allocate

### **Cache FSM** — `rtl/cache_fsm.sv`
- 4 states: `IDLE → ALLOCATE_I → IDLE`, `IDLE → ALLOCATE_D → IDLE`, `IDLE → WRITE_BACK → ALLOCATE_D → IDLE`
- Data misses prioritised over instruction misses (prevent deadlock on load)

### **Refill Line**
- Default: 512-bit (configurable at elaboration via `BLOCK_WIDTH`)
- Streamed as `BLOCK_WIDTH / 32` beats by `cache_data_transfer.sv`

### **Reconfigurability**
- `run_tests.py -v` sweeps `BLOCK_WIDTH` (128–1024 b), `SET_COUNT` (2–16), D-cache `N` (2–8 way)
- Regenerates performance numbers per combination

---

## 6. AXI4-Lite Memory Interface

**Files**: `rtl/axi4_lite_master.sv` (split into read/write), + slave pair for simulation

- 64-bit address, 32-bit data per beat
- Cache lines streamed as multiple beats
- Beat counter & `count_done` assertion by `cache_data_transfer.sv`
- External memory: `rtl/mem_simulated.sv` (loads test image from hex file via `scripts/disasm2mem.py`)

---

## 7. Top-Level Integration

**File**: `rtl/top.sv`

- `datapath` — five-stage pipeline
- `hazard_unit` — stall / flush / forward controller
- `cache_fsm` — cache-miss & AXI transaction controller

**Testbench wrapper**: `rtl/test_env.sv` wires `top` → `mem_simulated` + AXI4-Lite bridge

---

## 8. Verification Strategy

### **Dual Pass Criteria**
1. **Self-Check** — architectural end-state (return code, exceptions, branch stats)
2. **Trace-Compare** — full instruction stream vs. Spike golden reference
- **Result**: `PASS` only when both agree

### **Test Sources**

| Suite | Source | File List |
|-------|--------|-----------|
| **AM** | Abstract Machine (hand-written corner cases) | `test/tests/list/list-am.txt` |
| **riscv-tests** | Classic per-instruction regression | `test/tests/list/list-rv-tests.txt` |
| **riscv-arch-test** | Official RISC-V arch compliance | `test/tests/list/list-rv-arch-test.txt` |
| **Snippy** | LLVM-generated random programs (500 instr, 10 fn, 2-layer call graph) | `test/tests/list/list-snippy.txt` |

### **Simulators**

- **RTL**: Verilator (`test/tb/tb_test_env.cpp`); terminates on `ECALL`/`EBREAK` or `MAX_SIM_TIME`
- **Golden**: Spike with `rv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0` ISA string (superset; only executed instructions compared)

### **Commit-Log Format**

```
PC: 0x<pc>, INSTR: 0x<opcode>, REG x<rd>: 0x<value>, MEM 0x<addr>: 0x<data>
```
- `ECALL` (0x73) suppressed to avoid polluting exit log
- Register-write, memory-read, memory-write fields printed only when asserted

### **Self-Check** (`test/tb/check.c`)

| Register / Signal | Interpretation |
|-------------------|-----------------|
| `a0` | `0` = PASS, `1` = FAIL, else = undefined |
| `mcause = 11` | Standard exit via ECALL |
| `mcause = 3` | Standard exit via EBREAK |
| `mcause = 2` | Illegal instruction |
| `mcause = 0, 4, 6` | Instr/load/store address misaligned |
| `branch_total`, `branch_mispred` | Read and report predictor accuracy |

### **Trace-Compare Flow** (`scripts/tracecomp.py`)

1. Spawn Spike in commit-log mode on same ELF
2. Stream Spike log; stop at `ecall`, `ebreak`, or exception
3. Parse each commit into dict (PC / instr / reg / value / mem addr / mem value)
4. Write normalised Spike log to `spike_log_trace/<test>-log-trace.log`
5. RTL log written to `log_trace/<test>-log-trace.log`
6. `run_tests.py` runs `diff`; first mismatch (≤10 lines) kept in `temp.txt`

---

## 9. Repository Layout

```
rtl/                  SystemVerilog source (core, caches, AXI)
test/tb/              C/C++ Verilator testbench & trace helpers
test/tests/           Prebuilt test binaries & lists
scripts/              Flow helpers (ELF→disasm, disasm→mem, Spike compare)
tools/snippy/         Snippy config & test-generation script
results/              Auto-populated pass/fail & perf results
run_tests.py          Top-level driver (Verilate, build, run, grade)
```

---

## 10. Performance Monitoring

**File**: `results/perf_result.txt`

Per test, records:
- Retired instruction count
- Total cycles
- **IPC** (instructions per cycle)
- **Stall breakdown**: load-use, cache-miss, branch-flush
- **Branch predictor hit rate**

Combined with `-v` (cache sweep) to track performance impact of cache geometry changes.

---

## 11. Running Tests

### **Command Patterns**

```bash
# List all tests
python3 run_tests.py -l

# Run full test matrix
python3 run_tests.py -a

# Single test + waveform
python3 run_tests.py -s <test_name> -t

# Test group (am | rv-tests | rv-arch-test | snippy)
python3 run_tests.py -g rv-arch-test

# Sweep cache (BLOCK_WIDTH, SET_COUNT, associativity) for one test
python3 run_tests.py -s <test_name> -v

# Sweep cache for group
python3 run_tests.py -g rv-tests -v

# Full sweep
python3 run_tests.py -a -v

# Coverage (line + toggle)
python3 run_tests.py -a --coverage-all

# Clean before commit
python3 run_tests.py -p
```

### **Output Files**

- `results/result.txt` — pass/fail summaries
- `results/perf_result.txt` — IPC, stall counts, cache config headers for `-v` runs
- `cov/` — per-test coverage files (sweep-separated)
- `coverage_annotated/` — merged, annotated coverage

---

## 12. Dependencies

- Verilator (with `--trace`, `--coverage`)
- RISC-V GNU toolchain (ELF/disassembly manipulation)
- Spike (`riscv-isa-sim`)
- Python 3, GCC, Make

---

## 13. Key Upgrade Points for Linux Support

When extending MAVERIC Core 2.0 toward Linux (MMU, privilege modes, etc.):

### **Currently Implemented**
- ECALL / EBREAK exception generation
- Branch prediction with BTB/BHT
- Write-back caches with store buffer / eviction
- AXI4-Lite memory interface

### **Planned (or In Progress)**
- **RV64M** — multi-cycle multiply, divide, remainder (in progress)
- **Privilege modes** — M-mode as primary (Trap Vector Base, exception handler)
- **Zicsr extension** — Control & Status Registers (mcause, mtvec, etc.)
- **Zifencei extension** — Instruction-cache fencing (fence.i)
- **RAS** — Return Address Stack in branch prediction
- **Performance counters** — CPI, cache hit rates, stall attribution
- **MMU & virtual memory** — Paging, TLB, page-fault handling

### **Test Strategy for Extensions**
1. Use llvm-snippy to generate M-instruction sequences; validate against Spike
2. Extend riscv-arch-tests coverage for new extensions
3. Maintain trace-compare on all existing AM / riscv-tests baseline
4. Performance sweep cache params after each feature to track IPC / stall impact

---

## 14. Key Files to Monitor During Upgrades

| File | Purpose |
|------|---------|
| `rtl/top.sv` | Instantiation point; register new modules here |
| `rtl/execute_stage.sv` | ALU, branch resolution; add M ops here |
| `rtl/main_decoder.sv` | Instruction decoding; add opcode support |
| `rtl/hazard_unit.sv` | Pipeline control; update forward/stall logic if adding new pipeline stage or hazard type |
| `test/tb/check.c` | Self-check harness; add mcause validation for new exceptions |
| `scripts/tracecomp.py` | Trace format parser; ensure new exception codes handled |
| `run_tests.py` | Test driver; may need Spike ISA string update for new extensions |

---

## 15. Quick Debug Workflow

1. **Identify failing test**: `results/result.txt`
2. **Rerun with trace**: `python3 run_tests.py -s <test> -t` → generates `*.vcd`
3. **Compare logs**: `diff log_trace/<test>-log-trace.log spike_log_trace/<test>-log-trace.log`
4. **Check mismatch**: `temp.txt` shows first divergence (≤10 lines)
5. **Inspect waveform**: Open `.vcd` in GTKWave or similar; correlate to cycle of divergence
6. **Validate against Spike**: Run `spike <elf>` manually with `-d --log-commits` if trace output unclear

---

## 16. Notes for Texer.AI Integration

- **Scope**: Upgrade to support Linux; non-blocking, in-order core
- **Immediate priorities**: RV64M (multiply/divide), privilege modes (M-mode), Zicsr, Zifencei
- **Validation loop**: Each feature validated via llvm-snippy generation, Spike comparison, full test-matrix run with performance tracking
- **Infrastructure**: Verification setup is mature; focus on RTL changes and Spike ISA string updates
- **Performance tracking**: Always run with `-v` after major changes to catch cache/stall regressions

---

*Last updated from MAVERIC Core 2.0 README*
