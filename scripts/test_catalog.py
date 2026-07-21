from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BIN_ROOT = Path("test/tests/bin")
DISASM_ROOT = Path("build/dis-asm")
INSTR_ROOT = Path("build/instr")

GROUP_TESTS = {
    "am": """
        am-add-longlong am-add am-bit am-bubble-sort am-crc32 am-div am-dummy
        am-fact am-fib am-goldbach am-hello-str am-hello-str-print am-if-else am-leap-year
        am-load-store am-matrix-mul am-max am-mersenne am-min3 am-mov-c
        am-movsx am-mul-longlong am-pascal am-prime am-quick-sort
        am-recursion am-select-sort am-shift am-shuixianhua am-string
        am-sub-longlong am-sum am-switch am-to-lower-case am-unalign am-wanshu am-yield-os
    """.split(),
    "rv-arch-test": """
        rv-arch-test-add rv-arch-test-addi rv-arch-test-addiw
        rv-arch-test-addw rv-arch-test-and rv-arch-test-andi
        rv-arch-test-auipc rv-arch-test-beq rv-arch-test-bge
        rv-arch-test-bgeu rv-arch-test-blt rv-arch-test-bltu
        rv-arch-test-bne rv-arch-test-div rv-arch-test-divu
        rv-arch-test-divuw rv-arch-test-divw
        rv-arch-test-fence rv-arch-test-fencei rv-arch-test-jal rv-arch-test-jalr
        rv-arch-test-lb-align rv-arch-test-lbu-align rv-arch-test-ld-align
        rv-arch-test-lh-align rv-arch-test-lhu-align rv-arch-test-lui
        rv-arch-test-lw-align rv-arch-test-lwu-align
        rv-arch-test-misalign1-jalr rv-arch-test-mul rv-arch-test-mulh
        rv-arch-test-mulhsu rv-arch-test-mulhu rv-arch-test-mulw
        rv-arch-test-or rv-arch-test-ori rv-arch-test-rem rv-arch-test-remu
        rv-arch-test-remuw rv-arch-test-remw rv-arch-test-sb-align
        rv-arch-test-sd-align rv-arch-test-sh-align rv-arch-test-sll
        rv-arch-test-slli rv-arch-test-slliw rv-arch-test-sllw
        rv-arch-test-slt rv-arch-test-slti rv-arch-test-sltiu
        rv-arch-test-sltu rv-arch-test-sra rv-arch-test-srai
        rv-arch-test-sraiw rv-arch-test-sraw rv-arch-test-srl
        rv-arch-test-srli rv-arch-test-srliw rv-arch-test-srlw
        rv-arch-test-sub rv-arch-test-subw rv-arch-test-sw-align
        rv-arch-test-xor rv-arch-test-xori
        rv-arch-test-amoadd.d rv-arch-test-amoadd.w
        rv-arch-test-amoand.d rv-arch-test-amoand.w
        rv-arch-test-amomax.d rv-arch-test-amomax.w
        rv-arch-test-amomaxu.d rv-arch-test-amomaxu.w
        rv-arch-test-amomin.d rv-arch-test-amomin.w
        rv-arch-test-amominu.d rv-arch-test-amominu.w
        rv-arch-test-amoor.d rv-arch-test-amoor.w
        rv-arch-test-amoswap.d rv-arch-test-amoswap.w
        rv-arch-test-amoxor.d rv-arch-test-amoxor.w
    """.split(),
    "rv-tests-p": """
        rv-tests-p-add rv-tests-p-addi rv-tests-p-addiw rv-tests-p-addw
        rv-tests-p-and rv-tests-p-andi rv-tests-p-auipc
        rv-tests-p-beq rv-tests-p-bge rv-tests-p-bgeu rv-tests-p-blt rv-tests-p-bltu rv-tests-p-bne
        rv-tests-p-fence_i rv-tests-p-jal rv-tests-p-jalr
        rv-tests-p-lb rv-tests-p-lbu rv-tests-p-ld rv-tests-p-ld_st rv-tests-p-lh
        rv-tests-p-lhu rv-tests-p-lui rv-tests-p-lw rv-tests-p-lwu
        rv-tests-p-or rv-tests-p-ori rv-tests-p-sb rv-tests-p-sd rv-tests-p-sh rv-tests-p-simple
        rv-tests-p-sll rv-tests-p-slli rv-tests-p-slliw rv-tests-p-sllw
        rv-tests-p-slt rv-tests-p-slti rv-tests-p-sltiu rv-tests-p-sltu
        rv-tests-p-sra rv-tests-p-srai rv-tests-p-sraiw rv-tests-p-sraw
        rv-tests-p-srl rv-tests-p-srli rv-tests-p-srliw rv-tests-p-srlw
        rv-tests-p-st_ld rv-tests-p-sub rv-tests-p-subw rv-tests-p-sw
        rv-tests-p-xor rv-tests-p-xori
        rv-tests-p-div rv-tests-p-divu rv-tests-p-divuw rv-tests-p-divw
        rv-tests-p-mul rv-tests-p-mulh rv-tests-p-mulhsu rv-tests-p-mulhu rv-tests-p-mulw
        rv-tests-p-rem rv-tests-p-remu rv-tests-p-remuw rv-tests-p-remw
        rv-tests-p-amoadd_d rv-tests-p-amoadd_w rv-tests-p-amoand_d rv-tests-p-amoand_w
        rv-tests-p-amomax_d rv-tests-p-amomax_w rv-tests-p-amomaxu_d rv-tests-p-amomaxu_w
        rv-tests-p-amomin_d rv-tests-p-amomin_w rv-tests-p-amominu_d rv-tests-p-amominu_w
        rv-tests-p-amoor_d rv-tests-p-amoor_w rv-tests-p-amoswap_d rv-tests-p-amoswap_w
        rv-tests-p-amoxor_d rv-tests-p-amoxor_w rv-tests-p-lrsc
        rv-tests-p-instret_overflow
        rv-tests-p-ld-misaligned rv-tests-p-lh-misaligned rv-tests-p-lw-misaligned
        rv-tests-p-ma_addr rv-tests-p-sbreak rv-tests-p-scall
        rv-tests-p-sd-misaligned rv-tests-p-sh-misaligned rv-tests-p-sw-misaligned rv-tests-p-zicntr
        rv-tests-p-s-csr rv-tests-p-s-dirty rv-tests-p-s-icache-alias rv-tests-p-s-sbreak rv-tests-p-s-scall
    """.split(),
    "rv-tests-v": """
        rv-tests-v-add rv-tests-v-addi rv-tests-v-addiw rv-tests-v-addw
        rv-tests-v-and rv-tests-v-andi rv-tests-v-auipc
        rv-tests-v-beq rv-tests-v-bge rv-tests-v-bgeu rv-tests-v-blt rv-tests-v-bltu rv-tests-v-bne
        rv-tests-v-fence_i rv-tests-v-jal rv-tests-v-jalr
        rv-tests-v-lb rv-tests-v-lbu rv-tests-v-ld rv-tests-v-ld_st rv-tests-v-lh
        rv-tests-v-lhu rv-tests-v-lui rv-tests-v-lw rv-tests-v-lwu
        rv-tests-v-or rv-tests-v-ori rv-tests-v-sb rv-tests-v-sd rv-tests-v-sh rv-tests-v-simple
        rv-tests-v-sll rv-tests-v-slli rv-tests-v-slliw rv-tests-v-sllw
        rv-tests-v-slt rv-tests-v-slti rv-tests-v-sltiu rv-tests-v-sltu
        rv-tests-v-sra rv-tests-v-srai rv-tests-v-sraiw rv-tests-v-sraw
        rv-tests-v-srl rv-tests-v-srli rv-tests-v-srliw rv-tests-v-srlw
        rv-tests-v-st_ld rv-tests-v-sub rv-tests-v-subw rv-tests-v-sw
        rv-tests-v-xor rv-tests-v-xori
        rv-tests-v-div rv-tests-v-divu rv-tests-v-divuw rv-tests-v-divw
        rv-tests-v-mul rv-tests-v-mulh rv-tests-v-mulhsu rv-tests-v-mulhu rv-tests-v-mulw
        rv-tests-v-rem rv-tests-v-remu rv-tests-v-remuw rv-tests-v-remw
        rv-tests-v-amoadd_d rv-tests-v-amoadd_w rv-tests-v-amoand_d rv-tests-v-amoand_w
        rv-tests-v-amomax_d rv-tests-v-amomax_w rv-tests-v-amomaxu_d rv-tests-v-amomaxu_w
        rv-tests-v-amomin_d rv-tests-v-amomin_w rv-tests-v-amominu_d rv-tests-v-amominu_w
        rv-tests-v-amoor_d rv-tests-v-amoor_w rv-tests-v-amoswap_d rv-tests-v-amoswap_w
        rv-tests-v-amoxor_d rv-tests-v-amoxor_w rv-tests-v-lrsc
    """.split(),
    "snippy": """
        snippy-add snippy-addi snippy-addiw snippy-addw snippy-and
        snippy-andi snippy-auipc snippy-beq snippy-bge snippy-bgeu
        snippy-blt snippy-bltu snippy-bne snippy-div snippy-divu
        snippy-divuw snippy-divw snippy-jal snippy-jalr snippy-lb
        snippy-lbu snippy-ld snippy-lh snippy-lhu snippy-load-store
        snippy-lui snippy-lw snippy-lwu snippy-mul snippy-mulh
        snippy-mulhsu snippy-mulhu snippy-mulw snippy-or snippy-ori
        snippy-rem snippy-remu snippy-remuw snippy-remw snippy-sb
        snippy-sd snippy-sh snippy-simple snippy-sll snippy-slli
        snippy-slliw snippy-sllw snippy-slt snippy-slti snippy-sltiu
        snippy-sltu snippy-sra snippy-srai snippy-sraiw snippy-sraw
        snippy-srl snippy-srli snippy-srliw snippy-srlw snippy-sub
        snippy-subw snippy-sw snippy-xor snippy-xori
    """.split(),
    "custom": """
        custom-csr-test custom-ebreak-mret custom-csr-test-2
        custom-clint-msi-test custom-clint-mti-test custom-clint-msi-mti
        custom-clint-mti-irq-regwrite custom-rtthread custom-satp_switch
    """.split(),
    "xv6": """
        xv6-forktest xv6-stressfs xv6-zombie
        xv6-usertests-argptest xv6-usertests-bigargtest xv6-usertests-bigfile
        xv6-usertests-bigwrite xv6-usertests-bsstest xv6-usertests-concreate
        xv6-usertests-copyin xv6-usertests-copyinstr1 xv6-usertests-copyinstr2
        xv6-usertests-copyinstr3 xv6-usertests-copyout
        xv6-usertests-createdeleteshort xv6-usertests-createtest
        xv6-usertests-dirfile xv6-usertests-dirtest xv6-usertests-exectest
        xv6-usertests-exitiput xv6-usertests-exitwait xv6-usertests-forkforkfork
        xv6-usertests-fourfiles xv6-usertests-fourteen xv6-usertests-iput
        xv6-usertests-iref xv6-usertests-kernmem xv6-usertests-killstatus
        xv6-usertests-lazy_copy xv6-usertests-lazy_sbrk xv6-usertests-lazy_unmap
        xv6-usertests-linktest xv6-usertests-linkunlink xv6-usertests-MAXVAplus
        xv6-usertests-mem xv6-usertests-nowrite xv6-usertests-openiput
        xv6-usertests-opentest xv6-usertests-pgbug xv6-usertests-pipe1
        xv6-usertests-preempt xv6-usertests-reparent xv6-usertests-rmdot
        xv6-usertests-rwsbrk xv6-usertests-sbrk8000 xv6-usertests-sbrkarg
        xv6-usertests-sbrkbasic xv6-usertests-sbrkbugs xv6-usertests-sbrkfail
        xv6-usertests-sbrklast xv6-usertests-sharedfd xv6-usertests-stacktest
        xv6-usertests-subdir xv6-usertests-truncate1 xv6-usertests-truncate2
        xv6-usertests-truncate3 xv6-usertests-unlinkread
        xv6-usertests-validatetest xv6-usertests-writebig xv6-usertests-writetest
    """.split(),
}

