import argparse
import sys
import subprocess
import time
import os
import signal
from pathlib import Path

from test_catalog import trap_continuation_tests

CSR_OPCODE = 0x73
SELF_LOOP_INSTRUCTION = "0x0000006f"
# The encoding token as Spike prints it, e.g. "core 0: 3 0x... (0x0000006f)".
# Matching the parenthesized form pins the check to the instruction encoding and
# cannot fire on a register/memory operand that merely contains the value.
SELF_LOOP_TOKEN = f"({SELF_LOOP_INSTRUCTION})"
ECALL_INSTRUCTION = "0x00000073"
EBREAK_INSTRUCTION = "0x00100073"
# The riscv-tests family links the program entry (reset vector) at 0x8000_0000,
# which is where the RTL trace begins. Spike prints the fetched pc immediately
# followed by the "(0x<encoding>)" token, so matching pc + " (0x" pins the trigger
# to the reset-vector *instruction* line (interactive echo or commit line) without
# firing on a register/memory operand that merely holds the address 0x8000_0000
# (e.g. the bootrom `ld` that loads it into a register before jumping there).
RESET_VECTOR_MARKER = "0x0000000080000000 (0x"
# ecall/ebreak are emitted as regular trace entries annotated with the mnemonic.
TRAP_MNEMONICS = {
    ECALL_INSTRUCTION: "ecall",
    EBREAK_INSTRUCTION: "ebreak",
}
# Spike prints the encoding in parentheses, e.g. "(0x00000073)"; the token is
# unique per trap instruction, which lets us recover the pc next to it.
TRAP_INSTRUCTION_TOKENS = {
    f"({instruction})": instruction for instruction in TRAP_MNEMONICS
}
TRAP_CONTINUATION_TESTS = trap_continuation_tests()
CSR_NAMES = {
    # M-mode CSRs.
    0x300: "mstatus",
    0x301: "misa",
    0x302: "medeleg",
    0x303: "mideleg",
    0x304: "mie",
    0x305: "mtvec",
    0x340: "mscratch",
    0x341: "mepc",
    0x342: "mcause",
    0x343: "mtval",
    0x344: "mip",
    0xF11: "mvendorid",
    0xF12: "marchid",
    0xF13: "mimpid",
    0xF14: "mhartid",
    # S-mode CSRs.
    0x100: "sstatus",
    0x104: "sie",
    0x105: "stvec",
    0x140: "sscratch",
    0x141: "sepc",
    0x142: "scause",
    0x143: "stval",
    0x144: "sip",
    0x14D: "stimecmp",
    0xC01: "time",
}


def format_64_hex(value):
    return f"0x{int(value, 16):016x}"


def is_gpr_token(token):
    return len(token) > 1 and token[0] == "x" and token[1:].isdigit()


def parse_csr_token(token):
    if len(token) < 2 or token[0] != "c":
        return None

    csr_number = token[1:].split("_", 1)[0]
    if not csr_number.isdigit():
        return None
    return int(csr_number, 10)


def decode_csr_addr(instruction):
    instruction_value = int(instruction, 16)
    opcode = instruction_value & 0x7F
    func3 = (instruction_value >> 12) & 0x7
    if opcode != CSR_OPCODE or func3 == 0:
        return None
    return (instruction_value >> 20) & 0xFFF


def format_csr_log(csr_addr, csr_value):
    csr_name = CSR_NAMES.get(csr_addr)
    csr_label = f"c{csr_addr}_{csr_name}" if csr_name is not None else f"c{csr_addr}"
    return f", {csr_label}: {format_64_hex(csr_value)}"


def parse_trap_disasm(line):
    """Return (pc, instruction) if `line` is a Spike disasm line for an
    ecall/ebreak, else None.

    Spike never emits a normal commit line for ecall/ebreak; the instruction
    only shows up in the interactive disasm line (e.g.
    "... 0x<pc> (0x00000073) ecall"). The encoding token is unique, so the pc
    is simply the hex token right before it -- this works whether or not the
    line carries the "(spike)" prompt prefix (which shifts the columns)."""
    tokens = line.split()
    for index in range(1, len(tokens)):
        instruction = TRAP_INSTRUCTION_TOKENS.get(tokens[index])
        if instruction is None:
            continue
        pc = tokens[index - 1]
        if pc.startswith("0x"):
            return pc, instruction
    return None


