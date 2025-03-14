import os
import subprocess

file_path_1 = 'test_1.txt'
file_path_2 = 'test_2.txt'
file_path_3 = 'test_3.txt'
exception_handler_path = './test/tests/docs/exception_handler_routine.txt'
mtvec_initialize_asm   = './test/tests/docs/mtvec_initialize.s'

def process_file(input_path, output_path):
    try:
        with open(input_path, 'r') as file:
            content = file.readlines()
        start_processing = False
        results = []

        for line in content:
            if "Disassembly of section .data:" in line:
                break
            if start_processing:
                # Extract specified character ranges and add to results
                parts = [
                   line[10:18],  # characters 6 to 13
                   line[19:27],  # characters 15 to 22
                   line[28:36],  # characters 24 to 31
                   line[37:45]   # characters 33 to 40
                ]
                results.extend(parts)

            if "Contents of section .data:" in line:
                start_processing = True

        # Write results to the output file
        with open(file_path_1, 'w') as file:
            for item in results:
                if (item == '        ') | (item == ''):
                    file.write('00000000\n')
                else: 
                    file.write(item + '\n')

        with open(file_path_1, 'r') as file_in:
            # Open the output file where the modified content will be written
            with open(file_path_2, 'w') as file_out:
                # Iterate over each line in the input file
                number_of_lines = 0
                for line in file_in:
                    # Strip newline characters from the end of the line
                    line = line.rstrip()
                    # Reorder the characters in each line as per the specified format
                    reordered_line = line[6:8] + line[4:6] + line[2:4] + line[0:2]
                    #reordered_line = line[0:2] + line[2:4] + line[4:6] + line[6:8]  
                    # Write the reordered line to the output file, adding a newline character
                    file_out.write(reordered_line + '\n')
                    number_of_lines += 1

                number_of_lines += 4
                number_of_lines *= 16

                #print(input_path + f": {number_of_lines} lines.")
                with open (exception_handler_path, 'r') as exception_h:
                   for line in exception_h:
                       file_out.write(line)
                with open (mtvec_initialize_asm, 'w') as asm_file:
                    asm_file.write(".globl _start\n")
                    asm_file.write("_start:\n")
                    asm_file.write(f"li t0, {number_of_lines}\n")
                    asm_file.write("csrw mtvec, t0\n")
                    asm_file.write("li t0, 0\n")
                try:
                    subprocess.run(["riscv64-unknown-elf-as", "-o", mtvec_initialize_asm.replace(".s", ".o"), mtvec_initialize_asm], check=True)
                    subprocess.run(["riscv64-unknown-elf-ld", "-o", mtvec_initialize_asm.removesuffix(".s"), mtvec_initialize_asm.replace(".s", ".o")], check=True)
                    with open(mtvec_initialize_asm.replace('.s', '.txt'), "w") as f:
                        subprocess.run(["riscv64-unknown-elf-objdump", "-D", mtvec_initialize_asm.removesuffix(".s")], stdout=f, check=True)
                except subprocess.CalledProcessError as e:
                    print(f"Failed to run script: {e}")

                with open (mtvec_initialize_asm.replace('.s', '.txt'), 'r') as mtvec_init:
                    content = mtvec_init.readlines()
                    start_processing = False
                    results = []
            
                    for line in content:
                        if "Disassembly of section .riscv.attributes:" in line:
                            break
                        if start_processing:
                            # Extract specified character ranges and add to results
                            parts = line[10:19]
                            
                            results.append(parts)
                        if "00000000000100b0 <_start>:" in line:
                            start_processing = True
            
                    # Write results to the output file
                    with open(file_path_3, 'w') as file:
                        k = 0
                        for item in results:
                            if ( item != ""): 
                                file.write(item + '\n')  
                                k += 1
                        while k < 4:
                            file.write("00000013\n")
                            k += 1


        with open(file_path_2, 'r') as file_in:
            with open(output_path, 'w') as file_out:
                # with open(file_path_3, 'r') as file:
                #     for line in file:
                #         file_out.write(line)
                for line in file_in:
                    file_out.write(line)


        if 'rv64ui-' in input_path:
            skip = False
            lines = []
            with open (output_path, 'r') as file_in:
                lines = file_in.readlines()
            
            replace_lines = []
            for line in lines:
                if "f1402573" in line:
                    skip = True
                if "00200193" in line:
                    skip = False
    
                if "c0001073" in line:
                    replace_lines.append("0000006f\n") #jump here forever.
                elif skip:
                    replace_lines.append("00000013\n") #nop
                elif ("0ff0000f" in line):
                    replace_lines.append("00000013\n")
                else:
                    replace_lines.append(line)
            with open(output_path, 'w') as file_out:
                file_out.writelines(replace_lines)
                

    except Exception as e:
        print(f"Error processing file {input_path}: {e}")

def main(input_directory):
    # Ensure output directory exists
    output_directory = input_directory.replace('dis-asm', 'instr')
    os.makedirs(output_directory, exist_ok=True)

    # Process each file in the input directory
    for filename in os.listdir(input_directory):
        if filename.endswith('.txt'):  # Check file extension if needed
            input_path = os.path.join(input_directory, filename)
            output_filename = filename
            output_path = os.path.join(output_directory, output_filename)
            process_file(input_path, output_path)

if __name__ == '__main__':
    input_directory = ['test/tests/dis-asm/am-kernels', 'test/tests/dis-asm/riscv-arch-test', 'test/tests/dis-asm/riscv-tests']
    for directory in input_directory:
        main(directory)

os.remove(file_path_1)
os.remove(file_path_2)
os.remove(file_path_3)
os.remove(mtvec_initialize_asm.replace(".s", ".o"))
os.remove(mtvec_initialize_asm.replace(".s", ".txt"))
os.remove(mtvec_initialize_asm.removesuffix(".s"))
os.remove(mtvec_initialize_asm)