# rv-tests-p-csr rv-tests-p-illegal rv-tests-p-ma_fetch rv-tests-p-mcsr rv-tests-p-pmpaddr
# xv6-kernel-full xv6-kernel-timerless xv6-kernel-timer-only

GROUP_NAMES = tuple(GROUP_TESTS)

ALL_TEST_ORDER = (
    *GROUP_TESTS["am"],
    *GROUP_TESTS["rv-arch-test"],
    *GROUP_TESTS["rv-tests-p"],
    *GROUP_TESTS["rv-tests-v"],
    *GROUP_TESTS["snippy"],
    *GROUP_TESTS["custom"],
    *GROUP_TESTS["xv6"],
)

TEST_BINARY_DIRS = (
    "am-kernels",
    "riscv-arch-test",
    "riscv-tests",
    "snippy",
    "custom",
    "xv6",
)

GROUP_BIN_DIRS = {
    "am": "am-kernels",
    "rv-arch-test": "riscv-arch-test",
    "rv-tests-p": "riscv-tests",
    "rv-tests-v": "riscv-tests",
    "snippy": "snippy",
    "custom": "custom",
    "xv6": "xv6",
}

CUSTOM_TRAP_CONTINUATION_EXCLUSIONS = frozenset({"custom-csr-test"})