def format_trace_entry(log):
    log_line = log["priv_mode"] + " PC: " + log["pc"] + ", INSTR: " + log["instruction"]
    mnemonic = TRAP_MNEMONICS.get(log["instruction"])
    if mnemonic is not None:
        # ecall/ebreak: no register/memory/CSR side effects are recorded, just
        # the mnemonic -- matching the RTL trace.
        return log_line + ", " + mnemonic + "\n"
    if log["register"] is not None:
        log_line += ", REG " + log["register"] + ": " + format_64_hex(log["value"])
        if log["mem"] is not None:
            log_line += ", MEM " + log["mem"]
            # Atomic memory op (AMO): writes a register *and* memory. Spike
            # supplies the written value, so log it alongside the address,
            # matching the RTL trace. Loads/LR have no write value (None).
            if log["mem_value"] is not None:
                log_line += ": " + format_64_hex(log["mem_value"])
        elif log["csr_value"] is not None:
            log_line += format_csr_log(log["csr_addr"], log["csr_value"])
    elif log["mem"] is not None:
        if log["mem_value"] is not None:
            log_line += ", MEM " + log["mem"] + ": " + format_64_hex(log["mem_value"])
        else:
            log_line += ", MEM " + log["mem"]
    elif log["csr_value"] is not None:
        log_line += format_csr_log(log["csr_addr"], log["csr_value"])
    return log_line + "\n"


def parse_log_contents(log_contents, continue_after_trap=False):
    content = []
    pass_next = 0
    not_pass = 0
    for line in log_contents.splitlines():
        # A retired self-loop (jal x0, 0) ends the run in every mode: the RTL
        # stops the simulation there (check_self_loop) and excludes the line
        # from its trace (log_trace.c), so end the Spike trace just before it.
        if SELF_LOOP_TOKEN in line:
            break
        # Start capturing at the reset vector. The mi/si-mode riscv-tests ELFs
        # lack the "$x<arch>" mapping symbol the base tests carry, so the reset
        # vector is the reliable, ELF-independent start of the program; the
        # symbol-name markers remain as fallbacks for programs that begin
        # elsewhere.
        if (
            RESET_VECTOR_MARKER in line
            or "xrv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0" in line
            or "_pmem_start" in line
            or "$x" in line
        ):
            not_pass = 1
        if not_pass:
            trap = parse_trap_disasm(line)
            if trap is not None:
                pc, instruction = trap
                # Synthesize a commit-style line the parser below turns into a
                # trace entry; format_trace_entry adds the mnemonic.
                content.append(
                    f"core 0: - {pc} ({instruction}) {TRAP_MNEMONICS[instruction]}"
                )
                if not continue_after_trap:
                    # The run stops at the trap: nothing after it is traced.
                    break
                continue
        if not continue_after_trap and ("ecall" in line or "ebreak" in line):
            not_pass = 0
        if not_pass:
            if (
                "(spike)" in line or ">>>>" in line or "exception" in line or pass_next
            ):  # ignore the interactive traces
                if pass_next:
                    pass_next = 0
                if ">>>>" in line:
                    pass_next = 1
                continue
            else:
                content.append(line)
        else:
            continue
    log_data = []
    for line in content:
        line_split = line.split()
        if len(line_split) < 5:
            continue
        # A real commit line carries the encoding as "(0x<instr>)" at index 4.
        # Interactive disasm echoes ("... j pc + 0x50") and HTIF banners
        # ("*** FAILED *** (tohost = 668)") don't, so skip them rather than
        # mis-parsing an operand as the instruction (which crashes on int('',16)).
        if not (line_split[4].startswith("(0x") and line_split[4].endswith(")")):
            continue
        log = {
            "priv_mode": line_split[2],
            "pc": line_split[3],
            "instruction": line_split[4][1:-1],
            "register": None,
            "value": None,
            "mem": None,
            "mem_value": None,
            "csr_addr": None,
            "csr_value": None,
        }

        if log["instruction"] == SELF_LOOP_INSTRUCTION:
            break

        token_index = 5
        while token_index < len(line_split):
            token = line_split[token_index]
            if is_gpr_token(token) and token_index + 1 < len(line_split):
                log["register"] = token
                log["value"] = line_split[token_index + 1]
                token_index += 2
                continue

            if token == "mem" and token_index + 1 < len(line_split):
                # Atomics (AMO/LR/SC variants that both read and write) are
                # printed by Spike as "mem <read_addr> mem <write_addr>
                # <write_value>". Capture the write address/value so the line
                # matches the RTL log, which records the atomic's memory write
                # exactly like a store. This also avoids treating the second
                # "mem" token as a hex value (which would crash on rd=x0 AMOs).
                if (
                    token_index + 4 < len(line_split)
                    and line_split[token_index + 2] == "mem"
                ):
                    log["mem"] = line_split[token_index + 3]
                    log["mem_value"] = line_split[token_index + 4]
                    token_index += 5
                    continue

                log["mem"] = line_split[token_index + 1]
                if token_index + 2 < len(line_split):
                    log["mem_value"] = line_split[token_index + 2]
                    token_index += 3
                else:
                    token_index += 2
                continue

            csr_addr = parse_csr_token(token)
            if csr_addr is not None and token_index + 1 < len(line_split):
                log["csr_addr"] = csr_addr
                log["csr_value"] = line_split[token_index + 1]
                token_index += 2
                continue

            token_index += 1

        # decoded_csr_addr = decode_csr_addr(log["instruction"])
        # if (
        #     decoded_csr_addr is not None
        #     and log["csr_value"] is None
        #     and log["value"] is not None
        # ):
        #     log["csr_addr"] = decoded_csr_addr
        #     log["csr_value"] = log["value"]

        log_data.append(log)

    return log_data


