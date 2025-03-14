import os
import argparse

SCRIPT_1 = "./scripts/bin-to-hex.py"
SCRIPT_2 = "./scripts/hex-to-mem.py"

AM_TEST_DIR = "./test/tests/list/list-am.txt"
RV_ARCH_TEST_DIR = "./test/tests/list/list-rv-arch-test.txt"
RV_TESTS_DIR = "./test/tests/list/list-rv-tests.txt"
TEST_DIR = "./test/tests/list/list.txt"

MEMORY_FILE = "./rtl/mem_simulated.sv"
TB_FILE     = "./test/tb/tb_test_env.cpp"
RESULT_FILE = "result.txt"
TEST_ENV_FILE = "./rtl/test_env.sv"
DCACHE_FILE   = "./rtl/dcache.sv"

TEST_AM = []
TEST_RV_ARCH= []
TEST_RV = []
TEST = {}



with open(AM_TEST_DIR, 'r') as file_in:
    for line in file_in:
                TEST_AM.append(line.strip())

with open(RV_ARCH_TEST_DIR, 'r') as file_in:
    for line in file_in:
                TEST_RV_ARCH.append(line.strip())

with open(RV_TESTS_DIR, 'r') as file_in:
    for line in file_in:
                TEST_RV.append(line.strip())

with open(TEST_DIR, 'r') as file_in:
    for line in file_in:
            # Strip newlines and whitespace
            line = line.strip()
            # Check if the line contains a colon
            if ':' in line:
                # Split the line at the first colon
                parts = line.split(':', 1)
                key = parts[0].strip()
                directory = parts[1].strip()
                TEST[key] = directory
            else:
                print("No colon found in the line.")



COMPILE_C_COMMAND = "gcc -c -o ./check.o ./test/tb/check.c"
VERILATE_COMMAND = "verilator --assert -I./rtl --Wall --cc ./rtl/test_env.sv --exe ./test/tb/tb_test_env.cpp ./test/tb/check.c"
VERILATE_COMMAND_TRACE = "verilator --assert -I./rtl --Wall --trace --cc ./rtl/test_env.sv --exe ./test/tb/tb_test_env.cpp ./test/tb/check.c"
MAKE_COMMAND = "make -C obj_dir -f Vtest_env.mk"
SAVE_COMMAND = "./obj_dir/Vtest_env | tee -a res.txt"
CLEAN_COMMAND = "rm -r ./obj_dir check.o"
CLEAN_RESULT = "rm result.txt"



def clean_before():
    os.system(CLEAN_RESULT)
    with open (RESULT_FILE, 'w') as file_out:
        file_out.write("")


def compile_single(test, gen_wave=False):
    modify_testbench(not gen_wave)
    modify_memory(TEST[test])
    os.system(COMPILE_C_COMMAND)
    if gen_wave:
        os.system(VERILATE_COMMAND_TRACE)
    else:
        os.system(VERILATE_COMMAND)
    os.system(MAKE_COMMAND)
    save_result(test)
    clean_after()


def compile_all():
    for key in TEST.keys():
        compile_single(key)


def compile_group(group):
    if group == 'am':
        for test in TEST_AM:
             compile_single(test)
    elif group == 'rv-arch-test':
        for test in TEST_RV_ARCH:
             compile_single(test)
    elif group == 'rv-tests':
        for test in TEST_RV:
             compile_single(test)
    else:
        print("Unrecognized test group")


def compile_varying_cache():
     block_size = 128
     while block_size <= 1024:
          set_count = 2
          while set_count <= 16:
               modify_cache_size(block_size, set_count)
               os.system(SAVE_COMMAND)
               with open (RESULT_FILE, 'r') as file_in:
                    lines = file_in.readlines()
           
               old_lines = []
               for line in lines:
                   old_lines.append(line)
           
               with open(RESULT_FILE, 'w') as file_out:
                    file_out.writelines(old_lines)
                    message = "\n\nCACHE_LINE_WIDTH: " +  str(block_size) + " bits, SET_COUNT: " + str(set_count) + "\n"
                    file_out.write(message)   

               # compile_single("am-add", False)
               compile_all()
               set_count *= 2
          block_size *= 2


