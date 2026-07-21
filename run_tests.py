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
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from itertools import islice
from pathlib import Path
from typing import Callable, Mapping, Sequence

from scripts import disasm2mem, elf2disasm
from scripts.test_catalog import (
    GROUP_NAMES,
    SUBGROUP_NAMES,
    TestEntry,
    cosim_only_tests,
    discover_groups,
    discover_subgroups,
    discover_tests,
    no_tracecomp_tests,
    self_loop_continue_tests,
    trap_continuation_tests,
)


ROOT = Path(__file__).resolve().parent

SCRIPT_TRACECOMP = ROOT / "scripts/tracecomp.py"

RESULT_FILE = ROOT / "results/result.txt"

DROMAJO_DIR = ROOT / "tools/dromajo"
DROMAJO_INCLUDE = DROMAJO_DIR / "include"
DROMAJO_LIB = DROMAJO_DIR / "build" / "libdromajo_cosim.a"

# All run artifacts live under build/: generated test inputs, per-test
# Verilator builds, run outputs, traces, waveforms, and coverage.
BUILD_DIR = ROOT / "build"
BUILD_OBJ_DIR = BUILD_DIR / "obj"
BUILD_RUN_DIR = BUILD_DIR / "run"
LOG_TRACE_DIR = BUILD_DIR / "log_trace"
SPIKE_LOG_TRACE_DIR = BUILD_DIR / "spike_log_trace"
PMEM_WRITE_DIR = BUILD_DIR / "pmem_write"
WAVEFORM_DIR = BUILD_DIR / "waveform"
COV_DIR = BUILD_DIR / "cov"
COVERAGE_OUT_DIR = BUILD_DIR / "coverage"
MERGED_COVERAGE_FILE = COVERAGE_OUT_DIR / "merged.dat"
COVERAGE_RESULTS_FILE = COVERAGE_OUT_DIR / "coverage_results.txt"
COVERAGE_ANNOTATED_DIR = COVERAGE_OUT_DIR / "annotated"

# Artifact locations used before the build/ tree existed; removed by -c so a
# checkout carrying them transitions cleanly.
LEGACY_ARTIFACTS = (
    ROOT / "obj_dir",
    ROOT / "check.o",
    ROOT / "log_trace.o",
    ROOT / "pmem_write.o",
    ROOT / "res.txt",
    ROOT / "temp.txt",
    ROOT / "trace.log",
    ROOT / "log_trace",
    ROOT / "spike_log_trace",
    ROOT / "pmem_write",
    ROOT / "waveform",
    ROOT / "cov",
    ROOT / "coverage.dat",
    ROOT / "merged.dat",
    ROOT / "coverage_annotated",
    ROOT / "coverage_results.txt",
    ROOT / "test/tests/dis-asm",
    ROOT / "test/tests/instr",
)

DEFAULT_BLOCK_WIDTH = 512
DEFAULT_SET_COUNT = 4
DEFAULT_ASSOCIATIVITY = 4

CACHE_SWEEP_BLOCK_WIDTHS = (128, 256, 512, 1024)
CACHE_SWEEP_SET_COUNTS = (2, 4, 8, 16)

COMMAND_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_COMMAND_TIMEOUT_SEC", "600"))
SIMULATION_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_SIM_TIMEOUT_SEC", "180"))
SIMULATION_IDLE_TIMEOUT_SECONDS = int(
    os.environ.get("MAVERIC_SIM_IDLE_TIMEOUT_SEC", "20")
)
TRACE_TIMEOUT_SECONDS = int(os.environ.get("MAVERIC_TRACE_TIMEOUT_SEC", "20"))
# Simulation log files (RTL trace, PMEM writes) that grow past this size stop
# the run with a LOG-LIMIT outcome instead of filling the disk.
TRACE_MAX_BYTES = int(
    os.environ.get("MAVERIC_TRACE_MAX_BYTES", str(3 * 1024 * 1024 * 1024))
)
# Backstop simulation budget (half-clock ticks) for runs that end via a trap or
# a self-loop; SELF_LOOP_CONTINUE tests instead run out this reduced budget so
# check_final() reports their last a0 status (the historical MAX_SIM_TIME).
# xv6 tests boot a kernel and need a far larger budget than any bare-metal test.
DEFAULT_MAX_SIM_TIME = 20_000_000
XV6_MAX_SIM_TIME = 20_000_000_000
SELF_LOOP_CONTINUE_SIM_TIME = 20_000_000

OUTPUT_TAIL_BYTES = 8192
VERILATOR_WARNING_RE = re.compile(r"^%Warning(?:-[A-Za-z0-9_]+)?:", re.MULTILINE)
STATUS_COLOR_RE = re.compile(r"\b(PASS|FAIL|N/A|Skipped)\b")
ANSI_GREEN = "\033[32m"
ANSI_RED = "\033[31m"
ANSI_YELLOW = "\033[33m"
ANSI_RESET = "\033[0m"
STATUS_COLORS = {
    "PASS": ANSI_GREEN,
    "FAIL": ANSI_RED,
    "N/A": ANSI_YELLOW,
    "Skipped": ANSI_YELLOW,
}
DEFAULT_TESTS = (
    "custom-clint-msi-test",
    "custom-clint-mti-test",
    "custom-clint-msi-mti",
    "custom-clint-mti-irq-regwrite",
)
TRAP_CONTINUATION_TESTS = trap_continuation_tests()
COSIM_ONLY_TESTS = cosim_only_tests()
NO_TRACECOMP_TESTS = no_tracecomp_tests()
SELF_LOOP_CONTINUE_TESTS = self_loop_continue_tests()


