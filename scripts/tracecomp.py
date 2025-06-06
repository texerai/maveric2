import pexpect
import sys
import subprocess
import time
import os
import signal

log_file = 'trace.log'

# Read the log file and print its contents
def parse_log(filename):
    cmd = ["spike", "-d", "--log-commits", filename]

    with open(log_file, "w") as log_output:
        process = subprocess.Popen(cmd, stderr=log_output)

    try:
        while True:
            with open(log_file, "r") as f:
                contents = f.read()
                if "ecall" in contents or "ebreak" in contents:
                    print("ecall or ebreak found, stopping trace.")
                    process.terminate()
                    break
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("KeyboardInterrupt received, stopping trace.")
        process.terminate()

    log_contents = ""
    with open(log_file, "r") as f:
        log_contents = f.read()
    content = []
    pass_next = 0
    not_pass = 0
    for line in log_contents.splitlines():
        if "xrv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0" in line or "_pmem_start" in line:
            not_pass = 1
        if "ecall" in line or "ebreak" in line:
            not_pass = 0
        if not_pass:
            if "(spike)" in line or ">>>>" in line or "exception" in line or pass_next: # ignore the interactive traces
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
        log = {}
        log = {
            "pc": line_split[3],
            "instruction": line_split[4][1:-1]
        }
        if len(line_split) > 5:
            log["register"] = line_split[5]
            log["value"] = line_split[6]
        else:
            log["register"] = None
            log["value"] = None
        if "mem" in line:
            if len(line_split) > 8:
                log["mem"] = line_split[8] #load
                log["mem_value"] = None
            elif len(line_split) == 8:
                log["mem"] = line_split[6]
                log["mem_value"] = line_split[7]  # store
                log["register"] = None
                log["value"] = None
            else:
                log["mem"] = line_split[6]
                log["mem_value"] = None
                log["register"] = None
                log["value"] = None
        else:
            log["mem"] = None
            log["mem_value"] = None
        log_data.append(log)

    return log_data


def main(test_name, test_path):
    trace_log_file = "./spike_log_trace/" + test_name + "-log-trace.log"
    print("Trace log file: " + trace_log_file)
    trace_log = parse_log(test_path)
    log_lines = []

    for log in trace_log:
        log_line = "PC: " + log["pc"] + ", INSTR: " + log["instruction"]
        if log["register"] is not None:
            log_line += ", REG " + log["register"] + ": " + log["value"]
            if log["mem"] is not None:
                log_line += ", MEM " + log["mem"]
        elif log["mem"] is not None:
            if log["mem_value"] is not None:
                mem_value_str = log["mem_value"]
                mem_value_int = int(mem_value_str, 16)
                mem_value_formatted = f"0x{mem_value_int:016x}"
                log_line += ", MEM " + log["mem"] + ": " + mem_value_formatted
            else:
                log_line += ", MEM " + log["mem"]
        log_line += "\n"
        log_lines.append(log_line)

    with open(trace_log_file, 'w') as f_out:
        f_out.writelines(log_lines)
    os.remove(log_file)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 file.py <test_name> <test_path>")
        sys.exit(1)

    test_name = sys.argv[1]
    test_path = sys.argv[2]
    main(test_name, test_path)