def modify_cache_size(block_size, set_count):
    with open ( TEST_ENV_FILE, 'r' ) as file_in:
        lines = file_in.readlines()

    new_lines = []
    parameter_found = False
    for line in lines:
        if 'parameter' in line:
            parameter_found =True
        
        if parameter_found:
            if 'BLOCK_WIDTH' in line:
                 new_line = line[:31] + str(block_size)
                 new_lines.append(new_line)
                 new_lines.append("\n")
                 parameter_found = False
            else:
                 new_lines.append(line)
        else:
             new_lines.append(line)

    with open (TEST_ENV_FILE, 'w') as file_out:
          file_out.writelines(new_lines)


    with open ( DCACHE_FILE, 'r' ) as file_in:
        lines = file_in.readlines()

    new_lines = []
    parameter_found = False
    for line in lines:
        if 'parameter' in line:
            parameter_found =True
        
        if parameter_found:
            if 'SET_COUNT' in line:
                 new_line = line[:27] + str(set_count)
                 new_lines.append(new_line)
                 new_lines.append("\n")
                 parameter_found = False
            else:
                 new_lines.append(line)
        else:
             new_lines.append(line)

    with open (DCACHE_FILE, 'w') as file_out:
          file_out.writelines(new_lines)


def save_result(test):
    os.system(SAVE_COMMAND)
    with open (RESULT_FILE, 'r') as file_in:
         lines = file_in.readlines()

    old_lines = []
    for line in lines:
        old_lines.append(line)

    with open(RESULT_FILE, 'w') as file_out:
         file_out.writelines(old_lines)
         file_out.write(f'{test + ": ":<29}')
         with open('res.txt', 'r') as file_in:
            i = 0
            lines = file_in.readlines()
            for line in lines:
                if i < 1:
                    file_out.write(line)
                i += 1
            if i == 0:
                 file_out.write("\n")


    os.system("rm res.txt")


def clean_after():
    os.system(CLEAN_COMMAND)


def print_all_tests():
    for key in TEST.keys():
         print(key)


def modify_memory(mem_directory):
    with open (MEMORY_FILE, 'r') as file_in:
          lines = file_in.readlines()
    new_lines = []
    for line in lines:
         if '`define' in line:
              new_line = '`define PATH_TO_MEM ' + "\"" +mem_directory + "\""
              new_lines.append(new_line)
              new_lines.append("\n")
         else:
              new_lines.append(line)
    with open (MEMORY_FILE, 'w') as file_out:
          file_out.writelines(new_lines)


def modify_testbench(comment):
    with open (TB_FILE, 'r') as file_in:
        lines = file_in.readlines()
    new_lines = []
    for line in lines:
        if 'trace' in line:
            if '//' in line:
                if comment:
                    new_lines.append(line)
                else:
                    new_line = "  " + line[2:]
                    new_lines.append(new_line)
            else:
                if comment: 
                    new_line = '//' + line[2:]
                    new_lines.append(new_line)
                else:
                    new_lines.append(line)
        else:
            new_lines.append(line)

    with open (TB_FILE, 'w') as file_out:
          file_out.writelines(new_lines)


def initial_note():
    with open(RESULT_FILE, 'w') as file_out:
        message_1 = "NOTE: ILLEGAL INSTRUCTION REFERS TO INSTRUCTIONS THAT WERE NOT (YET) IMPLEMENTED IN MAVERIC CORE 2.0 PROCESSOR. THE SYSTEM REGOGNIZES THOSE INSTRUCTIONS AS ILLEGAL.\n"
        message_2 = "THE LIST INCLUDES, BUT IS NOT LIMITED TO, MUL, DIV, AND FENCE INSTRUCTIONS.\n"
        file_out.write(message_1)
        file_out.write(message_2)        


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('-a', '--compile-all', action='store_true', default=False)
    parser.add_argument('-l', '--list-tests', action='store_true', default=False)
    parser.add_argument('-s', '--compile-single', type=str)
    parser.add_argument('-g', '--compile-group', type=str)
    parser.add_argument('-c', '--clean', action='store_true', default=False)
    parser.add_argument('-t', '--trace', action='store_true', default=False)
    parser.add_argument('-v', '--compile-varying-cache', action='store_true', default=False)

    return parser.parse_args()


def prepare_tests():
    os.system("python3 " + SCRIPT_1)
    os.system("python3 " + SCRIPT_2)

def main():
    prepare_tests()
    clean_before()
    args = parse_arguments()

    initial_note()
  
    if args.compile_single:
        compile_single(args.compile_single, args.trace)
    elif args.list_tests:
         print_all_tests()
    elif args.compile_all:
         compile_all()
    elif args.compile_group:
         compile_group(args.compile_group)
    elif args.compile_varying_cache:
         compile_varying_cache()
    elif args.clean:
         clean_after()
    else:
         print("Invalid arguments")

    os.system("rm -r ./test/tests/dis-asm")
    os.system("rm -r ./test/tests/instr") 

main()
