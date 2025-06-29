import os
import argparse
import sys


#-------------------------
# Constants.
#-------------------------
SCRIPT_1 = "./scripts/elf2disasm.py"
SCRIPT_2 = "./scripts/disasm2mem.py"

AM_TEST_DIR = "./test/tests/list/list-am.txt"
RV_ARCH_TEST_DIR = "./test/tests/list/list-rv-arch-test.txt"
RV_TESTS_DIR = "./test/tests/list/list-rv-tests.txt"
SNIPPY_TEST_DIR = "./test/tests/list/list-snippy.txt"
TEST_DIR = "./test/tests/list/list.txt"

MEMORY_FILE = "./rtl/mem_simulated.sv"
TB_FILE     = "./test/tb/tb_test_env.cpp"
RESULT_FILE = "./results/result.txt"
PERF_RESULT_FILE = "./results/perf_result.txt"
TEST_ENV_FILE = "./rtl/test_env.sv"
DCACHE_FILE   = "./rtl/dcache.sv"

TEST_AM = []
TEST_RV_ARCH= []
TEST_RV = []
TEST_SNIPPY = []
TEST = {}



#-------------------------
# Prepare tests.
#-------------------------
with open(AM_TEST_DIR, 'r') as file_in:
    for line in file_in:
        TEST_AM.append(line.strip())

with open(RV_ARCH_TEST_DIR, 'r') as file_in:
    for line in file_in:
        TEST_RV_ARCH.append(line.strip())

with open(RV_TESTS_DIR, 'r') as file_in:
    for line in file_in:
        TEST_RV.append(line.strip())
with open(SNIPPY_TEST_DIR, 'r') as file_in:
    for line in file_in:
        TEST_SNIPPY.append(line.strip())

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



#-------------------------
# Commands.
#-------------------------
COMPILE_C_COMMAND = "gcc -c -o ./check.o ./test/tb/check.c"
COMPILE_LOG_COMMAND = "gcc -c -o ./log_trace.o ./test/tb/log_trace.c"
VERILATE_COMMAND_START = "verilator --assert -I./rtl --Wall --cc ./rtl/test_env.sv "
VERILATE_COMMAND_END = " --exe ./test/tb/tb_test_env.cpp ./test/tb/check.c ./test/tb/log_trace.c"

MAKE_COMMAND = "make -C obj_dir -f Vtest_env.mk"
# SAVE_COMMAND = '''./obj_dir/Vtest_env | awk '
#     /PC/ {
#         print >> "res.txt"; next;
#     }
#     {
#         print; print >> "res.txt";
#     }' '''
SAVE_COMMAND = "./obj_dir/Vtest_env > res.txt"
CLEAN_SINGLE = "rm -r ./obj_dir check.o log_trace.o res.txt temp.txt"
CLEAN_TESTS  = "rm -r ./test/tests/dis-asm ./test/tests/instr"
CLEAN_RESULT = "rm ./results/result.txt ./results/perf_result.txt"

COV_MERGE = "verilator_coverage --write merged.dat cov/*"
COV_ANNOTATE = "verilator_coverage --annotate coverage_annotated/ merged.dat"


#-------------------------
# Help messages.
#-------------------------
HELP_MSG_SCRIPT_DESCRIPTION = "Utility script to automate test runs on the MAVERIC CORE 2.0 processor."
HELP_MSG_ALL_DESCRIPTION = "Run all tests."
HELP_MSG_LIST_DESCRIPTION = "Print the list of all available tests."
HELP_MSG_SINGLE_DESCRIPTION = "Run a single test. Format: -s <test_name>. Use -l to list available tests."
HELP_MSG_GROUP_DESCRIPTION = "Run a group of tests. Format: -g <test_group>. Available groups: am, rv-tests, rv-arch-test."
HELP_MSG_CLEAN_DESCRIPTION = "Clean the work directory by deleting all files generated during the test run."
HELP_MSG_TRACE_DESCRIPTION = "Generate a waveform. Works only with the -s flag."
HELP_MSG_VARYING_DESCRIPTION = "Run all tests across multiple cache sizes, ranging from 128 B to 8 KB."
HELP_MSG_COVERAGE_ALL_DESCRIPTION = "Generate coverage reports for both line and toggle coverage."
HELP_MSG_COVERAGE_LINE_DESCRIPTION = "Generate coverage report for line coverage."
HELP_MSG_COVERAGE_TOGGLE_DESCRIPTION = "Generate coverage report for toggle coverage."
HELP_MSG_PREP_FOR_COMMIT_DESCRIPTION = "Removes autogenerated files and restores autoupdated files to prepare for git commit."