# Batch-run defaults: Dromajo cosim is the sole check (no self-check, no
# tracecomp, no Spike trace).
COSIM_ONLY_TESTS = frozenset(
    {
        "am-yield-os",
        "custom-clint-msi-test",
        "custom-clint-mti-test",
        "custom-clint-mti-irq-regwrite",
        "custom-rtthread",
    }
)

# Batch-run defaults: skip RTL trace logging / Spike tracecomp (cosim +
# self-check still run). Cosim-only tests skip tracecomp implicitly. The whole
# xv6 group is folded in by no_tracecomp_tests().
NO_TRACECOMP_TESTS = frozenset(
    {
        "custom-csr-test-2",
        "custom-clint-msi-mti",
    }
)

# Continue-after-trap tests not covered by custom_trap_continuation_tests() or
# the break/call name rule in break_call_tests().
EXTRA_TRAP_CONTINUATION_TESTS = frozenset({"am-yield-os"})

# Tests that spin on the self-loop instruction (jal x0, 0 == 0x0000006f) as an
# interrupt WAIT loop rather than a terminal halt loop. The simulation normally
# finishes at a retired self-loop (see check_self_loop); these tests must keep
# running so the pending interrupt can be serviced, and instead terminate via
# the reduced MAVERIC_MAX_SIM_TIME budget set by run_tests.py.
SELF_LOOP_CONTINUE_TESTS = frozenset(
    {
        "custom-clint-msi-test",
        "custom-clint-mti-test",
        "custom-clint-msi-mti",
        "custom-clint-mti-irq-regwrite",
        "custom-rtthread",
    }
)

