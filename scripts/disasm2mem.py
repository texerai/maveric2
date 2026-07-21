import os
import re

SECTION_ROW_RE = re.compile(r" [0-9a-fA-F]{8} ")


def process_file(input_path, output_path):
    try:
        with open(input_path, "r") as file:
            content = []
            content = file.readlines()
            instruction_lines = []
            lines_splitted = []
            new_instruction_lines = []
            test_line = ""
            valid_line = False
            first_line = True
            new_pc = 0
            old_pc = 0
            old_pc_str = ""
            old_len = 0
            k = 0
            for line in content:
                if "Contents of section .comment:" in line:
                    break
                elif SECTION_ROW_RE.match(line):
                    valid_line = True
                else:
                    valid_line = False

                if valid_line:
                    k = k + 1
                    test_line = line[:-19]
                    lines_splitted = test_line.split()

                    # Add skipped instructions.
                    new_pc = int(lines_splitted[0], 16)
                    if not first_line and old_pc != new_pc - 4 * (old_len - 1):
                        # print("old_pc: ", hex(old_pc), " new_pc: ", hex(new_pc), " old_len: ", old_len - 1)
                        range_val = int((new_pc - old_pc) / 4 - (old_len - 1))
                        # print("range_val: ", range_val)
                        for i in range(range_val):
                            instruction_lines.append("0" * 8)

                    # Add the instruction line.
                    for i in range(1, len(lines_splitted)):
                        if len(lines_splitted[i]) != 8:
                            lines_splitted[i] = lines_splitted[i] + "0" * (
                                8 - len(lines_splitted[i])
                            )
                        instruction_lines.append(lines_splitted[i])

                    first_line = False
                    old_pc = int(lines_splitted[0], 16)
                    old_pc_str = lines_splitted[0]
                    old_len = len(lines_splitted)

            for instr in instruction_lines:
                new_instruction_lines.append(
                    (instr[6:8] + instr[4:6] + instr[2:4] + instr[0:2])
                )
        # print(k)
    except FileNotFoundError:
        print(f"File not found: {input_path}")
        return

    # Write the accumulated instructions
    try:
        with open(output_path, "w") as file:
            # print(f"Writing to file: {output_path}")
            file.writelines(instr + "\n" for instr in new_instruction_lines)
    except IOError as e:
        print(f"Error writing to file {output_path}: {e}")
        return


def main(input_directory):
    # Ensure output directory exists
    output_directory = input_directory.replace("dis-asm", "instr")
    os.makedirs(output_directory, exist_ok=True)

    # Process each file in the input directory
    for filename in os.listdir(input_directory):
        if filename.endswith(".txt"):  # Check file extension if needed
            input_path = os.path.join(input_directory, filename)
            output_filename = filename
            output_path = os.path.join(output_directory, output_filename)
            process_file(input_path, output_path)
            # if filename == 'add-riscv64-nemu.txt':
            #     print("Skipping file: ", filename)
            #     input_path = os.path.join(input_directory, filename)
            #     output_filename = filename
            #     output_path = os.path.join(output_directory, output_filename)
            #     process_file(input_path, output_path)


if __name__ == "__main__":
    import argparse
    import sys
    from pathlib import Path

    _ROOT_DIR = Path(__file__).resolve().parents[1]
    if str(_ROOT_DIR) not in sys.path:
        sys.path.insert(0, str(_ROOT_DIR))

    from scripts.test_catalog import DISASM_ROOT, ROOT, TEST_BINARY_DIRS

    parser = argparse.ArgumentParser(
        description="Convert objdump disassembly dumps into $readmemh memory images."
    )
    parser.add_argument(
        "inputs",
        nargs="*",
        help="dis-asm directories to convert (default: every test group)",
    )
    args = parser.parse_args()

    input_directories = args.inputs or [
        str(ROOT / DISASM_ROOT / subdir) for subdir in TEST_BINARY_DIRS
    ]
    for directory in input_directories:
        main(directory)