#-------------------------
# Clean commands.
#-------------------------

# Clean before start.
def clean_before():
    os.system(CLEAN_RESULT)
    with open (RESULT_FILE, 'w') as file_out:
        file_out.write("")
    with open (PERF_RESULT_FILE, 'w') as file_out:
        file_out.write("")


# Clean after the run.
def clean_single():
    os.system(CLEAN_SINGLE)

# Clean after the run.
def clean():
    os.system(CLEAN_TESTS)


#-------------------------
# Compile commands
#-------------------------

# Compile single test.
def compile_single(test, block_size=512, set_count=4, gen_wave=False, gen_coverage=False):
    modify_testbench(test, not gen_wave, not gen_coverage)
    modify_cache_size(block_size, set_count)
    modify_memory(TEST[test])
    os.system(COMPILE_C_COMMAND)
    os.system(COMPILE_LOG_COMMAND)
    command = VERILATE_COMMAND_START
    if gen_coverage:
        command += " --coverage"
    if gen_wave:
        command += " --trace"

    command += VERILATE_COMMAND_END 
    os.system(command)
    os.system(MAKE_COMMAND)
    os.system("touch" + " ./spike_log_trace/" + test + "-log-trace.log")
    test_elf = TEST[test][:13] + "bin" + TEST[test][18:-4] + ".elf"
    spike_command = "python3 ./scripts/tracecomp.py " + test + " " + test_elf
    os.system(spike_command)
    save_result(test, block_size, set_count, gen_coverage)
    clean_single()


# Compile group of tests.
def compile_group(group, gen_wave=False, gen_coverage=False):
    if group == 'am':
        for test in TEST_AM:
            compile_single(test, gen_wave=gen_wave, gen_coverage = gen_coverage)
    elif group == 'rv-arch-test':
        for test in TEST_RV_ARCH:
            compile_single(test, gen_wave=gen_wave, gen_coverage = gen_coverage)
    elif group == 'rv-tests':
        for test in TEST_RV:
            compile_single(test, gen_wave=gen_wave, gen_coverage = gen_coverage)
    elif group == 'snippy':
        for test in TEST_SNIPPY:
            compile_single(test, gen_wave=gen_wave, gen_coverage = gen_coverage)
    else:
        print("Unrecognized test group")


# Compile all tests.
def compile_all(block_size=512, set_count=4, gen_wave=False, gen_coverage=False):
    for key in TEST.keys():
        compile_single(key, block_size=block_size, set_count=set_count, gen_wave=gen_wave, gen_coverage=gen_coverage)


# Compile all tests with varying cache sizes.
def compile_varying_cache(gen_wave=False, gen_coverage=False):
    block_size = 128
    while block_size <= 1024:
        set_count = 2
        while set_count <= 16:
            modify_cache_size(block_size, set_count)
            with open (RESULT_FILE, 'r') as file_in:
                lines = file_in.readlines()
            with open (PERF_RESULT_FILE, 'r') as file_in:
                perf_lines = file_in.readlines()   
           
            old_lines = []
            for line in lines:
                old_lines.append(line)
            
            old_perf_lines = []
            for line in perf_lines:
                old_perf_lines.append(line)
           
            with open(RESULT_FILE, 'w') as file_out:
                file_out.writelines(old_lines)
                message = "\n\nCACHE_LINE_WIDTH: " +  str(block_size) + " bits, SET_COUNT: " + str(set_count) + "\n"
                file_out.write(message)

            with open(PERF_RESULT_FILE, 'w') as file_out:
                file_out.writelines(old_perf_lines)
                message = "\n\nCACHE_LINE_WIDTH: " +  str(block_size) + " bits, SET_COUNT: " + str(set_count) + "\n"
                file_out.write(message)

            # compile_single("am-add", False)
            compile_all(block_size, set_count, gen_wave, gen_coverage)
            set_count *= 2
        block_size *= 2


