import pexpect
import os
import sys

log_file = open("spike_output.txt", "wb")

# Read the log file and print its contents
def parse_log(filename):
    cmd = "spike -d --log-commits " + " 2> trace.log" + " " + filename
    child = pexpect.spawn("/bin/sh", ["-c", cmd])

    child.logfile_read = log_file
    child.expect(pexpect.EOF, timeout=None)

    log_file.close()
    os.remove("spike_output.txt")
    log_contents = ""
    with open("trace.log", "r") as f:
        log_contents = f.read()
    content = []
    pass_next = 0
    not_pass = 0
    for line in log_contents.splitlines():
        if "xrv64i2p1_m2p0_a2p1_f2p2_d2p2_zicsr2p0_zifencei2p0_zmmul1p0" in line:
            not_pass = 1
        if "ecall" in line:
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
    # print(len(content))
    log_data = []
    for line in content:
        line_split = line.split()
        log = {}
        if "tval" in line:
            log = {
                "pc": "0x00000000800000e0",
                "instruction": "0x00000013",
                "register": None,
                "value": None,
                "mem": None,
                "mem_value": None
            }
            log_data.append(log)
            continue
        if "0x0ff0000f" in line:
            log = {
                "pc": line_split[3],
                "instruction": "0x00000013",
                "register": None,
                "value": None,
                "mem": None,
                "mem_value": None
            }
            log_data.append(log)
            continue
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
            else:
                log["mem"] = line_split[6]
                log["mem_value"] = line_split[7]  # store
                log["register"] = None
                log["value"] = None
        else:
            log["mem"] = None
            log["mem_value"] = None
        log_data.append(log)
    start = 0
    count = 0
    first_found = False
    for log in log_data:
        if log["instruction"] == "0xf1402573":
            if not first_found:
                start_pc_str = log["pc"]
                start_pc_int = int(start_pc_str, 16)
                first_found = True
        if log["instruction"] == "0x00200193":
            end_pc_str = log["pc"]
            end_pc_int = int(end_pc_str, 16)
            break

    log_trace_data = []
    replaced = False
    for log in log_data:
        pc_value_str = log["pc"]
        pc_value_int = int(pc_value_str, 16)
        if ((pc_value_int >= start_pc_int) and (pc_value_int < end_pc_int)):
            if not replaced: 
                range_i = (end_pc_int - start_pc_int)/4
                new_pc_int = pc_value_int
                for i in range(int(range_i)):
                    new_pc_formatted = f"0x{new_pc_int:016x}"
                    log_new = {
                        "pc": new_pc_formatted,
                        "instruction": "0x00000013",
                        "register": None,
                        "value": None,
                        "mem": None,
                        "mem_value": None
                    }
                    new_pc_int += 4
                    log_trace_data.append(log_new)
                replaced = True
        else:
            log_trace_data.append(log)
    return log_trace_data


def main(test_name, test_path):
    trace_log_file = "./spike_log_trace/" + test_name + "-log-trace.log"
    trace_log = parse_log(test_path)
    log_lines = []

    for log in trace_log:
        log_line = "PC: " + log["pc"] + ", INSTR: " + log["instruction"]
        if log["register"] is not None:
            log_line += ", REG " + log["register"] + ": " + log["value"]
            if log["mem"] is not None:
                log_line += ", MEM " + log["mem"]
        elif log["mem"] is not None:
            mem_value_str = log["mem_value"]
            mem_value_int = int(mem_value_str, 16)
            mem_value_formatted = f"0x{mem_value_int:016x}"
            log_line += ", MEM " + log["mem"] + ": " + mem_value_formatted
        log_line += "\n"
        log_lines.append(log_line)

    with open(trace_log_file, 'w') as f_out:
        f_out.writelines(log_lines)
    os.remove("trace.log")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 file.py <test_name> <test_path>")
        sys.exit(1)

    test_name = sys.argv[1]
    test_path = sys.argv[2]
    main(test_name, test_path)