RV_TESTS_M_EXTENSION = {
    "div",
    "divu",
    "divuw",
    "divw",
    "mul",
    "mulh",
    "mulhsu",
    "mulhu",
    "mulw",
    "rem",
    "remu",
    "remuw",
    "remw",
}

RV_TESTS_A_EXTENSION = {
    "amoadd_d",
    "amoadd_w",
    "amoand_d",
    "amoand_w",
    "amomax_d",
    "amomax_w",
    "amomaxu_d",
    "amomaxu_w",
    "amomin_d",
    "amomin_w",
    "amominu_d",
    "amominu_w",
    "amoor_d",
    "amoor_w",
    "amoswap_d",
    "amoswap_w",
    "amoxor_d",
    "amoxor_w",
    "lrsc",
}

RV_TESTS_M_MODE_EXTENSION = {
    # "csr",  # Arch mismatch with misa.
    # "illegal",  # Not implemented instructions, i.e. wfi.
    "instret_overflow",
    "ld-misaligned",
    "lh-misaligned",
    "lw-misaligned",
    "ma_addr",
    # "ma_fetch",  # Arch mismatch with misa.
    # "mcsr",  # Arch mismatch with misa.
    # "pmpaddr",  # Physical address mismatch with Dromajo. Other than that PASS.
    "sbreak",
    "scall",
    "sd-misaligned",
    "sh-misaligned",
    "sw-misaligned",
    "zicntr",
}

RV_TESTS_S_MODE_EXTENSION = {
    "s-csr",
    "s-dirty",
    "s-icache-alias",
    # "s-ma_fetch",  # Fail due to misaligned address access.
    "s-sbreak",
    "s-scall",
}


@dataclass(frozen=True)
class TestEntry:
    name: str
    group: str
    elf_path: Path
    disasm_path: Path
    instr_path: Path


def discover_tests(root: Path = ROOT) -> list[TestEntry]:
    return [_entry_for_test_name(test_name) for test_name in ALL_TEST_ORDER]


def discover_groups(root: Path = ROOT) -> dict[str, list[str]]:
    return {
        group_name: list(test_names) for group_name, test_names in GROUP_TESTS.items()
    }


def custom_trap_continuation_tests() -> frozenset[str]:
    return frozenset(
        test_name
        for test_name in GROUP_TESTS["custom"]
        if test_name not in CUSTOM_TRAP_CONTINUATION_EXCLUSIONS
    )