# Print command.
def print_all_tests():
    for key in TEST.keys():
        print(key)



#-------------------------
# Helper functions.
#-------------------------

# Modify the cache size in cache HDL file.
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


# Save test results.
def save_result(test, block_size, set_count, gen_coverage):
    os.system(SAVE_COMMAND)

    with open ('res.txt', 'r') as file_in:
        lines_res = file_in.readlines()

    lines_log_trace = lines_res[:-3]
    LOG_FILE = "./log_trace/" + test + "-log-trace.log"

    os.system("rm " + LOG_FILE)
    with open (LOG_FILE, 'w') as file_out:
        file_out.writelines(lines_log_trace)

    unit_test_res_line = lines_res[-3]
    unit_test_res_line_split = unit_test_res_line.split()
    test_status = " ".join(unit_test_res_line_split[:-13])

    with open (RESULT_FILE, 'r') as file_in:
        lines = file_in.readlines()

    with open (PERF_RESULT_FILE, 'r') as file_in:
        perf_lines = file_in.readlines()

    old_lines = []
    for line in lines:
        old_lines.append(line)

    old_perf_lines = []
    for line in perf_lines:
        old_perf_lines.append(line)

    log_trace_file_name = test + "-log-trace.log"
    diff_command = f"diff ./log_trace/{log_trace_file_name} ./spike_log_trace/{log_trace_file_name} | head -n 5 > temp.txt"
    os.system(diff_command)

    with open(RESULT_FILE, 'w') as file_out:
        file_out.writelines(old_lines)
        file_out.write(f'{test + ": ":<29}')

        if "snippy" in test:
            result_line = "Self Check: Not applicable"
            print("\n" + result_line)
        else:
            result_line = "Self Check: " + test_status
            print("\n" + result_line)

        if "pass" not in result_line.lower() and "not applicable" not in result_line.lower():
            result_line += "FAIL\n"
            print(f"\nSelf Check: FAIL | Reason: {test_status}")
            os.system("rm res.txt temp.txt")
            print(f"\nError: Test {test} failed")
            print("Terminating test suite execution.")
            sys.exit(1)
        if os.path.exists("temp.txt") and os.stat("temp.txt").st_size == 0:
            result_line += "    Tracecomp: PASS\n"
            print("Tracecomp: PASS")
        elif os.path.exists(f"./spike_log_trace/{log_trace_file_name}") and os.stat(f"./spike_log_trace/{log_trace_file_name}").st_size == 0:
            result_line += "    Tracecomp: Not Applicable\n"
        else:
            result_line += "    Tracecomp: FAIL\n"
            print("Tracecomp: FAIL")
            os.system("rm res.txt temp.txt")
            print(f"\nError: Test {test} failed")
            print("Terminating test suite execution.")
            sys.exit(1)

        file_out.write(result_line)

    with open(PERF_RESULT_FILE, 'w') as file_out:
        file_out.writelines(old_perf_lines)
        file_out.write(f'{test + ": ":<29}')
        file_out.write(unit_test_res_line[7:])


    if gen_coverage:
        os.system(f"mv coverage.dat cov/coverage_{test}_{block_size}_{set_count}.dat")


# Modify memory file used for test.
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


# Modify testbench file.
def modify_testbench(test_name, comment_trace, comment_coverage):
    with open (TB_FILE, 'r') as file_in:
        lines = file_in.readlines()
    new_lines = []
    for line in lines:
        if 'trace' in line:
            if '//' in line:
                if comment_trace:
                    new_lines.append(line)
                else:
                    if "waveform.vcd" in line:
                        new_line = "    sim_trace->open(\"./waveform/" + test_name + "_waveform.vcd\");\n"
                    else:
                        new_line = "  " + line[2:]
                    new_lines.append(new_line)
            else:
                if comment_trace:
                    new_line = '//' + line[2:]
                    new_lines.append(new_line)
                else:
                    if "waveform.vcd" in line:
                        new_line = "    sim_trace->open(\"./waveform/" + test_name + "_waveform.vcd\");\n"
                        new_lines.append(new_line)
                    else:
                        new_lines.append(line)
        elif 'VerilatedCov' in line:
            if '//' in line:
                if comment_coverage:
                    new_lines.append(line)
                else:
                    new_line = "  " + line[2:]
                    new_lines.append(new_line)
            else:
                if comment_coverage:
                    new_line = '//' + line[2:]
                    new_lines.append(new_line)
                else:
                    new_lines.append(line)
        else:
            new_lines.append(line)

    with open (TB_FILE, 'w') as file_out:
        file_out.writelines(new_lines)