HELP_MSG_SCRIPT_DESCRIPTION = (
    "Utility script to automate test runs on the MAVERIC CORE 2.0 processor. "
    "With no operation flag, runs the default CLINT interrupt tests."
)
HELP_MSG_ALL_DESCRIPTION = "Run all tests."
HELP_MSG_LIST_DESCRIPTION = "Print the list of all available tests."
HELP_MSG_SINGLE_DESCRIPTION = (
    "Run a single test. Format: -s <test_name>. Use -l to list available tests."
)
HELP_MSG_GROUP_DESCRIPTION = (
    f"Run a group of tests. Available groups: {', '.join(GROUP_NAMES)}. "
    f"Sub-groups: {', '.join(SUBGROUP_NAMES)}."
)
HELP_MSG_LINT_DESCRIPTION = "Run Verilator lint-only check for an RTL module."
HELP_MSG_CLEAN_DESCRIPTION = (
    "Delete the build/ tree (generated test inputs, per-test builds, traces, "
    "coverage) and legacy root artifacts."
)
HELP_MSG_TRACE_DESCRIPTION = "Generate a waveform dump for the executed tests."
HELP_MSG_VARYING_DESCRIPTION = "Sweep BLOCK_WIDTH from 128 b to 1024 b and SET_COUNT from 2 to 16, holding D-cache associativity at the saved default (N=4). Applies to the default run, -s, -g, or -a."
HELP_MSG_COVERAGE_ALL_DESCRIPTION = "Generate both line and toggle coverage."
HELP_MSG_COVERAGE_LINE_DESCRIPTION = "Generate line coverage only."
HELP_MSG_COVERAGE_TOGGLE_DESCRIPTION = "Generate toggle coverage only."
HELP_MSG_PREP_FOR_COMMIT_DESCRIPTION = (
    "Remove generated artifacts and restore autoupdated tracked files."
)
HELP_MSG_COSIM_ONLY_DESCRIPTION = (
    "Run only the Dromajo co-simulation; skip RTL self-check validation, "
    "Spike trace generation, and tracecomp."
)
HELP_MSG_NO_COSIM_DESCRIPTION = (
    "Disable Dromajo co-simulation; keep RTL self-checks and Spike trace comparison."
)
HELP_MSG_NO_TRACECOMP_DESCRIPTION = (
    "Disable RTL trace logging, Spike trace generation, and trace comparison."
)
HELP_MSG_NO_SPIKETRACE_DESCRIPTION = (
    "Keep RTL trace logging, but skip Spike trace generation and trace "
    "comparison (Tracecomp is reported as N/A)."
)
HELP_MSG_NO_SELF_CHECK_DESCRIPTION = (
    "Do not enforce the a0 self-check; report it as N/A instead of PASS/FAIL."
)
HELP_MSG_JOBS_DESCRIPTION = (
    "Run up to N tests concurrently (default: 1). Each test builds its own "
    "simulator under build/obj/<test>, so batch runs scale with N."
)
HELP_MSG_CONTINUE_AFTER_TRAP_DESCRIPTION = (
    "Run every test past the ebreak/ecall trap instead of finishing on it "
    "(forces MAVERIC_CONTINUE_AFTER_TRAP for all tests)."
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


class TraceLimitExceeded(RunTestsError):
    """Raised when a simulation log file grows past TRACE_MAX_BYTES."""

    def __init__(self, path: Path, size: int, limit: int) -> None:
        self.path = path
        self.size = size
        self.limit = limit
        super().__init__(
            f"{format_repo_path(path)} grew to {size} bytes, exceeding the "
            f"{limit}-byte cap (MAVERIC_TRACE_MAX_BYTES); simulation stopped."
        )


@dataclass(frozen=True)
class ParsedSimulationOutput:
    status_text: str | None
    status_missing: bool = False


@dataclass(frozen=True)
class TestOutcome:
    self_check: str
    tracecomp: str


@dataclass(frozen=True)
class TestPaths:
    """Per-test artifact locations inside the build/ tree."""

    obj_dir: Path
    sim_binary: Path
    run_dir: Path
    res_file: Path
    trace_diff_file: Path
    spike_scratch_log: Path
    coverage_file: Path
    rtl_trace_file: Path
    spike_trace_file: Path
    spike_original_file: Path
    pmem_write_file: Path
    waveform_file: Path


def format_command(command: Sequence[str]) -> str:
    return shlex.join(str(part) for part in command)


def format_repo_path(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def format_result_row(test_name: str, outcome: TestOutcome) -> str:
    return (
        f"{test_name + ': ':<29}"
        f"Self Check: {outcome.self_check}    Tracecomp: {outcome.tracecomp}\n"
    )


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
        color = STATUS_COLORS[status]
        return f"{color}{status}{ANSI_RESET}"

    return STATUS_COLOR_RE.sub(colorize, text)


def format_duration(seconds: float) -> str:
    minutes, secs = divmod(seconds, 60)
    hours, minutes = divmod(int(minutes), 60)
    if hours:
        return f"{hours}h{minutes:02d}m{secs:04.1f}s"
    return f"{int(minutes)}m{secs:04.1f}s"


class TestConsole:
    """Sink for one test's console output.

    Serial runs pass text straight through; parallel runs buffer it so each
    test's output is printed as one uninterleaved block on completion."""

    def __init__(self, buffered: bool) -> None:
        self.buffered = buffered
        self._lines: list[str] = []

    def emit(self, text: str = "") -> None:
        if self.buffered:
            self._lines.append(text)
        else:
            print(text, flush=True)

    def flush(self) -> None:
        for line in self._lines:
            print(line, flush=True)
        self._lines.clear()


class PmemWriteStreamer:
    """Echo MMIO PMEM writes to stdout as the simulation produces them."""

    HEADER = "  PMEM MMIO write:"
    INDENT = "    "

    def __init__(self, path: Path) -> None:
        self._path = path
        self._offset = 0
        self._pending = bytearray()
        self._header_printed = False

    def pump(self) -> None:
        try:
            with self._path.open("rb") as handle:
                handle.seek(self._offset)
                chunk = handle.read()
                self._offset = handle.tell()
        except FileNotFoundError:
            return
        if chunk:
            self._consume(chunk)

    def finalize(self) -> None:
        self.pump()
        if self._pending:
            self._emit_line(bytes(self._pending))
            self._pending.clear()

    def _consume(self, chunk: bytes) -> None:
        self._pending.extend(chunk)
        while True:
            newline_index = self._pending.find(b"\n")
            if newline_index == -1:
                break
            line = bytes(self._pending[:newline_index])
            del self._pending[: newline_index + 1]
            self._emit_line(line)

    def _emit_line(self, line: bytes) -> None:
        if not self._header_printed:
            print(self.HEADER, flush=True)
            self._header_printed = True
        print(f"{self.INDENT}{line.decode('utf-8', errors='replace')}", flush=True)


class CommandRunner:
    def __init__(self, cwd: Path) -> None:
        self.cwd = cwd

    def run(
        self,
        command: Sequence[str],
        *,
        description: str,
        timeout: int | None = COMMAND_TIMEOUT_SECONDS,
        echo_output: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        normalized = [str(part) for part in command]
        try:
            result = subprocess.run(
                normalized,
                cwd=self.cwd,
                stdin=subprocess.DEVNULL,
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
        timeout: int | None,
        idle_timeout: int | None = None,
        env: Mapping[str, str] | None = None,
        progress_paths: Sequence[Path] = (),
        size_limits: Sequence[tuple[Path, int]] = (),
        poll_callback: Callable[[], None] | None = None,
        cancel_event: threading.Event | None = None,
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
                stdin=subprocess.DEVNULL,
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

                    for limit_path, limit_bytes in size_limits:
                        try:
                            limit_size = limit_path.stat().st_size
                        except FileNotFoundError:
                            continue
                        if limit_size > limit_bytes:
                            self._terminate_process(process)
                            raise TraceLimitExceeded(
                                limit_path, limit_size, limit_bytes
                            )

                    if cancel_event is not None and cancel_event.is_set():
                        self._terminate_process(process)
                        raise CommandError(description, normalized, "cancelled")

                    if poll_callback is not None:
                        poll_callback()

                    if timeout is not None and now - start_time > timeout:
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


@dataclass
class TestCatalog:
    tests: dict[str, TestEntry]
    groups: dict[str, list[str]]
    subgroups: dict[str, dict[str, list[str]]]

    @classmethod
    def load(cls) -> "TestCatalog":
        tests: dict[str, TestEntry] = {}
        for entry in discover_tests(ROOT):
            if entry.name in tests:
                raise ConfigurationError(
                    f"Duplicate test name in catalog: {entry.name}"
                )
            tests[entry.name] = entry

        return cls(
            tests=tests,
            groups=discover_groups(ROOT),
            subgroups=discover_subgroups(ROOT),
        )

    def all_tests(self) -> list[str]:
        return list(self.tests.keys())

    def require_test(self, test_name: str) -> TestEntry:
        if test_name not in self.tests:
            raise ConfigurationError(
                f"Unknown test '{test_name}'. Use -l to list available tests."
            )
        return self.tests[test_name]

    def resolve_group(self, group_name: str) -> tuple[list[str], list[str]]:
        members = self.groups.get(group_name)
        if members is None:
            for group_subgroups in self.subgroups.values():
                if group_name in group_subgroups:
                    members = group_subgroups[group_name]
                    break
        if members is None:
            available = ", ".join(self.groups)
            subgroup_names = ", ".join(
                subgroup_name
                for group_subgroups in self.subgroups.values()
                for subgroup_name in group_subgroups
            )
            raise ConfigurationError(
                f"Unknown test group '{group_name}'. Available groups: {available}. "
                f"Sub-groups: {subgroup_names}."
            )

        available_tests: list[str] = []
        missing_tests: list[str] = []
        for test_name in members:
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
        self.no_tracecomp = args.no_tracecomp
        self.no_spiketrace = args.no_spiketrace
        self.no_self_check = args.no_self_check
        self.dromajo_cosim = not args.no_cosim
        self.jobs = args.jobs
        # Upper bound used only for workspace prep; per-test trace logging is
        # resolved by _rtl_trace_enabled().
        self.tracecomp_possible = not (args.cosim_only or args.no_tracecomp)
        self.force_continue_after_trap = args.continue_after_trap
        self.cancel_event = threading.Event()
        self._result_lock = threading.Lock()
        self._suite_ran = 0
        self._suite_failed = 0
        # Per-test default flags (see COSIM_ONLY_TESTS / NO_TRACECOMP_TESTS)
        # apply in -g, -a, and the no-arg default run, but not single (-s).
        default_run = not any(
            (
                args.compile_all,
                args.compile_single is not None,
                args.compile_group is not None,
                args.list_tests,
                args.lint_module is not None,
                args.clean,
                args.prepare_for_commit,
            )
        )
        self.batch_mode = (
            args.compile_group is not None or args.compile_all or default_run
        )
        self.show_warnings = args.warnings
        self.default_block_width = DEFAULT_BLOCK_WIDTH
        self.default_set_count = DEFAULT_SET_COUNT
        self.default_associativity = DEFAULT_ASSOCIATIVITY

    def print_all_tests(self) -> None:
        groups = self.catalog.groups
        counts = {name: len(test_names) for name, test_names in groups.items()}
        total = sum(counts.values())

        terminal_width = shutil.get_terminal_size((80, 24)).columns
        rule_width = min(terminal_width, 72)

        print(f"Available tests: {total} total in {len(groups)} groups")

        for group_name, test_names in groups.items():
            print()
            print(f"{group_name}  ({counts[group_name]} tests)")
            print("─" * rule_width)
            subgroups = self.catalog.subgroups.get(group_name)
            if subgroups:
                # Each sub-group is runnable on its own via -g <subgroup_name>.
                for subgroup_name, subgroup_tests in subgroups.items():
                    print(f"· {subgroup_name}  ({len(subgroup_tests)} tests)")
                    for line in self._columnize(
                        subgroup_tests, terminal_width, indent=4
                    ):
                        print(line)
            else:
                for line in self._columnize(test_names, terminal_width):
                    print(line)

        print()
        print("Summary")
        print("─" * rule_width)
        self._print_group_summary(counts, total)

    @staticmethod
    def _columnize(
        items: Sequence[str], width: int, *, indent: int = 2, gap: int = 2
    ) -> list[str]:
        if not items:
            return []
        col_width = max(len(item) for item in items) + gap
        usable = max(width - indent, col_width)
        columns = max(1, usable // col_width)
        rows = -(-len(items) // columns)  # ceil division
        pad = " " * indent
        lines = []
        for row in range(rows):
            cells = [
                items[index].ljust(col_width)
                for column in range(columns)
                if (index := column * rows + row) < len(items)
            ]
            lines.append((pad + "".join(cells)).rstrip())
        return lines

    @staticmethod
    def _print_group_summary(counts: Mapping[str, int], total: int) -> None:
        name_width = max(*(len(name) for name in counts), len("Group"), len("Total"))
        count_width = max(
            *(len(str(count)) for count in counts.values()),
            len(str(total)),
            len("Tests"),
        )

        def row(label: str, value: str) -> str:
            return f"  {label.ljust(name_width)}  {value.rjust(count_width)}"

        separator = f"  {'─' * name_width}  {'─' * count_width}"
        print(row("Group", "Tests"))
        print(separator)
        for name, count in counts.items():
            print(row(name, str(count)))
        print(separator)
        print(row("Total", str(total)))

    def run_default(self, *, varying: bool = False) -> None:
        tests = list(DEFAULT_TESTS)
        missing = [
            test_name for test_name in tests if test_name not in self.catalog.tests
        ]
        if missing:
            missing_text = ", ".join(missing)
            raise ConfigurationError(
                f"Default test set references unavailable tests: {missing_text}"
            )

        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_tests(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            ),
            tests,
        )

    def run_single(self, test_name: str, *, varying: bool = False) -> None:
        tests = [test_name]
        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_tests(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            ),
            tests,
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
            lambda: self._run_tests(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            ),
            tests,
        )

    def run_all(self, *, varying: bool = False) -> None:
        tests = self.catalog.all_tests()
        if varying:
            self.run_varying_cache(tests)
            return

        self._run_suite(
            lambda: self._run_tests(
                tests,
                self.default_block_width,
                self.default_set_count,
                self.default_associativity,
            ),
            tests,
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
        # Associativity is held at the saved default (N=4); only BLOCK_WIDTH and
        # SET_COUNT are swept (see CACHE_SWEEP_* notes above).
        associativity = self.default_associativity

        def work() -> None:
            for block_width in CACHE_SWEEP_BLOCK_WIDTHS:
                for set_count in CACHE_SWEEP_SET_COUNTS:
                    self._run_tests(tests, block_width, set_count, associativity)

        self._run_suite(work, tests)

    def clean(self) -> None:
        self._remove_path(BUILD_DIR)
        for path in LEGACY_ARTIFACTS:
            self._remove_path(path)

    def prepare_for_commit(self) -> None:
        self.clean()
        self.command_runner.run(
            [
                "git",
                "restore",
                format_repo_path(RESULT_FILE),
            ],
            description="Restore tracked generated files",
        )

    def _run_suite(self, work: Callable[[], None], tests: list[str]) -> None:
        self._suite_ran = 0
        self._suite_failed = 0
        start_time = time.monotonic()
        try:
            self._prepare_workspace(tests)
            work()
            if self.coverage_mode is not None:
                self._finalize_coverage()
        finally:
            # Report even when failures propagate: the summary lands on stdout
            # right after the per-test output, before main() prints the details.
            self._print_suite_summary(time.monotonic() - start_time)

    def _print_suite_summary(self, elapsed_seconds: float) -> None:
        if self._suite_ran == 0:
            return
        passed = self._suite_ran - self._suite_failed
        counts = f"{passed}/{self._suite_ran} passed"
        if self._suite_failed:
            counts = f"{ANSI_RED}{counts}, {self._suite_failed} failed{ANSI_RESET}"
        else:
            counts = f"{ANSI_GREEN}{counts}{ANSI_RESET}"
        print(
            f"Summary: {counts} (elapsed {format_duration(elapsed_seconds)})",
            flush=True,
        )

    def _run_tests(
        self, tests: list[str], block_width: int, set_count: int, associativity: int
    ) -> None:
        self._append_cache_header(block_width, set_count, associativity)
        if self.jobs > 1 and len(tests) > 1:
            failures = self._run_tests_parallel(
                tests, block_width, set_count, associativity
            )
        else:
            failures = self._run_tests_serial(
                tests, block_width, set_count, associativity
            )

        self._suite_ran += len(tests)
        self._suite_failed += len(failures)

        if failures:
            raise TestFailure("\n\n".join(failures))

    def _run_tests_serial(
        self, tests: list[str], block_width: int, set_count: int, associativity: int
    ) -> list[str]:
        total = len(tests)
        failures: list[str] = []
        for index, test_name in enumerate(tests, start=1):
            console = TestConsole(buffered=False)
            try:
                self._run_single_test(
                    test_name,
                    block_width,
                    set_count,
                    associativity,
                    index,
                    total,
                    console,
                    self._record_test_outcome,
                )
            except TestFailure as exc:
                failures.append(f"{test_name}:\n{exc}")
        return failures

    def _run_tests_parallel(
        self, tests: list[str], block_width: int, set_count: int, associativity: int
    ) -> list[str]:
        total = len(tests)
        outcomes: dict[str, TestOutcome] = {}
        failure_texts: dict[str, str] = {}
        output_lock = threading.Lock()
        section_start = RESULT_FILE.stat().st_size

        def record_outcome(test_name: str, outcome: TestOutcome) -> None:
            # Rewrite this configuration's section of results/result.txt in
            # catalog order on every completion, so the file stays ordered and
            # current while tests finish out of order.
            with self._result_lock:
                outcomes[test_name] = outcome
                with RESULT_FILE.open("r+") as result_file:
                    result_file.seek(section_start)
                    result_file.truncate()
                    for name in tests:
                        if name in outcomes:
                            result_file.write(format_result_row(name, outcomes[name]))

        def run_one(index: int, test_name: str) -> tuple[str, str | None]:
            console = TestConsole(buffered=True)
            failure_text: str | None = None
            try:
                if not self.cancel_event.is_set():
                    self._run_single_test(
                        test_name,
                        block_width,
                        set_count,
                        associativity,
                        index,
                        total,
                        console,
                        record_outcome,
                    )
            except TestFailure as exc:
                failure_text = f"{test_name}:\n{exc}"
            finally:
                with output_lock:
                    console.flush()
            return test_name, failure_text

        executor = ThreadPoolExecutor(max_workers=self.jobs)
        try:
            futures = [
                executor.submit(run_one, index, test_name)
                for index, test_name in enumerate(tests, start=1)
            ]
            for future in as_completed(futures):
                test_name, failure_text = future.result()
                if failure_text is not None:
                    failure_texts[test_name] = failure_text
        except BaseException:
            # Infrastructure error or Ctrl-C: stop in-flight simulations and
            # drop queued tests before propagating.
            self.cancel_event.set()
            executor.shutdown(wait=True, cancel_futures=True)
            raise
        executor.shutdown(wait=True)

        return [failure_texts[name] for name in tests if name in failure_texts]

    def _run_single_test(
        self,
        test_name: str,
        block_width: int,
        set_count: int,
        associativity: int,
        index: int,
        total: int,
        console: TestConsole,
        record_outcome: Callable[[str, TestOutcome], None],
    ) -> None:
        entry = self.catalog.require_test(test_name)
        paths = self._paths_for(test_name)
        flag_notes = self._effective_flag_notes(test_name)
        flag_suffix = f" [flags: {' '.join(flag_notes)}]" if flag_notes else ""
        console.emit(
            f"[{index}/{total}] Running {test_name} "
            f"(BLOCK_WIDTH={block_width}, SET_COUNT={set_count}, ASSOCIATIVITY={associativity}-way)"
            f"{flag_suffix}"
        )

        try:
            self._build_simulator(test_name, entry, paths, block_width, set_count)

            trace_limit: TraceLimitExceeded | None = None
            try:
                self._run_simulation(test_name, entry, paths, console)
            except TraceLimitExceeded as exc:
                trace_limit = exc
                console.emit(f"  {exc}")

            skips_self_check = (
                self._cosim_only(test_name)
                or self._skips_self_check(test_name)
                or self.no_self_check
            )
            require_status = not skips_self_check and trace_limit is None
            parsed_output = self._parse_simulation_output(
                test_name, paths, require_status=require_status
            )

            if skips_self_check:
                self_check = "N/A"
                self_check_failed = False
            elif trace_limit is not None:
                # The simulation was killed at the log cap; the test fails via
                # the LOG-LIMIT outcome, so report whatever status made it out.
                self_check = parsed_output.status_text or "N/A"
                self_check_failed = False
            else:
                self_check = (
                    "Missing"
                    if parsed_output.status_missing
                    else (parsed_output.status_text or "Unknown")
                )
                self_check_failed = not self._self_check_passed(
                    parsed_output.status_text
                )

            trace_preview = ""
            if trace_limit is not None:
                tracecomp_status = "LOG-LIMIT"
            elif not self._rtl_trace_enabled(test_name):
                tracecomp_status = "Skipped"
            elif not self._spike_compare_enabled(test_name):
                tracecomp_status = "N/A"
            else:
                self._run_trace_reference(test_name, entry, paths)
                tracecomp_status, trace_preview = self._compare_traces(test_name, paths)

            outcome = TestOutcome(self_check=self_check, tracecomp=tracecomp_status)
            record_outcome(test_name, outcome)

            failures = []
            if trace_limit is not None:
                failures.append(
                    f"RTL log for {test_name} exceeded the {trace_limit.limit}-byte "
                    f"cap and the simulation was stopped. "
                    f"See {format_repo_path(trace_limit.path)}."
                )
            if self_check_failed:
                if parsed_output.status_missing:
                    failures.append(
                        f"Self Check missing for {test_name}. See {format_repo_path(paths.res_file)}."
                    )
                else:
                    failures.append(
                        f"Self Check failed for {test_name}: {self_check}. See {format_repo_path(paths.res_file)}."
                    )
            if tracecomp_status == "FAIL":
                failures.append(
                    f"Tracecomp failed for {test_name}. Diff preview:\n{trace_preview}"
                )
            console.emit(
                colorize_status_text(
                    f"  Self Check: {outcome.self_check}; Tracecomp: {outcome.tracecomp}"
                )
            )
            if failures:
                raise TestFailure("\n".join(failures))

            if self.coverage_mode is not None:
                self._stash_coverage_file(
                    test_name, paths, block_width, set_count, associativity
                )
        except BaseException:
            # Keep the per-test build for post-mortem on any failure; it is
            # rebuilt from scratch on the next run and removed by -c.
            raise
        else:
            self._clean_test_artifacts(paths)

    def _prepare_workspace(self, tests: list[str]) -> None:
        BUILD_DIR.mkdir(parents=True, exist_ok=True)
        if self.tracecomp_possible:
            LOG_TRACE_DIR.mkdir(parents=True, exist_ok=True)
            SPIKE_LOG_TRACE_DIR.mkdir(parents=True, exist_ok=True)
        if self.args.trace:
            WAVEFORM_DIR.mkdir(parents=True, exist_ok=True)

        RESULT_FILE.parent.mkdir(parents=True, exist_ok=True)
        RESULT_FILE.write_text("")

        if self.coverage_mode is not None:
            self._remove_path(COV_DIR)
            self._remove_path(COVERAGE_OUT_DIR)
            COV_DIR.mkdir(parents=True, exist_ok=True)

        self._prepare_test_inputs(tests)

    def _prepare_test_inputs(self, tests: list[str]) -> None:
        """Generate disassembly and memory images for the selected tests only.

        Outputs are cached in build/: a file is regenerated only when it is
        missing or older than its source (ELF -> dis-asm -> instr)."""
        generated = 0
        cached = 0
        for test_name in tests:
            entry = self.catalog.require_test(test_name)
            elf_path = ROOT / entry.elf_path
            if not elf_path.exists():
                raise ConfigurationError(
                    f"Expected ELF file not found: {format_repo_path(elf_path)}"
                )
            disasm_path = ROOT / entry.disasm_path
            instr_path = ROOT / entry.instr_path

            regenerated = False
            if self._is_stale(disasm_path, elf_path):
                try:
                    elf2disasm.disassemble(elf_path, disasm_path)
                except (OSError, subprocess.CalledProcessError) as exc:
                    raise CommandError(
                        f"Generate disassembly for {test_name}",
                        [elf2disasm.OBJDUMP, str(elf_path)],
                        str(exc),
                    ) from exc
                regenerated = True
            if regenerated or self._is_stale(instr_path, disasm_path):
                instr_path.parent.mkdir(parents=True, exist_ok=True)
                disasm2mem.process_file(str(disasm_path), str(instr_path))
                if not instr_path.exists():
                    raise ConfigurationError(
                        f"Failed to generate memory image {format_repo_path(instr_path)}."
                    )
                regenerated = True

            if regenerated:
                generated += 1
            else:
                cached += 1

        print(f"Test inputs: {generated} generated, {cached} cached.")

    @staticmethod
    def _is_stale(output_path: Path, source_path: Path) -> bool:
        if not output_path.exists():
            return True
        return output_path.stat().st_mtime < source_path.stat().st_mtime

    def _build_simulator(
        self,
        test_name: str,
        entry: TestEntry,
        paths: TestPaths,
        block_width: int,
        set_count: int,
    ) -> None:
        dromajo_cosim_enabled = self._dromajo_cosim_enabled(test_name)
        rtl_trace_enabled = self._rtl_trace_enabled(test_name)
        c_defines = (
            ["-DMAVERIC_CONTINUE_AFTER_TRAP"]
            if self._continues_after_trap(test_name)
            else []
        )

        self._remove_path(paths.obj_dir)
        # Verilator creates only the final component of --Mdir itself.
        paths.obj_dir.parent.mkdir(parents=True, exist_ok=True)

        verilator_command = [
            "verilator",
            "--assert",
            "-I./rtl",
            "--Wall",
            "-Wno-fatal",
            "--Mdir",
            format_repo_path(paths.obj_dir),
            "--cc",
            format_repo_path(ROOT / "rtl/test_env.sv"),
            # Per-test configuration is passed to the build instead of editing
            # the RTL sources in place, so concurrent builds cannot conflict.
            f"-GBLOCK_WIDTH={block_width}",
            f"+define+MAVERIC_DCACHE_SET_COUNT={set_count}",
            f'+define+PATH_TO_MEM="{(ROOT / entry.instr_path).as_posix()}"',
        ]
        if self.coverage_mode == "all":
            verilator_command.append("--coverage")
        elif self.coverage_mode == "line":
            verilator_command.append("--coverage-line")
        elif self.coverage_mode == "toggle":
            verilator_command.append("--coverage-toggle")
        if self.args.trace:
            verilator_command.extend(["--trace-fst", "--trace-structs"])
        if self._continues_after_trap(test_name):
            verilator_command.append("-DMAVERIC_CONTINUE_AFTER_TRAP")
        if self._self_loop_continues(test_name):
            verilator_command.append("-DMAVERIC_SELF_LOOP_CONTINUE")
        if dromajo_cosim_enabled:
            verilator_command.append("-DDROMAJO_COSIM")
        if not rtl_trace_enabled:
            verilator_command.append("-DNO_TRACECOMP")

        verilator_sources = [
            format_repo_path(ROOT / "test/tb/tb_test_env.cpp"),
            format_repo_path(ROOT / "test/tb/check.c"),
            format_repo_path(ROOT / "test/tb/pmem_write.c"),
        ]
        if rtl_trace_enabled:
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
            [
                "make",
                "-C",
                format_repo_path(paths.obj_dir),
                "-f",
                "Vtest_env.mk",
                f"-j{self._make_jobs()}",
            ],
            description="Build generated simulator",
        )

    def _make_jobs(self) -> int:
        # Split the cores between concurrent test builds so `-j N` test-level
        # parallelism does not oversubscribe the machine.
        return max(1, (os.cpu_count() or 1) // max(1, self.jobs))

    def _run_simulation(
        self,
        test_name: str,
        entry: TestEntry,
        paths: TestPaths,
        console: TestConsole,
    ) -> None:
        paths.run_dir.mkdir(parents=True, exist_ok=True)
        self._remove_path(paths.res_file)
        paths.pmem_write_file.parent.mkdir(parents=True, exist_ok=True)
        paths.pmem_write_file.write_bytes(b"")

        simulation_env = {"MAVERIC_PMEM_WRITE_FILE": str(paths.pmem_write_file)}
        progress_paths: list[Path] = []
        size_limits: list[tuple[Path, int]] = []

        if self._rtl_trace_enabled(test_name):
            paths.rtl_trace_file.parent.mkdir(parents=True, exist_ok=True)
            paths.rtl_trace_file.write_text("")
            simulation_env["MAVERIC_RTL_TRACE_FILE"] = str(paths.rtl_trace_file)
            progress_paths.append(paths.rtl_trace_file)
            size_limits.append((paths.rtl_trace_file, TRACE_MAX_BYTES))
        progress_paths.append(paths.pmem_write_file)
        size_limits.append((paths.pmem_write_file, TRACE_MAX_BYTES))

        if self.args.trace:
            paths.waveform_file.parent.mkdir(parents=True, exist_ok=True)
            simulation_env["MAVERIC_WAVEFORM_FILE"] = str(paths.waveform_file)
        if self.coverage_mode is not None:
            simulation_env["MAVERIC_COVERAGE_FILE"] = str(paths.coverage_file)
        # SELF_LOOP_CONTINUE tests wait on a self-loop for interrupts and end by
        # running out the (reduced) clock; xv6 tests boot a kernel and get a far
        # larger budget; everything else stops at a trap or retired self-loop
        # long before the default budget.
        simulation_env["MAVERIC_MAX_SIM_TIME"] = str(
            self._max_sim_time(test_name, entry)
        )

        # Benchmark and xv6 tests are long-running and emit output in bursts;
        # let them run unbounded and rely on the self-loop stop / trap / log cap
        # / MAVERIC_MAX_SIM_TIME to end the run.
        unbounded = self._is_unbounded(entry)
        simulation_timeout = None if unbounded else SIMULATION_TIMEOUT_SECONDS
        idle_timeout = (
            None
            if unbounded or self._continues_after_trap(test_name)
            else SIMULATION_IDLE_TIMEOUT_SECONDS
        )

        pmem_streamer = (
            None if console.buffered else PmemWriteStreamer(paths.pmem_write_file)
        )
        try:
            self.command_runner.run_streaming_to_file(
                [str(paths.sim_binary), str(ROOT / entry.elf_path)],
                description=f"Run RTL simulation for {test_name}",
                output_path=paths.res_file,
                timeout=simulation_timeout,
                idle_timeout=idle_timeout,
                env=simulation_env,
                progress_paths=progress_paths,
                size_limits=size_limits,
                poll_callback=pmem_streamer.pump if pmem_streamer is not None else None,
                cancel_event=self.cancel_event,
            )
        finally:
            if pmem_streamer is not None:
                pmem_streamer.finalize()
            else:
                self._emit_pmem_output(console, paths.pmem_write_file)

    @staticmethod
    def _emit_pmem_output(console: TestConsole, pmem_path: Path) -> None:
        try:
            data = pmem_path.read_bytes()
        except FileNotFoundError:
            return
        if not data:
            return
        console.emit(PmemWriteStreamer.HEADER)
        for line in data.decode("utf-8", errors="replace").splitlines():
            console.emit(f"{PmemWriteStreamer.INDENT}{line}")

    def _run_trace_reference(
        self, test_name: str, entry: TestEntry, paths: TestPaths
    ) -> None:
        self._remove_path(paths.spike_trace_file)
        self._remove_path(paths.spike_original_file)
        paths.run_dir.mkdir(parents=True, exist_ok=True)
        tracecomp_command = [
            sys.executable,
            format_repo_path(SCRIPT_TRACECOMP),
            test_name,
            str(ROOT / entry.elf_path),
            "--out-dir",
            str(SPIKE_LOG_TRACE_DIR),
            "--scratch-log",
            str(paths.spike_scratch_log),
        ]
        # Keep the Spike trace's stop point aligned with the RTL simulation: when
        # the run continues past ebreak/ecall (either from -C or the per-test
        # default), tracecomp must continue too.
        if self._continues_after_trap(test_name):
            tracecomp_command.append("--continue-after-trap")
        # tracecomp enforces the trace timeout itself so it can kill Spike and
        # still write the partial trace logs; the outer timeout stays as a
        # backstop with headroom for parsing what Spike produced.
        if self._is_unbounded(entry):
            outer_timeout = None
        else:
            tracecomp_command.extend(["--timeout", str(TRACE_TIMEOUT_SECONDS)])
            outer_timeout = TRACE_TIMEOUT_SECONDS + 60
        self.command_runner.run(
            tracecomp_command,
            description=f"Generate Spike trace for {test_name}",
            timeout=outer_timeout,
        )

    def _parse_simulation_output(
        self, test_name: str, paths: TestPaths, *, require_status: bool = True
    ) -> ParsedSimulationOutput:
        if not paths.res_file.exists():
            raise SimulationOutputError(
                f"Simulation output file {format_repo_path(paths.res_file)} was not created for {test_name}."
            )

        match = STATUS_COLOR_RE.search(paths.res_file.read_text())
        if match is not None:
            return ParsedSimulationOutput(status_text=match.group(1))

        if self._skips_self_check(test_name) or not require_status:
            return ParsedSimulationOutput(status_text=None)

        return ParsedSimulationOutput(status_text=None, status_missing=True)

    @staticmethod
    def _paths_for(test_name: str) -> TestPaths:
        obj_dir = BUILD_OBJ_DIR / test_name
        run_dir = BUILD_RUN_DIR / test_name
        return TestPaths(
            obj_dir=obj_dir,
            sim_binary=obj_dir / "Vtest_env",
            run_dir=run_dir,
            res_file=run_dir / "res.txt",
            trace_diff_file=run_dir / "tracediff.txt",
            spike_scratch_log=run_dir / "spike-raw.log",
            coverage_file=run_dir / "coverage.dat",
            rtl_trace_file=LOG_TRACE_DIR / f"{test_name}-log-trace.log",
            spike_trace_file=SPIKE_LOG_TRACE_DIR / f"{test_name}-log-trace.log",
            spike_original_file=SPIKE_LOG_TRACE_DIR / f"{test_name}-spike-original.log",
            pmem_write_file=PMEM_WRITE_DIR / f"{test_name}-pmem-write.log",
            waveform_file=WAVEFORM_DIR / f"{test_name}_waveform.fst",
        )

    def _compare_traces(self, test_name: str, paths: TestPaths) -> tuple[str, str]:
        rtl_trace_file = paths.rtl_trace_file
        spike_trace_file = paths.spike_trace_file

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

        if not spike_lines:
            self._remove_path(paths.trace_diff_file)
            return "N/A", ""

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
            self._remove_path(paths.trace_diff_file)
            return "PASS", ""

        preview = "".join(diff_preview_lines).strip()
        paths.trace_diff_file.parent.mkdir(parents=True, exist_ok=True)
        paths.trace_diff_file.write_text(preview + "\n")
        return "FAIL", preview

    def _record_test_outcome(self, test_name: str, outcome: TestOutcome) -> None:
        with self._result_lock:
            with RESULT_FILE.open("a") as result_file:
                result_file.write(format_result_row(test_name, outcome))

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
        self,
        test_name: str,
        paths: TestPaths,
        block_width: int,
        set_count: int,
        associativity: int,
    ) -> None:
        if not paths.coverage_file.exists():
            raise SimulationOutputError(
                f"Coverage was requested, but {format_repo_path(paths.coverage_file)} was not produced for {test_name}."
            )

        destination = (
            COV_DIR
            / f"coverage_{test_name}_{block_width}_{set_count}_{associativity}.dat"
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        paths.coverage_file.replace(destination)

    def _finalize_coverage(self) -> None:
        coverage_inputs = sorted(COV_DIR.glob("*.dat"))
        if not coverage_inputs:
            raise SimulationOutputError(
                f"No per-test coverage files were produced in {format_repo_path(COV_DIR)}."
            )

        COVERAGE_OUT_DIR.mkdir(parents=True, exist_ok=True)
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

    @staticmethod
    def _remove_path(path: Path) -> None:
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)

    def _clean_test_artifacts(self, paths: TestPaths) -> None:
        # The per-test Verilator build is ~150 MB; drop it as soon as the test
        # is done. Run outputs (res.txt, traces, diffs) stay for inspection and
        # are removed by -c.
        self._remove_path(paths.obj_dir)

    @staticmethod
    def _is_snippy(test_name: str) -> bool:
        return test_name.startswith("snippy-")

    @staticmethod
    def _is_benchmark(test_name: str) -> bool:
        return test_name.startswith("benchmark-")

    @staticmethod
    def _is_unbounded(entry: TestEntry) -> bool:
        return TestRunner._is_benchmark(entry.name) or entry.group == "xv6"

    @staticmethod
    def _no_self_check(test_name: str) -> bool:
        return test_name in COSIM_ONLY_TESTS

    @staticmethod
    def _skips_self_check(test_name: str) -> bool:
        return (
            TestRunner._is_snippy(test_name)
            or TestRunner._is_benchmark(test_name)
            or TestRunner._no_self_check(test_name)
        )

    def _continues_after_trap(self, test_name: str) -> bool:
        return self.force_continue_after_trap or test_name in TRAP_CONTINUATION_TESTS

    @staticmethod
    def _self_loop_continues(test_name: str) -> bool:
        return test_name in SELF_LOOP_CONTINUE_TESTS

    def _max_sim_time(self, test_name: str, entry: TestEntry) -> int:
        if self._self_loop_continues(test_name):
            return SELF_LOOP_CONTINUE_SIM_TIME
        if entry.group == "xv6":
            return XV6_MAX_SIM_TIME
        return DEFAULT_MAX_SIM_TIME

    def _dromajo_cosim_enabled(self, test_name: str) -> bool:
        return self.dromajo_cosim

    def _cosim_only(self, test_name: str) -> bool:
        return self.cosim_only or (self.batch_mode and test_name in COSIM_ONLY_TESTS)

    def _rtl_trace_enabled(self, test_name: str) -> bool:
        if self._cosim_only(test_name) or self.no_tracecomp:
            return False
        return not (self.batch_mode and test_name in NO_TRACECOMP_TESTS)

    def _spike_compare_enabled(self, test_name: str) -> bool:
        return self._rtl_trace_enabled(test_name) and not self.no_spiketrace

    def _effective_flag_notes(self, test_name: str) -> list[str]:
        # Effective per-test state of the important modifier flags, whether set
        # on the CLI or coming from a per-test (batch) default.
        flags = []
        if not self._dromajo_cosim_enabled(test_name):
            flags.append("--no-cosim")
        if not self._rtl_trace_enabled(test_name):
            flags.append("--no-tracecomp")
        elif not self._spike_compare_enabled(test_name):
            flags.append("--no-spiketrace")
        if self._continues_after_trap(test_name):
            flags.append("-C")
        return flags

    @staticmethod
    def _self_check_passed(status_text: str | None) -> bool:
        return status_text is not None and "pass" in status_text.lower()

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


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=HELP_MSG_SCRIPT_DESCRIPTION,
        epilog=(
            "Default tests: "
            + ", ".join(DEFAULT_TESTS)
            + ". Run artifacts are written under build/."
            + " PMEM writes are printed for inspection and are not used as pass/fail criteria."
        ),
    )
    operations = parser.add_mutually_exclusive_group()
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
        "-j",
        "--jobs",
        type=int,
        default=1,
        metavar="N",
        help=HELP_MSG_JOBS_DESCRIPTION,
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
        "--no-spiketrace",
        action="store_true",
        help=HELP_MSG_NO_SPIKETRACE_DESCRIPTION,
    )
    parser.add_argument(
        "--no-self-check",
        action="store_true",
        help=HELP_MSG_NO_SELF_CHECK_DESCRIPTION,
    )
    parser.add_argument(
        "-C",
        "--continue-after-trap",
        action="store_true",
        help=HELP_MSG_CONTINUE_AFTER_TRAP_DESCRIPTION,
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
    explicit_test_run = any(
        (
            args.compile_all,
            args.compile_single is not None,
            args.compile_group is not None,
        )
    )
    operation_selected = any(
        (
            explicit_test_run,
            args.list_tests,
            args.lint_module is not None,
            args.clean,
            args.prepare_for_commit,
        )
    )
    is_test_run = explicit_test_run or not operation_selected
    coverage_requested = TestRunner._resolve_coverage_mode_from_args(args) is not None

    if args.compile_varying_cache and not is_test_run:
        raise ConfigurationError("--compile-varying-cache (-v) requires a test run.")
    if args.trace and not is_test_run:
        raise ConfigurationError(
            "--trace can only be used with a test-running command."
        )
    if args.jobs < 1:
        raise ConfigurationError("--jobs (-j) must be at least 1.")
    if args.jobs > 1 and not is_test_run:
        raise ConfigurationError(
            "--jobs (-j) can only be used with a test-running command."
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
    if args.no_spiketrace and not is_test_run:
        raise ConfigurationError(
            "--no-spiketrace can only be used with a test-running command."
        )
    if args.no_self_check and not is_test_run:
        raise ConfigurationError(
            "--no-self-check can only be used with a test-running command."
        )
    if args.continue_after_trap and not is_test_run:
        raise ConfigurationError(
            "--continue-after-trap can only be used with a test-running command."
        )
    if args.cosim_only and args.no_cosim:
        raise ConfigurationError(
            "--cosim-only requires Dromajo co-simulation; remove --no-cosim."
        )
    if args.no_spiketrace and args.no_tracecomp:
        raise ConfigurationError(
            "--no-spiketrace keeps RTL trace logging; remove --no-tracecomp."
        )
    if args.no_spiketrace and args.cosim_only:
        raise ConfigurationError(
            "--cosim-only already disables trace logging; remove --no-spiketrace."
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
            runner.run_default(varying=args.compile_varying_cache)
    except RunTestsError as exc:
        print(colorize_status_text(f"Error: {exc}"), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
