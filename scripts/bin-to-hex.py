import os
import subprocess

# Define the command template
command_template_1 = "riscv64-unknown-elf-objdump -D --start-address=0x80000000 -b binary --adjust-vma=0x80000000 --full-content -m riscv:rv64 -M no-aliases,numeric \"./test/tests/bin/{input_file}\" > \"./test/tests/dis-asm/{output_file}\""
command_template_2 = "riscv64-unknown-elf-objdump -D --start-address=0x80001000 -b binary --adjust-vma=0x80000000 --full-content -m riscv:rv64 -M no-aliases,numeric \"./test/tests/bin/{input_file}\" > \"./test/tests/dis-asm/{output_file}\""

os.system("mkdir ./test/tests/dis-asm/")
os.system("mkdir ./test/tests/dis-asm/am-kernels/")
os.system("mkdir ./test/tests/dis-asm/riscv-arch-test/")
os.system("mkdir ./test/tests/dis-asm/riscv-tests/")


def generate_file_1_path(input_file):
    if input_file.endswith(".elf"):
        return input_file[:-4] + ".txt"
    elif input_file.endswith(".bin"):
        return input_file[:-4] + ".txt"
    else:
        return input_file + ".txt"

# Read the list of input files from "str.txt"
with open("./test/tests/docs/str.txt", "r") as file:
    input_files = file.read().strip().split()

# Process each file
for input_file in input_files:
    file_1 = generate_file_1_path(input_file)
    # Format the command with the current input and output file paths
    if "bin" in input_file:
        command = command_template_1.format(input_file=input_file, output_file=file_1)
    else: 
        command = command_template_2.format(input_file=input_file, output_file=file_1)
    # Run the command
    subprocess.run(command, shell=True)
