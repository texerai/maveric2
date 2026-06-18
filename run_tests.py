#!/usr/bin/env python3

from __future__ import annotations

import argparse
import difflib
import os
import re
import selectors
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from itertools import islice
from pathlib import Path
from typing import Callable, Iterable, Mapping, Sequence

from scripts.test_catalog import (
    GROUP_NAMES,
    custom_trap_continuation_tests,
    discover_groups,
    discover_tests,
)


ROOT = Path(__file__).resolve().parent

SCRIPT_ELF2DISASM = ROOT / "scripts/elf2disasm.py"
SCRIPT_DISASM2MEM = ROOT / "scripts/disasm2mem.py"
SCRIPT_TRACECOMP = ROOT / "scripts/tracecomp.py"

MEMORY_FILE = ROOT / "rtl/mem_simulated.sv"
TB_FILE = ROOT / "test/tb/tb_test_env.cpp"
RESULT_FILE = ROOT / "results/result.txt"
TEST_ENV_FILE = ROOT / "rtl/test_env.sv"
DCACHE_FILE = ROOT / "rtl/dcache.sv"

DROMAJO_DIR = ROOT / "tools/dromajo"
DROMAJO_INCLUDE = DROMAJO_DIR / "include"
DROMAJO_LIB = DROMAJO_DIR / "build" / "libdromajo_cosim.a"

OBJ_DIR = ROOT / "obj_dir"
SIM_BINARY = OBJ_DIR / "Vtest_env"
RES_FILE = ROOT / "res.txt"
TEMP_DIFF_FILE = ROOT / "temp.txt"
SPIKE_TEMP_LOG = ROOT / "trace.log"
LOG_TRACE_DIR = ROOT / "log_trace"
SPIKE_LOG_TRACE_DIR = ROOT / "spike_log_trace"
PMEM_WRITE_DIR = ROOT / "pmem_write"
WAVEFORM_DIR = ROOT / "waveform"
COV_DIR = ROOT / "cov"
COVERAGE_FILE = ROOT / "coverage.dat"
MERGED_COVERAGE_FILE = ROOT / "merged.dat"
COVERAGE_RESULTS_FILE = ROOT / "coverage_results.txt"
COVERAGE_ANNOTATED_DIR = ROOT / "coverage_annotated"

GENERATED_TEST_DIRS = (
    ROOT / "test/tests/dis-asm",
    ROOT / "test/tests/instr",
)

MANAGED_FILES = (
    MEMORY_FILE,
    TB_FILE,
    TEST_ENV_FILE,
    DCACHE_FILE,
)

CACHE_SWEEP_BLOCK_WIDTHS = (128, 256, 512, 1024)
CACHE_SWEEP_SET_COUNTS = (2, 4, 8, 16)
CACHE_SWEEP_ASSOCIATIVITIES = (2, 4, 8)

COMMAND_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_COMMAND_TIMEOUT_SEC", "600"))
SIMULATION_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_SIM_TIMEOUT_SEC", "180"))
SIMULATION_IDLE_TIMEOUT_SECONDS = int(
    os.environ.get("MAVERIC_SIM_IDLE_TIMEOUT_SEC", "20")
)
TRACE_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_TRACE_TIMEOUT_SEC", "120"))
OUTPUT_TAIL_BYTES = 8192
VERILATOR_WARNING_RE = re.compile(r"^%Warning(?:-[A-Za-z0-9_]+)?:", re.MULTILINE)
STATUS_COLOR_RE = re.compile(r"\b(PASS|FAIL)\b")
ANSI_GREEN = "\033[32m"
ANSI_RED = "\033[31m"
ANSI_RESET = "\033[0m"
CSR_OPCODE = 0x73
MSTATUS_CSR_ADDR = 0x300
TIME_CSR_ADDR = 0xC01
TRACE_INSTR_RE = re.compile(r"\bINSTR: (0x[0-9a-fA-F]{8})")
TRACE_REG_VALUE_RE = re.compile(r"(REG x\d+: )0x([0-9a-fA-F]{16})")
TRAP_CONTINUATION_PMEM_EXPECTED = {
    "custom-ebreak-mret": "EBREAK TEST: PASS\nMRET TEST: PASS\n",
    "custom-csr-test-2": "CSR TEST: PASS\n",
    "custom-clint-msi-test": "SW INTERRUPT TEST: PASS\n",
    "custom-clint-mti-test": "TIMER INTERRUPT TEST: PASS\n",
}
TRAP_CONTINUATION_TESTS = custom_trap_continuation_tests()


HELP_MSG_SCRIPT_DESCRIPTION = (
    "Utility script to automate test runs on the MAVERIC CORE 2.0 processor."
)
HELP_MSG_ALL_DESCRIPTION = "Run all tests."
HELP_MSG_LIST_DESCRIPTION = "Print the list of all available tests."
HELP_MSG_SINGLE_DESCRIPTION = (
    "Run a single test. Format: -s <test_name>. Use -l to list available tests."
)
HELP_MSG_GROUP_DESCRIPTION = (
    f"Run a group of tests. Available groups: {', '.join(GROUP_NAMES)}."
)
HELP_MSG_LINT_DESCRIPTION = "Run Verilator lint-only check for an RTL module."
HELP_MSG_CLEAN_DESCRIPTION = (
    "Delete generated build, trace, coverage, and prepared test artifacts."
)
HELP_MSG_TRACE_DESCRIPTION = "Generate a waveform dump for the executed tests."
HELP_MSG_VARYING_DESCRIPTION = "Sweep BLOCK_WIDTH from 128 b to 1024 b, SET_COUNT from 2 to 16, and associativity from 2-way to 8-way. Must be used with -s, -g, or -a."
HELP_MSG_COVERAGE_ALL_DESCRIPTION = "Generate both line and toggle coverage."
HELP_MSG_COVERAGE_LINE_DESCRIPTION = "Generate line coverage only."
HELP_MSG_COVERAGE_TOGGLE_DESCRIPTION = "Generate toggle coverage only."
HELP_MSG_PREP_FOR_COMMIT_DESCRIPTION = (
    "Remove generated artifacts and restore autoupdated tracked files."
)
HELP_MSG_COSIM_ONLY_DESCRIPTION = "Run only the Dromajo co-simulation; skip RTL self-check validation, Spike trace generation, and tracecomp."
HELP_MSG_NO_COSIM_DESCRIPTION = (
    "Disable Dromajo co-simulation; keep RTL self-checks and Spike trace comparison."
)
HELP_MSG_NO_TRACECOMP_DESCRIPTION = (
    "Disable RTL trace logging, Spike trace generation, and trace comparison."
)
HELP_MSG_WARNINGS_DESCRIPTION = (
    "Show Verilator warnings and print the Verilator warning count."
)