def trace_stop_found(contents, continue_after_trap):
    # A committed self-loop parks the program forever, so nothing meaningful
    # can follow it in any mode: stop Spike there (matches the RTL stop).
    if SELF_LOOP_TOKEN in contents:
        return True
    if continue_after_trap:
        return "ecall" in contents

    # Only ebreak/ecall end a run. Other exceptions (illegal instruction,
    # address-misaligned, ...) are serviced by the program's trap handler, so
    # they must not cut the Spike trace short before the terminating ecall/ebreak.
    return "ecall" in contents or "ebreak" in contents


# Read the log file and print its contents
def parse_log(filename, scratch_log, continue_after_trap=False, timeout_seconds=None):
    cmd = [
        "spike",
        "-d",
        "--log-commits",
        "--isa=rv64imafv_zicsr_zifencei_zihpm_sstc_zicntr",
        filename,
    ]

    log_file = str(scratch_log)
    Path(log_file).parent.mkdir(parents=True, exist_ok=True)
    with open(log_file, "w") as log_output:
        process = subprocess.Popen(cmd, stderr=log_output)

    start_time = time.monotonic()
    timed_out = False
    try:
        while True:
            with open(log_file, "r") as f:
                contents = f.read()
                if trace_stop_found(contents, continue_after_trap):
                    print("trace stop point found, stopping trace.")
                    process.terminate()
                    break
            # Spike can also end on its own -- e.g. an HTIF tohost pass/fail write
            # terminates the run without ever executing an ecall/ebreak. Stop
            # polling once it has exited so we parse what we have instead of
            # spinning on a dead process until the external timeout.
            if process.poll() is not None:
                print("spike exited on its own, stopping trace.")
                break
            # Spike never reaching the stop point (e.g. the program diverges or
            # loops) must not spin here until the driver's SIGKILL, which would
            # discard the trace and leave spike orphaned: kill spike ourselves
            # and keep whatever it logged so far.
            if (
                timeout_seconds is not None
                and time.monotonic() - start_time > timeout_seconds
            ):
                print(
                    f"no trace stop point within {timeout_seconds} seconds, "
                    "terminating spike and keeping the partial trace."
                )
                timed_out = True
                process.terminate()
                break
            time.sleep(0.01 if continue_after_trap else 0.1)
    except KeyboardInterrupt:
        print("KeyboardInterrupt received, stopping trace.")
        process.terminate()

    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()

    with open(log_file, "r") as f:
        log_contents = f.read()
    return parse_log_contents(log_contents, continue_after_trap), timed_out


def main(
    test_name,
    test_path,
    force_continue_after_trap=False,
    timeout_seconds=None,
    out_dir="spike_log_trace",
    scratch_log="trace.log",
):
    trace_log_dir = Path(out_dir)
    trace_log_dir.mkdir(parents=True, exist_ok=True)

    trace_log_file = trace_log_dir / (test_name + "-log-trace.log")
    original_log_file = trace_log_dir / (test_name + "-spike-original.log")
    print("Trace log file: " + str(trace_log_file))
    print("Original Spike log file: " + str(original_log_file))
    # -C (forwarded by run_tests.py) or the per-test list both enable running the
    # Spike trace past the ebreak/ecall trap, matching the RTL simulation.
    continue_after_trap = (
        force_continue_after_trap or test_name in TRAP_CONTINUATION_TESTS
    )
    trace_log, timed_out = parse_log(
        test_path, scratch_log, continue_after_trap, timeout_seconds
    )
    log_lines = []

    for log in trace_log:
        log_lines.append(format_trace_entry(log))

    with open(trace_log_file, "w") as f_out:
        f_out.writelines(log_lines)
    os.replace(scratch_log, original_log_file)

    if timed_out:
        if log_lines:
            print("last traced instruction: " + log_lines[-1].strip())
        print(
            f"Error: spike never reached the trace stop point; partial traces "
            f"kept at {trace_log_file} and {original_log_file}"
        )
        return 1
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a normalized Spike reference trace for a test."
    )
    parser.add_argument("test_name", help="test name used for the output file names")
    parser.add_argument("test_path", help="ELF file passed to Spike")
    parser.add_argument(
        "-C",
        "--continue-after-trap",
        action="store_true",
        help="run the trace past the terminating ebreak/ecall trap",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=None,
        metavar="seconds",
        help="kill Spike after this many seconds and keep the partial trace",
    )
    parser.add_argument(
        "--out-dir",
        default="spike_log_trace",
        metavar="dir",
        help="directory for the normalized and raw Spike trace files",
    )
    parser.add_argument(
        "--scratch-log",
        default="trace.log",
        metavar="file",
        help="scratch file capturing Spike's stderr while it runs",
    )
    cli_args = parser.parse_args()

    sys.exit(
        main(
            cli_args.test_name,
            cli_args.test_path,
            cli_args.continue_after_trap,
            cli_args.timeout,
            cli_args.out_dir,
            cli_args.scratch_log,
        )
    )