def break_call_tests() -> frozenset[str]:
    # Tests named after ebreak/ecall (sbreak, scall, ebreak, ...) stop at the
    # very trap they exercise unless the run continues past it.
    return frozenset(
        test_name
        for test_name in ALL_TEST_ORDER
        if "break" in test_name or "call" in test_name
    )


def trap_continuation_tests() -> frozenset[str]:
    # xv6 programs make ecall syscalls throughout; without trap continuation the
    # simulation would finish at the first one. They terminate at the kernel's
    # final self-loop instead (see SELF_LOOP_CONTINUE_TESTS for the exceptions).
    return (
        custom_trap_continuation_tests()
        | EXTRA_TRAP_CONTINUATION_TESTS
        | break_call_tests()
        | frozenset(GROUP_TESTS["xv6"])
    )


def self_loop_continue_tests() -> frozenset[str]:
    return SELF_LOOP_CONTINUE_TESTS


def cosim_only_tests() -> frozenset[str]:
    return COSIM_ONLY_TESTS


def no_tracecomp_tests() -> frozenset[str]:
    # xv6 runs are far too long for Spike tracecomp in batch (-g/-a) mode;
    # single (-s) runs are not batch-gated and keep tracecomp for debugging.
    return NO_TRACECOMP_TESTS | frozenset(GROUP_TESTS["xv6"])


def discover_binary_inputs(root: Path = ROOT) -> list[Path]:
    inputs: list[Path] = []

    for subdir in TEST_BINARY_DIRS:
        bin_dir = root / BIN_ROOT / subdir
        if not bin_dir.is_dir():
            continue

        inputs.extend(
            sorted(
                path.relative_to(root / BIN_ROOT)
                for path in bin_dir.iterdir()
                if path.suffix in {".elf", ".bin"}
            )
        )

    return inputs


def _entry_for_test_name(test_name: str) -> TestEntry:
    group = _group_for_test_name(test_name)
    bin_subdir = GROUP_BIN_DIRS[group]
    stem = _binary_stem_for_test_name(group, test_name)

    return TestEntry(
        name=test_name,
        group=group,
        elf_path=BIN_ROOT / bin_subdir / f"{stem}.elf",
        disasm_path=DISASM_ROOT / bin_subdir / f"{stem}.txt",
        instr_path=INSTR_ROOT / bin_subdir / f"{stem}.txt",
    )


def _group_for_test_name(test_name: str) -> str:
    for group_name in GROUP_NAMES:
        if test_name in GROUP_TESTS[group_name]:
            return group_name
    raise ValueError(f"Unknown test name in catalog: {test_name}")


def _binary_stem_for_test_name(group: str, test_name: str) -> str:
    if group == "am":
        return f"{test_name.removeprefix('am-')}-riscv64-nemu"
    if group == "rv-arch-test":
        return f"{test_name.removeprefix('rv-arch-test-')}-riscv64-nemu"
    if group == "rv-tests-p":
        short_name = test_name.removeprefix("rv-tests-p-")
        if short_name in RV_TESTS_M_EXTENSION:
            prefix = "rv64um-p"
        elif short_name in RV_TESTS_A_EXTENSION:
            prefix = "rv64ua-p"
        elif short_name in RV_TESTS_M_MODE_EXTENSION:
            prefix = "rv64mi-p"
        elif short_name in RV_TESTS_S_MODE_EXTENSION:
            prefix = "rv64si-p"
        else:
            prefix = "rv64ui-p"
        return f"{prefix}-{short_name}"
    if group == "rv-tests-v":
        short_name = test_name.removeprefix("rv-tests-v-")
        if short_name in RV_TESTS_M_EXTENSION:
            prefix = "rv64um-v"
        elif short_name in RV_TESTS_A_EXTENSION:
            prefix = "rv64ua-v"
        elif short_name in RV_TESTS_M_MODE_EXTENSION:
            prefix = "rv64mi-v"
        elif short_name in RV_TESTS_S_MODE_EXTENSION:
            prefix = "rv64si-v"
        else:
            prefix = "rv64ui-v"
        return f"{prefix}-{short_name}"
    if group == "snippy":
        return test_name
    if group == "custom":
        return f"{test_name.removeprefix('custom-')}-riscv64-nemu"
    if group == "xv6":
        return f"{test_name.removeprefix('xv6-')}"
    raise ValueError(f"Unknown test group in catalog: {group}")