class RunTestsError(Exception):
    """Base class for driver failures."""


class ConfigurationError(RunTestsError):
    """Raised when the repository or command-line inputs are inconsistent."""


class CommandError(RunTestsError):
    """Raised when an external command fails, times out, or stalls."""

    def __init__(
        self,
        description: str,
        command: Sequence[str],
        reason: str,
        stdout_tail: str = "",
        stderr_tail: str = "",
    ) -> None:
        parts = [
            f"{description} failed: {reason}",
            f"Command: {format_command(command)}",
        ]
        if stdout_tail:
            parts.append(f"stdout tail:\n{stdout_tail}")
        if stderr_tail:
            parts.append(f"stderr tail:\n{stderr_tail}")
        super().__init__("\n".join(parts))


class SimulationOutputError(RunTestsError):
    """Raised when the simulator output is malformed or incomplete."""


class TestFailure(RunTestsError):
    """Raised when a test completes but does not pass validation."""


@dataclass(frozen=True)
class ParsedSimulationOutput:
    status_text: str | None
    status_missing: bool = False


@dataclass(frozen=True)
class TestOutcome:
    self_check: str
    tracecomp: str


def format_command(command: Sequence[str]) -> str:
    return shlex.join(str(part) for part in command)


def format_repo_path(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def append_tail(buffer: bytearray, chunk: bytes) -> None:
    buffer.extend(chunk)
    overflow = len(buffer) - OUTPUT_TAIL_BYTES
    if overflow > 0:
        del buffer[:overflow]


def decode_tail(buffer: bytearray) -> str:
    return buffer.decode("utf-8", errors="replace").strip()


def tail_text(text: str, limit: int = OUTPUT_TAIL_BYTES) -> str:
    stripped = text.strip()
    if len(stripped) <= limit:
        return stripped
    return "...\n" + stripped[-limit:]


def count_verilator_warnings(text: str) -> int:
    return len(VERILATOR_WARNING_RE.findall(text))


def colorize_status_text(text: str) -> str:
    def colorize(match: re.Match[str]) -> str:
        status = match.group(1)
        color = ANSI_GREEN if status == "PASS" else ANSI_RED
        return f"{color}{status}{ANSI_RESET}"

    return STATUS_COLOR_RE.sub(colorize, text)


class CommandRunner:
    def __init__(self, cwd: Path) -> None:
        self.cwd = cwd

    def run(
        self,
        command: Sequence[str],
        *,
        description: str,
        timeout: int = COMMAND_TIMEOUT_SECONDS,
        echo_output: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        normalized = [str(part) for part in command]
        try:
            result = subprocess.run(
                normalized,
                cwd=self.cwd,
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except FileNotFoundError as exc:
            raise CommandError(
                description, normalized, "command was not found"
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise CommandError(
                description,
                normalized,
                f"timed out after {timeout} seconds",
                stdout_tail=(exc.stdout or "").strip(),
                stderr_tail=(exc.stderr or "").strip(),
            ) from exc

        if result.returncode != 0:
            raise CommandError(
                description,
                normalized,
                f"exited with status {result.returncode}",
                stdout_tail=tail_text(result.stdout),
                stderr_tail=tail_text(result.stderr),
            )
        if echo_output:
            if result.stdout:
                print(result.stdout, end="")
            if result.stderr:
                print(result.stderr, end="", file=sys.stderr)
        return result

    def run_streaming_to_file(
        self,
        command: Sequence[str],
        *,
        description: str,
        output_path: Path,
        timeout: int,
        idle_timeout: int | None = None,
        env: Mapping[str, str] | None = None,
        progress_paths: Sequence[Path] = (),
    ) -> None:
        normalized = [str(part) for part in command]
        stdout_tail = bytearray()
        stderr_tail = bytearray()
        start_time = time.monotonic()
        last_progress_time = start_time
        progress_sizes = {
            path: path.stat().st_size if path.exists() else -1
            for path in progress_paths
        }

        try:
            process = subprocess.Popen(
                normalized,
                cwd=self.cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=None if env is None else {**os.environ, **env},
                text=False,
                bufsize=0,
            )
        except FileNotFoundError as exc:
            raise CommandError(
                description, normalized, "command was not found"
            ) from exc

        assert process.stdout is not None
        assert process.stderr is not None

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ, "stdout")
        selector.register(process.stderr, selectors.EVENT_READ, "stderr")

        output_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            with output_path.open("wb") as output_file:
                while True:
                    now = time.monotonic()
                    for path in progress_paths:
                        try:
                            current_size = path.stat().st_size
                        except FileNotFoundError:
                            current_size = -1
                        if current_size != progress_sizes[path]:
                            progress_sizes[path] = current_size
                            last_progress_time = now

                    if now - start_time > timeout:
                        self._terminate_process(process)
                        raise CommandError(
                            description,
                            normalized,
                            f"timed out after {timeout} seconds",
                            stdout_tail=decode_tail(stdout_tail),
                            stderr_tail=decode_tail(stderr_tail),
                        )

                    if (
                        idle_timeout is not None
                        and process.poll() is None
                        and now - last_progress_time > idle_timeout
                    ):
                        self._terminate_process(process)
                        raise CommandError(
                            description,
                            normalized,
                            f"made no stdout/stderr progress for {idle_timeout} seconds; the process may be stuck",
                            stdout_tail=decode_tail(stdout_tail),
                            stderr_tail=decode_tail(stderr_tail),
                        )

                    events = selector.select(timeout=1.0)
                    if not events:
                        if process.poll() is not None and not selector.get_map():
                            break
                        continue

                    for key, _ in events:
                        chunk = os.read(key.fd, 4096)
                        if not chunk:
                            selector.unregister(key.fileobj)
                            continue

                        last_progress_time = time.monotonic()
                        if key.data == "stdout":
                            output_file.write(chunk)
                            output_file.flush()
                            append_tail(stdout_tail, chunk)
                        else:
                            append_tail(stderr_tail, chunk)

                    if process.poll() is not None and not selector.get_map():
                        break
        finally:
            selector.close()
            if process.poll() is None:
                self._terminate_process(process)

        if process.returncode != 0:
            raise CommandError(
                description,
                normalized,
                f"exited with status {process.returncode}",
                stdout_tail=decode_tail(stdout_tail),
                stderr_tail=decode_tail(stderr_tail),
            )

    @staticmethod
    def _terminate_process(process: subprocess.Popen[bytes]) -> None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


class ManagedFileBackup:
    def __init__(self, paths: Iterable[Path]) -> None:
        self.paths = tuple(paths)
        self.snapshots: dict[Path, bytes] = {}

    def __enter__(self) -> "ManagedFileBackup":
        for path in self.paths:
            self.snapshots[path] = path.read_bytes()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        for path, contents in self.snapshots.items():
            path.write_bytes(contents)


@dataclass
class TestCatalog:
    tests: dict[str, Path]
    groups: dict[str, list[str]]

    @classmethod
    def load(cls) -> "TestCatalog":
        tests: dict[str, Path] = {}
        for entry in discover_tests(ROOT):
            if entry.name in tests:
                raise ConfigurationError(
                    f"Duplicate test name in catalog: {entry.name}"
                )
            tests[entry.name] = entry.instr_path

        return cls(tests=tests, groups=discover_groups(ROOT))

    def all_tests(self) -> list[str]:
        return list(self.tests.keys())

    def require_test(self, test_name: str) -> Path:
        if test_name not in self.tests:
            raise ConfigurationError(
                f"Unknown test '{test_name}'. Use -l to list available tests."
            )
        return self.tests[test_name]

    def resolve_group(self, group_name: str) -> tuple[list[str], list[str]]:
        if group_name not in self.groups:
            available = ", ".join(self.groups.keys())
            raise ConfigurationError(
                f"Unknown test group '{group_name}'. Available groups: {available}."
            )

        available_tests: list[str] = []
        missing_tests: list[str] = []
        for test_name in self.groups[group_name]:
            if test_name in self.tests:
                available_tests.append(test_name)
            else:
                missing_tests.append(test_name)
        return available_tests, missing_tests


class TestRunner:
    def __init__(self, catalog: TestCatalog, args: argparse.Namespace) -> None:
        self.catalog = catalog
        self.args = args
        self.command_runner = CommandRunner(ROOT)
        self.coverage_mode = self._resolve_coverage_mode()
        self.cosim_only = args.cosim_only
        self.dromajo_cosim = not args.no_cosim
        self.tracecomp_enabled = not (args.cosim_only or args.no_tracecomp)
        self.show_warnings = args.warnings
        self.default_block_width = self._read_parameter_value(
            TEST_ENV_FILE, "BLOCK_WIDTH"
        )
        self.default_set_count = self._read_parameter_value(DCACHE_FILE, "SET_COUNT")
        self.default_associativity = self._read_parameter_value(DCACHE_FILE, "N")

    def print_all_tests(self) -> None:
        for test_name in self.catalog.all_tests():
            print(test_name)

    def run_single(self, test_name: str, *, varying: bool = False) -> None:
        tests = [test_name]
        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_with_configuration(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            )
        )

    def run_group(self, group_name: str, *, varying: bool = False) -> None:
        tests, missing = self.catalog.resolve_group(group_name)
        if missing:
            missing_text = ", ".join(missing)
            print(
                f"Warning: skipping {len(missing)} tests referenced by '{group_name}' with no catalog entry: {missing_text}",
                file=sys.stderr,
            )
        if not tests:
            raise ConfigurationError(
                f"Group '{group_name}' does not contain any runnable tests."
            )

        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_with_configuration(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            )
        )

    def run_all(self, *, varying: bool = False) -> None:
        tests = self.catalog.all_tests()
        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_with_configuration(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            )
        )

    def run_lint(self, module_name: str) -> None:
        if "/" in module_name or "\\" in module_name:
            raise ConfigurationError(
                "Lint module name must not include a path separator."
            )

        module_file = ROOT / "rtl" / f"{module_name}.sv"
        if not module_file.exists():
            raise ConfigurationError(
                f"RTL module file not found: {format_repo_path(module_file)}"
            )

        lint_runner = CommandRunner(ROOT / "rtl")
        result = lint_runner.run(
            [
                "verilator",
                "--lint-only",
                "-Wall",
                "-Wno-fatal",
                "--top-module",
                module_name,
                f"{module_name}.sv",
            ],
            description=f"Lint {module_name}",
            echo_output=True,
        )
        warning_count = count_verilator_warnings(result.stdout + result.stderr)
        print(f"Verilator warnings: {warning_count}", file=sys.stderr)

    def run_varying_cache(self, tests: list[str]) -> None:
        def work() -> None:
            for block_width in CACHE_SWEEP_BLOCK_WIDTHS:
                for set_count in CACHE_SWEEP_SET_COUNTS:
                    for associativity in CACHE_SWEEP_ASSOCIATIVITIES:
                        self._append_cache_header(block_width, set_count, associativity)
                        self._run_tests(tests, block_width, set_count, associativity)

        self._run_suite(work)

    def clean(self) -> None:
        self._clean_single_artifacts()
        self._clean_generated_artifacts()

    def prepare_for_commit(self) -> None:
        self.clean()
        self.command_runner.run(
            [
                "git",
                "restore",
                format_repo_path(RESULT_FILE),
                format_repo_path(MEMORY_FILE),
            ],
            description="Restore tracked generated files",
        )

    def _run_suite(self, work: Callable[[], None]) -> None:
        self._prepare_workspace()
        success = False

        try:
            with ManagedFileBackup(MANAGED_FILES):
                try:
                    work()
                    success = True
                finally:
                    if success and self.coverage_mode is not None:
                        self._finalize_coverage()
        finally:
            self._restore_default_cache_configuration()

        if success:
            self._clean_generated_tests()

    def _run_tests(
        self, tests: list[str], block_width: int, set_count: int, associativity: int
    ) -> None:
        total = len(tests)
        for index, test_name in enumerate(tests, start=1):
            self._run_single_test(
                test_name, block_width, set_count, associativity, index, total
            )

    def _run_with_configuration(
        self,
        tests: list[str],
        block_width: int,
        set_count: int,
        associativity: int,
    ) -> None:
        self._append_cache_header(block_width, set_count, associativity)
        self._run_tests(tests, block_width, set_count, associativity)

    def _run_single_test(
        self,
        test_name: str,
        block_width: int,
        set_count: int,
        associativity: int,
        index: int,
        total: int,
    ) -> None:
        memory_path = self.catalog.require_test(test_name)
        print(
            f"[{index}/{total}] Running {test_name} "
            f"(BLOCK_WIDTH={block_width}, SET_COUNT={set_count}, ASSOCIATIVITY={associativity}-way)"
        )

        elf_path = self._memory_path_to_elf_path(memory_path)
        self._configure_test_files(
            test_name, memory_path, block_width, set_count, associativity
        )
        self._build_simulator(
            test_name, gen_wave=self.args.trace, coverage_mode=self.coverage_mode
        )
        pmem_write_output = self._run_simulation(test_name, elf_path)

        if self._continues_after_trap(test_name):
            parsed_output = ParsedSimulationOutput(status_text=None)
            self_check = (
                "PASS"
                if self._trap_continuation_passed(test_name, pmem_write_output)
                else "FAIL"
            )
            self_check_failed = self_check == "FAIL"
        else:
            parsed_output = self._parse_simulation_output(
                test_name, require_status=not self.cosim_only
            )

            self_check = (
                "Skipped"
                if self.cosim_only
                else (
                    "Not applicable"
                    if self._is_snippy(test_name)
                    else (
                        "Missing"
                        if parsed_output.status_missing
                        else (parsed_output.status_text or "Unknown")
                    )
                )
            )
            self_check_failed = (
                not self.cosim_only
                and not self._is_snippy(test_name)
                and not self._self_check_passed(parsed_output.status_text)
            )

        if not self.tracecomp_enabled:
            tracecomp_status = "Skipped"
            trace_preview = ""
        else:
            self._run_trace_reference(test_name, memory_path)
            tracecomp_status, trace_preview = self._compare_traces(test_name)

        outcome = TestOutcome(self_check=self_check, tracecomp=tracecomp_status)
        self._record_test_outcome(test_name, outcome)

        failures = []
        if self_check_failed:
            if self._continues_after_trap(test_name):
                failures.append(
                    f"Self Check failed for {test_name}: PMEM output did not match the expected trap-continuation success banner."
                )
            elif parsed_output.status_missing:
                failures.append(
                    f"Self Check missing for {test_name}. See {format_repo_path(RES_FILE)}."
                )
            else:
                failures.append(
                    f"Self Check failed for {test_name}: {self_check}. See {format_repo_path(RES_FILE)}."
                )
        if tracecomp_status == "FAIL":
            failures.append(
                f"Tracecomp failed for {test_name}. Preview saved to {format_repo_path(TEMP_DIFF_FILE)}.\n{trace_preview}"
            )
        if failures:
            self._print_pmem_write_output(pmem_write_output)
            raise TestFailure("\n".join(failures))

        if self.coverage_mode is not None:
            self._stash_coverage_file(test_name, block_width, set_count, associativity)

        self._clean_single_artifacts()
        print(
            colorize_status_text(
                f"  Self Check: {outcome.self_check}; Tracecomp: {outcome.tracecomp}"
            )
        )
        self._print_pmem_write_output(pmem_write_output)

    def _prepare_workspace(self) -> None:
        if self.tracecomp_enabled:
            LOG_TRACE_DIR.mkdir(parents=True, exist_ok=True)
            SPIKE_LOG_TRACE_DIR.mkdir(parents=True, exist_ok=True)
        if self.args.trace:
            WAVEFORM_DIR.mkdir(parents=True, exist_ok=True)

        RESULT_FILE.parent.mkdir(parents=True, exist_ok=True)
        RESULT_FILE.write_text("")

        self._remove_path(RES_FILE)
        self._remove_path(TEMP_DIFF_FILE)
        self._remove_path(SPIKE_TEMP_LOG)
        self._remove_path(COVERAGE_FILE)

        if self.coverage_mode is not None:
            self._remove_path(COV_DIR)
            self._remove_path(MERGED_COVERAGE_FILE)
            self._remove_path(COVERAGE_RESULTS_FILE)
            self._remove_path(COVERAGE_ANNOTATED_DIR)
            COV_DIR.mkdir(parents=True, exist_ok=True)

        self.command_runner.run(
            [sys.executable, format_repo_path(SCRIPT_ELF2DISASM)],
            description="Generate disassembly files",
        )
        self.command_runner.run(
            [sys.executable, format_repo_path(SCRIPT_DISASM2MEM)],
            description="Generate memory images",
        )

    def _build_simulator(
        self, test_name: str, *, gen_wave: bool, coverage_mode: str | None
    ) -> None:
        dromajo_cosim_enabled = self._dromajo_cosim_enabled(test_name)
        c_defines = (
            ["-DMAVERIC_CONTINUE_AFTER_TRAP"]
            if self._continues_after_trap(test_name)
            else []
        )

        self.command_runner.run(
            [
                "gcc",
                *c_defines,
                "-c",
                "-o",
                format_repo_path(ROOT / "check.o"),
                format_repo_path(ROOT / "test/tb/check.c"),
            ],
            description="Compile self-check helper",
        )
        if self.tracecomp_enabled:
            self.command_runner.run(
                [
                    "gcc",
                    *c_defines,
                    "-c",
                    "-o",
                    format_repo_path(ROOT / "log_trace.o"),
                    format_repo_path(ROOT / "test/tb/log_trace.c"),
                ],
                description="Compile log-trace helper",
            )
        self.command_runner.run(
            [
                "gcc",
                *c_defines,
                "-c",
                "-o",
                format_repo_path(ROOT / "pmem_write.o"),
                format_repo_path(ROOT / "test/tb/pmem_write.c"),
            ],
            description="Compile pmem-write helper",
        )

        verilator_command = [
            "verilator",
            "--assert",
            "-I./rtl",
            "--Wall",
            "-Wno-fatal",
            "--cc",
            format_repo_path(ROOT / "rtl/test_env.sv"),
        ]
        if coverage_mode == "all":
            verilator_command.append("--coverage")
        elif coverage_mode == "line":
            verilator_command.append("--coverage-line")
        elif coverage_mode == "toggle":
            verilator_command.append("--coverage-toggle")
        if gen_wave:
            verilator_command.append("--trace")
        if self._continues_after_trap(test_name):
            verilator_command.append("-DMAVERIC_CONTINUE_AFTER_TRAP")
        if dromajo_cosim_enabled:
            verilator_command.append("-DDROMAJO_COSIM")
        if not self.tracecomp_enabled:
            verilator_command.append("-DNO_TRACECOMP")

        verilator_sources = [
            format_repo_path(ROOT / "test/tb/tb_test_env.cpp"),
            format_repo_path(ROOT / "test/tb/check.c"),
            format_repo_path(ROOT / "test/tb/pmem_write.c"),
        ]
        if self.tracecomp_enabled:
            verilator_sources.append(format_repo_path(ROOT / "test/tb/log_trace.c"))
        if dromajo_cosim_enabled:
            verilator_sources.extend(
                [
                    format_repo_path(ROOT / "test/tb/dromajo_cosim.cpp"),
                    str(DROMAJO_LIB),
                ]
            )

        cflags = []
        cflags.extend(c_defines)
        if dromajo_cosim_enabled:
            cflags.extend([f"-I{DROMAJO_INCLUDE}", "-DDROMAJO_COSIM"])
        if cflags:
            verilator_command.extend(["-CFLAGS", " ".join(cflags)])

        verilator_command.extend(["--exe", *verilator_sources])

        verilator_result = self.command_runner.run(
            verilator_command,
            description="Run Verilator",
            echo_output=self.show_warnings,
        )
        if self.show_warnings:
            warning_count = count_verilator_warnings(
                verilator_result.stdout + verilator_result.stderr
            )
            print(f"Verilator warnings: {warning_count}", file=sys.stderr)
        self.command_runner.run(
            ["make", "-C", format_repo_path(OBJ_DIR), "-f", "Vtest_env.mk"],
            description="Build generated simulator",
        )

    def _run_simulation(self, test_name: str, elf_path: Path) -> str:
        self._remove_path(RES_FILE)
        pmem_write_file = self._pmem_write_path(test_name)
        pmem_write_file.parent.mkdir(parents=True, exist_ok=True)
        pmem_write_file.write_bytes(b"")

        simulation_env = {"MAVERIC_PMEM_WRITE_FILE": format_repo_path(pmem_write_file)}
        progress_paths: list[Path] = []

        if self.tracecomp_enabled:
            rtl_trace_file = self._rtl_trace_path(test_name)
            rtl_trace_file.parent.mkdir(parents=True, exist_ok=True)
            rtl_trace_file.write_text("")
            simulation_env.update(
                {"MAVERIC_RTL_TRACE_FILE": format_repo_path(rtl_trace_file)}
            )
            progress_paths.append(rtl_trace_file)
        progress_paths.append(pmem_write_file)

        idle_timeout = (
            None
            if self._continues_after_trap(test_name)
            else SIMULATION_IDLE_TIMEOUT_SECONDS
        )

        self.command_runner.run_streaming_to_file(
            [format_repo_path(SIM_BINARY), format_repo_path(elf_path)],
            description=f"Run RTL simulation for {test_name}",
            output_path=RES_FILE,
            timeout=SIMULATION_TIMEOUT_SECONDS,
            idle_timeout=idle_timeout,
            env=simulation_env,
            progress_paths=progress_paths,
        )
        return pmem_write_file.read_bytes().decode("utf-8", errors="replace")

    def _run_trace_reference(self, test_name: str, memory_path: Path) -> None:
        spike_trace_path = SPIKE_LOG_TRACE_DIR / f"{test_name}-log-trace.log"
        spike_original_path = SPIKE_LOG_TRACE_DIR / f"{test_name}-spike-original.log"
        self._remove_path(spike_trace_path)
        self._remove_path(spike_original_path)
        elf_path = self._memory_path_to_elf_path(memory_path)
        self.command_runner.run(
            [
                sys.executable,
                format_repo_path(SCRIPT_TRACECOMP),
                test_name,
                format_repo_path(elf_path),
            ],
            description=f"Generate Spike trace for {test_name}",
            timeout=TRACE_TIMEOUT_SECONDS,
        )

    def _parse_simulation_output(
        self, test_name: str, *, require_status: bool = True
    ) -> ParsedSimulationOutput:
        if not RES_FILE.exists():
            raise SimulationOutputError(
                f"Simulation output file {format_repo_path(RES_FILE)} was not created for {test_name}."
            )

        match = STATUS_COLOR_RE.search(RES_FILE.read_text())
        if match is not None:
            return ParsedSimulationOutput(status_text=match.group(1))

        if self._is_snippy(test_name) or not require_status:
            return ParsedSimulationOutput(status_text=None)

        return ParsedSimulationOutput(status_text=None, status_missing=True)

    @staticmethod
    def _rtl_trace_path(test_name: str) -> Path:
        return LOG_TRACE_DIR / f"{test_name}-log-trace.log"

    @staticmethod
    def _pmem_write_path(test_name: str) -> Path:
        return PMEM_WRITE_DIR / f"{test_name}-pmem-write.log"

    @staticmethod
    def _print_pmem_write_output(pmem_write_output: str) -> None:
        if not pmem_write_output:
            return

        lines = pmem_write_output.splitlines()
        if len(lines) <= 1 and not pmem_write_output.endswith("\n"):
            print(f"  PMEM MMIO write: {pmem_write_output}")
            return

        print("  PMEM MMIO write:")
        for line in lines:
            print(f"    {line}")

    def _compare_traces(self, test_name: str) -> tuple[str, str]:
        rtl_trace_file = self._rtl_trace_path(test_name)
        spike_trace_file = SPIKE_LOG_TRACE_DIR / f"{test_name}-log-trace.log"

        if not rtl_trace_file.exists():
            raise SimulationOutputError(
                f"RTL trace file {format_repo_path(rtl_trace_file)} was not produced for {test_name}."
            )
        if not spike_trace_file.exists():
            raise SimulationOutputError(
                f"Spike trace file {format_repo_path(spike_trace_file)} was not produced for {test_name}."
            )

        rtl_lines = rtl_trace_file.read_text().splitlines(keepends=True)
        spike_lines = spike_trace_file.read_text().splitlines(keepends=True)

        if self._continues_after_trap(test_name):
            rtl_lines = self._normalize_trap_continuation_trace_lines(rtl_lines)
            spike_lines = self._normalize_trap_continuation_trace_lines(spike_lines)

        if not spike_lines:
            self._remove_path(TEMP_DIFF_FILE)
            return "Not applicable", ""

        diff_preview_lines = list(
            islice(
                difflib.unified_diff(
                    rtl_lines,
                    spike_lines,
                    fromfile=format_repo_path(rtl_trace_file),
                    tofile=format_repo_path(spike_trace_file),
                    n=2,
                ),
                10,
            )
        )

        if not diff_preview_lines:
            self._remove_path(TEMP_DIFF_FILE)
            return "PASS", ""

        preview = "".join(diff_preview_lines).strip()
        TEMP_DIFF_FILE.write_text(preview + "\n")
        return "FAIL", preview

    def _record_test_outcome(self, test_name: str, outcome: TestOutcome) -> None:
        with RESULT_FILE.open("a") as result_file:
            result_file.write(
                f"{test_name + ': ':<29}Self Check: {outcome.self_check}    Tracecomp: {outcome.tracecomp}\n"
            )

    def _append_cache_header(
        self, block_width: int, set_count: int, associativity: int
    ) -> None:
        message = (
            f"\n\nCACHE_LINE_WIDTH: {block_width} bits, "
            f"SET_COUNT: {set_count}, ASSOCIATIVITY: {associativity}-way\n"
        )
        with RESULT_FILE.open("a") as result_file:
            result_file.write(message)

    def _stash_coverage_file(
        self, test_name: str, block_width: int, set_count: int, associativity: int
    ) -> None:
        if not COVERAGE_FILE.exists():
            raise SimulationOutputError(
                f"Coverage was requested, but {format_repo_path(COVERAGE_FILE)} was not produced for {test_name}."
            )

        destination = (
            COV_DIR
            / f"coverage_{test_name}_{block_width}_{set_count}_{associativity}.dat"
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        COVERAGE_FILE.replace(destination)

    def _finalize_coverage(self) -> None:
        coverage_inputs = sorted(COV_DIR.glob("*.dat"))
        if not coverage_inputs:
            raise SimulationOutputError(
                f"No per-test coverage files were produced in {format_repo_path(COV_DIR)}."
            )

        self.command_runner.run(
            ["verilator_coverage", "--write", format_repo_path(MERGED_COVERAGE_FILE)]
            + [format_repo_path(path) for path in coverage_inputs],
            description="Merge coverage files",
        )

        result = self.command_runner.run(
            [
                "verilator_coverage",
                "--annotate",
                format_repo_path(COVERAGE_ANNOTATED_DIR),
                format_repo_path(MERGED_COVERAGE_FILE),
            ],
            description="Annotate coverage results",
        )
        COVERAGE_RESULTS_FILE.write_text(result.stdout + result.stderr)
        self._remove_path(COV_DIR)

    def _configure_test_files(
        self,
        test_name: str,
        memory_path: Path,
        block_width: int,
        set_count: int,
        associativity: int,
    ) -> None:
        self._modify_testbench(
            test_name,
            enable_trace=self.args.trace,
            enable_coverage=self.coverage_mode is not None,
        )
        if self._read_parameter_value(TEST_ENV_FILE, "BLOCK_WIDTH") != block_width:
            self._replace_in_file(
                TEST_ENV_FILE,
                r"(parameter\s+BLOCK_WIDTH\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{block_width}",
                label="BLOCK_WIDTH",
            )
        if self._read_parameter_value(DCACHE_FILE, "SET_COUNT") != set_count:
            self._replace_in_file(
                DCACHE_FILE,
                r"(parameter\s+SET_COUNT\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{set_count}",
                label="SET_COUNT",
            )
        if self._read_parameter_value(DCACHE_FILE, "N") != associativity:
            self._replace_in_file(
                DCACHE_FILE,
                r"(parameter\s+N\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{associativity}",
                label="N",
            )
        self._replace_in_file(
            MEMORY_FILE,
            r'^\s*`define\s+PATH_TO_MEM\s+".*"\s*$',
            lambda _: f'`define PATH_TO_MEM "./{memory_path.as_posix()}"',
            label="PATH_TO_MEM",
            flags=re.MULTILINE,
        )

    def _restore_default_cache_configuration(self) -> None:
        if (
            TEST_ENV_FILE.exists()
            and self._read_parameter_value(TEST_ENV_FILE, "BLOCK_WIDTH")
            != self.default_block_width
        ):
            self._replace_in_file(
                TEST_ENV_FILE,
                r"(parameter\s+BLOCK_WIDTH\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{self.default_block_width}",
                label="BLOCK_WIDTH",
            )

        if (
            DCACHE_FILE.exists()
            and self._read_parameter_value(DCACHE_FILE, "SET_COUNT")
            != self.default_set_count
        ):
            self._replace_in_file(
                DCACHE_FILE,
                r"(parameter\s+SET_COUNT\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{self.default_set_count}",
                label="SET_COUNT",
            )

        if (
            DCACHE_FILE.exists()
            and self._read_parameter_value(DCACHE_FILE, "N")
            != self.default_associativity
        ):
            self._replace_in_file(
                DCACHE_FILE,
                r"(parameter\s+N\s*=\s*)\d+",
                lambda match: f"{match.group(1)}{self.default_associativity}",
                label="N",
            )

    def _modify_testbench(
        self, test_name: str, *, enable_trace: bool, enable_coverage: bool
    ) -> None:
        text = TB_FILE.read_text()
        replacements = [
            (
                r"^\s*(?://\s*)?Verilated::traceEverOn\(true\);\s*$",
                "  Verilated::traceEverOn(true);",
                enable_trace,
                "traceEverOn",
            ),
            (
                r"^\s*(?://\s*)?VerilatedVcdC\*\s+sim_trace\s*=\s*new\s+VerilatedVcdC;\s*$",
                "  VerilatedVcdC* sim_trace = new VerilatedVcdC;",
                enable_trace,
                "sim_trace allocation",
            ),
            (
                r"^\s*(?://\s*)?dut->trace\(sim_trace,\s*10\);\s*$",
                "  dut->trace(sim_trace, 10);",
                enable_trace,
                "trace hookup",
            ),
            (
                r'^\s*(?://\s*)?sim_trace->open\(".*"\);\s*$',
                f'  sim_trace->open("./waveform/{test_name}_waveform.vcd");',
                enable_trace,
                "waveform path",
            ),
            (
                r"^\s*(?://\s*)?sim_trace->dump\(sim_time\);\s*$",
                "      sim_trace->dump(sim_time);",
                enable_trace,
                "trace dump",
            ),
            (
                r"^\s*(?://\s*)?sim_trace->close\(\);\s*$",
                "  sim_trace->close();",
                enable_trace,
                "trace close",
            ),
            (
                r"^\s*(?://\s*)?delete\s+sim_trace;\s*$",
                "  delete sim_trace;",
                enable_trace,
                "trace delete",
            ),
            (
                r'^\s*(?://\s*)?VerilatedCov::write\("coverage\.dat"\);\s*$',
                '  VerilatedCov::write("coverage.dat");',
                enable_coverage,
                "coverage write",
            ),
        ]

        for pattern, active_line, enabled, label in replacements:
            replacement = active_line if enabled else f"//{active_line}"
            text, count = re.subn(
                pattern, replacement, text, count=1, flags=re.MULTILINE
            )
            if count != 1:
                raise ConfigurationError(
                    f"Could not update {label} in {format_repo_path(TB_FILE)}."
                )

        TB_FILE.write_text(text)

    @staticmethod
    def _replace_in_file(
        path: Path,
        pattern: str,
        replacement,
        *,
        label: str,
        flags: int = 0,
    ) -> None:
        text = path.read_text()
        new_text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
        if count != 1:
            raise ConfigurationError(
                f"Could not update {label} in {format_repo_path(path)}."
            )
        path.write_text(new_text)

    @staticmethod
    def _read_parameter_value(path: Path, parameter_name: str) -> int:
        text = path.read_text()
        pattern = re.compile(
            rf"\bparameter\s+{re.escape(parameter_name)}\s*=\s*(\d+)\b"
        )
        match = pattern.search(text)
        if match is None:
            raise ConfigurationError(
                f"Could not read parameter {parameter_name} from {format_repo_path(path)}."
            )
        return int(match.group(1))

    @staticmethod
    def _remove_path(path: Path) -> None:
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)

    @staticmethod
    def _is_snippy(test_name: str) -> bool:
        return test_name.startswith("snippy-")

    @staticmethod
    def _continues_after_trap(test_name: str) -> bool:
        return test_name in TRAP_CONTINUATION_TESTS

    @staticmethod
    def _trap_continuation_passed(test_name: str, pmem_write_output: str) -> bool:
        expected_output = TRAP_CONTINUATION_PMEM_EXPECTED.get(test_name)
        if expected_output is None:
            raise ConfigurationError(
                f"No PMEM success banner configured for trap-continuation test {test_name}."
            )
        return pmem_write_output == expected_output

    def _dromajo_cosim_enabled(self, test_name: str) -> bool:
        return self.dromajo_cosim and not self._continues_after_trap(test_name)

    @staticmethod
    def _self_check_passed(status_text: str | None) -> bool:
        return status_text is not None and "pass" in status_text.lower()

    @staticmethod
    def _memory_path_to_elf_path(memory_path: Path) -> Path:
        relative = memory_path.as_posix()
        elf_relative = relative.replace("/instr/", "/bin/", 1)
        if elf_relative == relative:
            raise ConfigurationError(f"Could not derive ELF path from {memory_path}.")

        elf_path = Path(elf_relative).with_suffix(".elf")
        absolute_path = ROOT / elf_path
        if not absolute_path.exists():
            raise ConfigurationError(
                f"Expected ELF file not found: {format_repo_path(absolute_path)}"
            )
        return absolute_path

    @staticmethod
    def _normalize_trap_continuation_trace_lines(lines: list[str]) -> list[str]:
        normalized_lines = [
            TestRunner._normalize_trap_continuation_trace_line(line) for line in lines
        ]
        return TestRunner._drop_poll_retry_iterations(normalized_lines)

    @staticmethod
    def _normalize_trap_continuation_trace_line(line: str) -> str:
        match = TRACE_INSTR_RE.search(line)
        if match is None:
            return line

        csr_addr = TestRunner._decode_csr_addr(match.group(1))
        if csr_addr == MSTATUS_CSR_ADDR:
            return TestRunner._normalize_mstatus_trace_line(line)
        if csr_addr == TIME_CSR_ADDR:
            return TestRunner._normalize_time_trace_line(line)
        return line

    @staticmethod
    def _decode_csr_addr(instruction: str) -> int | None:
        instruction_value = int(instruction, 16)
        opcode = instruction_value & 0x7F
        func3 = (instruction_value >> 12) & 0x7
        if opcode != CSR_OPCODE or func3 == 0:
            return None
        return (instruction_value >> 20) & 0xFFF

    @staticmethod
    def _normalize_mstatus_trace_line(line: str) -> str:
        csr_value_re = TestRunner._trace_csr_value_re(MSTATUS_CSR_ADDR)
        line = TRACE_REG_VALUE_RE.sub(r"\g<1>0x0000000000000000", line)
        return csr_value_re.sub(r"\g<1>0x0000000000000000", line)

    @staticmethod
    def _normalize_time_trace_line(line: str) -> str:
        csr_value_re = TestRunner._trace_csr_value_re(TIME_CSR_ADDR)
        line = TRACE_REG_VALUE_RE.sub(r"\g<1>0x0000000000000000", line)
        return csr_value_re.sub(r"\g<1>0x0000000000000000", line)

    @staticmethod
    def _trace_csr_value_re(csr_addr: int) -> re.Pattern[str]:
        return re.compile(rf"(c{csr_addr}(?:_[^:]+)?: )0x([0-9a-fA-F]{{16}})")

    @staticmethod
    def _drop_poll_retry_iterations(lines: list[str]) -> list[str]:
        filtered: list[str] = []
        index = 0
        while index < len(lines):
            if TestRunner._is_poll_retry_iteration(lines, index):
                index += 5
                continue

            filtered.append(lines[index])
            index += 1
        return filtered

    @staticmethod
    def _is_poll_retry_iteration(lines: list[str], index: int) -> bool:
        if index + 4 >= len(lines):
            return False

        return (
            "c836" in lines[index]
            and "INSTR: 0xfffe8e93" in lines[index + 3]
            and lines[index + 4].rstrip().endswith("e3")
        )

    @staticmethod
    def _resolve_coverage_mode_from_args(args: argparse.Namespace) -> str | None:
        if args.coverage_all:
            return "all"
        if args.coverage_line:
            return "line"
        if args.coverage_toggle:
            return "toggle"
        return None

    def _resolve_coverage_mode(self) -> str | None:
        return self._resolve_coverage_mode_from_args(self.args)

    def _clean_single_artifacts(self) -> None:
        for path in (
            OBJ_DIR,
            ROOT / "check.o",
            ROOT / "log_trace.o",
            ROOT / "pmem_write.o",
            PMEM_WRITE_DIR,
            RES_FILE,
            TEMP_DIFF_FILE,
            SPIKE_TEMP_LOG,
            COVERAGE_FILE,
        ):
            self._remove_path(path)

    def _clean_generated_tests(self) -> None:
        for path in GENERATED_TEST_DIRS:
            self._remove_path(path)

    def _clean_generated_artifacts(self) -> None:
        self._clean_generated_tests()
        for path in (
            LOG_TRACE_DIR,
            SPIKE_LOG_TRACE_DIR,
            WAVEFORM_DIR,
            COV_DIR,
            COVERAGE_ANNOTATED_DIR,
            MERGED_COVERAGE_FILE,
            COVERAGE_RESULTS_FILE,
        ):
            self._remove_path(path)


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=HELP_MSG_SCRIPT_DESCRIPTION)
    operations = parser.add_mutually_exclusive_group(required=True)
    operations.add_argument(
        "-a", "--compile-all", action="store_true", help=HELP_MSG_ALL_DESCRIPTION
    )
    operations.add_argument(
        "-l", "--list-tests", action="store_true", help=HELP_MSG_LIST_DESCRIPTION
    )
    operations.add_argument(
        "-s",
        "--compile-single",
        type=str,
        metavar="test_name",
        help=HELP_MSG_SINGLE_DESCRIPTION,
    )
    operations.add_argument(
        "-g",
        "--compile-group",
        type=str,
        metavar="test_group",
        help=HELP_MSG_GROUP_DESCRIPTION,
    )
    operations.add_argument(
        "-L",
        "--lint-module",
        type=str,
        metavar="module_name",
        help=HELP_MSG_LINT_DESCRIPTION,
    )
    operations.add_argument(
        "-c", "--clean", action="store_true", help=HELP_MSG_CLEAN_DESCRIPTION
    )
    operations.add_argument(
        "-p",
        "--prepare-for-commit",
        action="store_true",
        help=HELP_MSG_PREP_FOR_COMMIT_DESCRIPTION,
    )

    parser.add_argument(
        "-v",
        "--compile-varying-cache",
        action="store_true",
        help=HELP_MSG_VARYING_DESCRIPTION,
    )
    parser.add_argument(
        "-t", "--trace", action="store_true", help=HELP_MSG_TRACE_DESCRIPTION
    )
    parser.add_argument(
        "--cosim-only", action="store_true", help=HELP_MSG_COSIM_ONLY_DESCRIPTION
    )
    parser.add_argument(
        "--no-cosim",
        action="store_true",
        help=HELP_MSG_NO_COSIM_DESCRIPTION,
    )
    parser.add_argument(
        "--no-tracecomp",
        action="store_true",
        help=HELP_MSG_NO_TRACECOMP_DESCRIPTION,
    )
    parser.add_argument(
        "-w", "--warnings", action="store_true", help=HELP_MSG_WARNINGS_DESCRIPTION
    )

    coverage_group = parser.add_mutually_exclusive_group()
    coverage_group.add_argument(
        "-ca",
        "--coverage-all",
        action="store_true",
        help=HELP_MSG_COVERAGE_ALL_DESCRIPTION,
    )
    coverage_group.add_argument(
        "-cl",
        "--coverage-line",
        action="store_true",
        help=HELP_MSG_COVERAGE_LINE_DESCRIPTION,
    )
    coverage_group.add_argument(
        "-ct",
        "--coverage-toggle",
        action="store_true",
        help=HELP_MSG_COVERAGE_TOGGLE_DESCRIPTION,
    )
    return parser


