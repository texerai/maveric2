import os

# Make sure to add llvm-snippy install path to your PATH
LLVM_SNIPPY = "llvm-snippy"

layout_base_file = "layout_base.yaml"
layout_file = "layout.yaml"
reloc_object_file = "snippy-simple.elf"
linker_file = "snippy-simple.ld"
exec_elf_file = "final.elf"


def modify_linker(linker_file):
    with open(linker_file, "r") as file_in:
        lines = file_in.readlines()

    new_line = []

    for i, line in enumerate(lines):
        new_line.append(line)
        if i == 2:
            new_line.append("\nENTRY(_start)\n\n")
        if i == 4:
            new_line.append("  _start = .;\n")
    os.remove(linker_file)
    with open (linker_file, "w") as file_out:
        file_out.writelines(new_line)

def gen(test_name):
    copy_file = "snippy-" + test_name + ".elf"

    os.system(LLVM_SNIPPY + " " + layout_file)
    modify_linker(linker_file)
    os.system("riscv64-unknown-elf-ld -T" + linker_file + " -o " + exec_elf_file + " " + reloc_object_file)
    os.system("cp final.elf ../../test/tests/bin/snippy/" + copy_file)
    # os.system("riscv64-unknown-elf-objdump -D --full-content -M no-aliases,numeric " + exec_elf_file + " > out.txt")
    # os.system("dot -Tpng func.dot -o output.png")

def modify_hist(test_name):
    jump_tests = ["jal", "jalr"]
    load_store_tests = ["lb", "lbu", "ld", "lh", "lhu", "lw", "lwu", "sb", "sd", "sh", "sw"]
    mod_lines = []
    with open(layout_base_file, 'r') as file_in:
        for line in file_in:
            line_split = line.split()
            if len(line_split) == 3:
                instr = line_split[1]
                instr = instr[1:-1]
                if test_name == instr.lower():
                    if test_name in jump_tests:
                        temp = "    " + line_split[0] + " " + line_split[1] + " 5.0]\n"
                    else:
                        temp = "    " + line_split[0] + " " + line_split[1] + " 50.0]\n"
                    mod_lines.append(temp)
                elif test_name == "load-store":
                    if instr.lower() in load_store_tests:
                        temp = "    " + line_split[0] + " " + line_split[1] + " 10.0]\n"
                        mod_lines.append(temp)
                    else:
                        mod_lines.append(line)
                else:
                    mod_lines.append(line)
            else:
                mod_lines.append(line)

    with open(layout_file, 'w') as file_out:
        file_out.writelines(mod_lines)

def main():
    test_list = ["add", "addi", "addiw", "addw", "and", "andi", "auipc", "beq", "bge", "bgeu", "blt", "bltu", "bne",
                  "jal", "jalr", "lb", "lbu", "ld", "lh", "lhu", "lui", "lw", "lwu", "or", "ori", "sb", "sd", "sh",
                  "sll", "slli", "slliw", "sllw", "slt", "slti", "sltiu", "sltu", "sra", "srai", "sraiw", "sraw",
                  "srl", "srli", "srliw", "srlw", "sub", "subw", "sw", "xor", "xori", "load-store", "simple"]
    for test in test_list:
        modify_hist(test)
        gen(test)

    os.remove(exec_elf_file)
    os.remove(reloc_object_file)
    os.remove(linker_file)
    os.remove(layout_file)
    os.remove("func.dot")

main()
