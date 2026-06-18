import sys
import subprocess
import time
import os
import signal
from pathlib import Path

from test_catalog import custom_trap_continuation_tests

log_file = "trace.log"
CSR_OPCODE = 0x73
MRET_INSTRUCTION = "0x30200073"
SELF_LOOP_INSTRUCTION = "0x0000006f"
TRAP_CONTINUATION_TESTS = custom_trap_continuation_tests()
CSR_NAMES = {
    0x300: "mstatus",
    0x304: "mie",
    0x305: "mtvec",
    0x341: "mepc",
    0x342: "mcause",
    0x344: "mip",
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


def format_trace_entry(log):
    log_line = "PC: " + log["pc"] + ", INSTR: " + log["instruction"]
    if log["register"] is not None:
        log_line += ", REG " + log["register"] + ": " + format_64_hex(log["value"])
        if log["mem"] is not None:
            log_line += ", MEM " + log["mem"]
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
    trap_return_seen = False
    for line in log_contents.splitlines():
        if continue_after_trap:
            if MRET_INSTRUCTION in line:
                trap_return_seen = True
            if SELF_LOOP_INSTRUCTION in line:
                if trap_return_seen:
                    break
                continue
        if (
            "xrv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0" in line
            or "_pmem_start" in line
            or "$x" in line
        ):
            not_pass = 1
        if "ecall" in line or ("ebreak" in line and not continue_after_trap):
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
        log = {
            "pc": line_split[3],
            "instruction": line_split[4][1:-1],
            "register": None,
            "value": None,
            "mem": None,
            "mem_value": None,
            "csr_addr": None,
            "csr_value": None,
        }

        if continue_after_trap and log["instruction"] == SELF_LOOP_INSTRUCTION:
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

        decoded_csr_addr = decode_csr_addr(log["instruction"])
        if (
            decoded_csr_addr is not None
            and log["csr_value"] is None
            and log["value"] is not None
        ):
            log["csr_addr"] = decoded_csr_addr
            log["csr_value"] = log["value"]

        if continue_after_trap and log["instruction"] == MRET_INSTRUCTION:
            log["csr_addr"] = None
            log["csr_value"] = None

        log_data.append(log)

    return log_data


def trace_stop_found(contents, continue_after_trap):
    if continue_after_trap:
        return terminal_self_loop_found(contents) or "ecall" in contents

    return (
        "ecall" in contents
        or "ebreak" in contents
        or "exception trap" in contents
    )


def terminal_self_loop_found(contents):
    trap_return_seen = False
    for line in contents.splitlines():
        if MRET_INSTRUCTION in line:
            trap_return_seen = True
        elif trap_return_seen and SELF_LOOP_INSTRUCTION in line:
            return True
    return False


# Read the log file and print its contents
def parse_log(filename, continue_after_trap=False):
    cmd = ["spike", "-d", "--log-commits", filename]

    with open(log_file, "w") as log_output:
        process = subprocess.Popen(cmd, stderr=log_output)

    try:
        while True:
            with open(log_file, "r") as f:
                contents = f.read()
                if trace_stop_found(contents, continue_after_trap):
                    print("trace stop point found, stopping trace.")
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
    return parse_log_contents(log_contents, continue_after_trap)


def main(test_name, test_path):
    trace_log_dir = Path("spike_log_trace")
    trace_log_dir.mkdir(parents=True, exist_ok=True)

    trace_log_file = trace_log_dir / (test_name + "-log-trace.log")
    original_log_file = trace_log_dir / (test_name + "-spike-original.log")
    print("Trace log file: " + str(trace_log_file))
    print("Original Spike log file: " + str(original_log_file))
    trace_log = parse_log(test_path, test_name in TRAP_CONTINUATION_TESTS)
    log_lines = []

    for log in trace_log:
        log_lines.append(format_trace_entry(log))

    with open(trace_log_file, "w") as f_out:
        f_out.writelines(log_lines)
    os.replace(log_file, original_log_file)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 file.py <test_name> <test_path>")
        sys.exit(1)

    test_name = sys.argv[1]
    test_path = sys.argv[2]
    main(test_name, test_path)