def parse_arguments():
    parser = argparse.ArgumentParser(description=HELP_MSG_SCRIPT_DESCRIPTION)
    parser.add_argument('-a', '--compile-all',
                        action='store_true',
                        help=HELP_MSG_ALL_DESCRIPTION)
    parser.add_argument('-l', '--list-tests',
                        action='store_true',
                        help=HELP_MSG_LIST_DESCRIPTION)

    parser.add_argument('-s', '--compile-single',
                        type=str,
                        metavar='test_name',
                        help=HELP_MSG_SINGLE_DESCRIPTION)

    parser.add_argument('-g', '--compile-group',
                        type=str,
                        metavar='test_group',
                        help=HELP_MSG_GROUP_DESCRIPTION)

    parser.add_argument('-c', '--clean',
                        action='store_true',
                        help=HELP_MSG_CLEAN_DESCRIPTION)

    parser.add_argument('-t', '--trace',
                        action='store_true',
                        help=HELP_MSG_TRACE_DESCRIPTION)

    parser.add_argument('-v', '--compile-varying-cache',
                        action='store_true',
                        help=HELP_MSG_VARYING_DESCRIPTION)

    parser.add_argument('-ca', '--coverage-all',
                        action='store_true',
                        help=HELP_MSG_COVERAGE_ALL_DESCRIPTION)

    parser.add_argument('-cl', '--coverage-line',
                        action='store_true',
                        help=HELP_MSG_COVERAGE_LINE_DESCRIPTION)

    parser.add_argument('-ct', '--coverage-toggle',
                        action='store_true',
                        help=HELP_MSG_COVERAGE_TOGGLE_DESCRIPTION)
    parser.add_argument('-p', '--prepare-for-commit',
                        action='store_true',
                        help=HELP_MSG_PREP_FOR_COMMIT_DESCRIPTION)

    return parser.parse_args()


    return parser.parse_args()


def prepare_tests():
    os.system("python3 " + SCRIPT_1)
    os.system("python3 " + SCRIPT_2)
    os.system("mkdir log_trace")
    os.system("mkdir spike_log_trace")

def prep():
    prepare_tests()
    clean_before()

def prepare_for_commit():
    os.system("git restore ./results/result.txt")
    os.system("git restore ./results/perf_result.txt")
    os.system("git restore ./rtl/mem_simulated.sv")
    os.system("rm -r log_trace")
    os.system("rm -r spike_log_trace")
    os.system("rm -r waveform")
    clean_single()
    clean()

def main():
    args = parse_arguments()

    if args.coverage_all:
        os.system ("mkdir cov")
    if args.trace:
        os.system("mkdir waveform")
  
    if args.compile_single:
        prep()
        compile_single(args.compile_single, 128, 4, args.trace, args.coverage_all)
        clean()
    elif args.list_tests:
        print_all_tests()
    elif args.compile_all:
        prep()
        compile_all(block_size=128, set_count=4, gen_wave=args.trace, gen_coverage=args.coverage_all)
        clean()
    elif args.compile_group:
        prep()
        compile_group(args.compile_group, args.trace, args.coverage_all)
        clean()
    elif args.compile_varying_cache:
        prep()
        compile_varying_cache(args.trace, args.coverage_all)
        clean()
    elif args.prepare_for_commit:
        prepare_for_commit()
    elif args.clean:
        clean_single()
        clean()
    else:
        print("Invalid arguments")

    if args.coverage_all:
        os.system(COV_MERGE)
        os.system(COV_ANNOTATE + " | tee -a ./coverage_results.txt")
        os.system("rm -r ./cov")

main()