def validate_arguments(args: argparse.Namespace) -> None:
    is_test_run = any(
        (
            args.compile_all,
            args.compile_single is not None,
            args.compile_group is not None,
        )
    )
    coverage_requested = TestRunner._resolve_coverage_mode_from_args(args) is not None

    if args.compile_varying_cache and not is_test_run:
        raise ConfigurationError(
            "--compile-varying-cache (-v) must be used with -s, -g, or -a."
        )
    if args.trace and not is_test_run:
        raise ConfigurationError(
            "--trace can only be used with a test-running command."
        )
    if args.cosim_only and not is_test_run:
        raise ConfigurationError(
            "--cosim-only can only be used with a test-running command."
        )
    if args.no_cosim and not is_test_run:
        raise ConfigurationError(
            "--no-cosim can only be used with a test-running command."
        )
    if args.no_tracecomp and not is_test_run:
        raise ConfigurationError(
            "--no-tracecomp can only be used with a test-running command."
        )
    if args.cosim_only and args.no_cosim:
        raise ConfigurationError(
            "--cosim-only requires Dromajo co-simulation; remove --no-cosim."
        )
    if coverage_requested and not is_test_run:
        raise ConfigurationError(
            "Coverage options can only be used with a test-running command."
        )


def main() -> int:
    parser = build_argument_parser()
    args = parser.parse_args()

    try:
        validate_arguments(args)
        catalog = TestCatalog.load()
        runner = TestRunner(catalog, args)

        if args.list_tests:
            runner.print_all_tests()
        elif args.compile_single:
            runner.run_single(args.compile_single, varying=args.compile_varying_cache)
        elif args.compile_group:
            runner.run_group(args.compile_group, varying=args.compile_varying_cache)
        elif args.compile_all:
            runner.run_all(varying=args.compile_varying_cache)
        elif args.lint_module:
            runner.run_lint(args.lint_module)
        elif args.prepare_for_commit:
            runner.prepare_for_commit()
        elif args.clean:
            runner.clean()
        else:
            raise ConfigurationError("No valid command was provided.")
    except RunTestsError as exc:
        print(colorize_status_text(f"Error: {exc}"), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
