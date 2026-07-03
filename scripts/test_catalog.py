from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BIN_ROOT = Path("test/tests/bin")
DISASM_ROOT = Path("test/tests/dis-asm")
INSTR_ROOT = Path("test/tests/instr")

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
        rv-arch-test-fence rv-arch-test-fencei rv-arch-test-jalr
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
    "rv-tests": """
        rv-tests-add rv-tests-addi rv-tests-addiw rv-tests-addw rv-tests-and
        rv-tests-andi rv-tests-auipc rv-tests-beq rv-tests-bge rv-tests-bgeu
        rv-tests-blt rv-tests-bltu rv-tests-bne rv-tests-fence_i
        rv-tests-jal rv-tests-jalr
        rv-tests-lb rv-tests-lbu rv-tests-ld rv-tests-ld_st rv-tests-lh
        rv-tests-lhu rv-tests-lui rv-tests-lw rv-tests-lwu rv-tests-or
        rv-tests-ori rv-tests-sb rv-tests-sd rv-tests-sh rv-tests-simple
        rv-tests-sll rv-tests-slli rv-tests-slliw rv-tests-sllw
        rv-tests-slt rv-tests-slti rv-tests-sltiu rv-tests-sltu
        rv-tests-sra rv-tests-srai rv-tests-sraiw rv-tests-sraw
        rv-tests-srl rv-tests-srli rv-tests-srliw rv-tests-srlw
        rv-tests-st_ld rv-tests-sub rv-tests-subw rv-tests-sw
        rv-tests-xor rv-tests-xori rv-tests-div rv-tests-divu
        rv-tests-divuw rv-tests-divw rv-tests-mul rv-tests-mulh
        rv-tests-mulhsu rv-tests-mulhu rv-tests-mulw rv-tests-rem
        rv-tests-remu rv-tests-remuw rv-tests-remw
        rv-tests-amoadd_d rv-tests-amoadd_w rv-tests-amoand_d
        rv-tests-amoand_w rv-tests-amomax_d rv-tests-amomax_w
        rv-tests-amomaxu_d rv-tests-amomaxu_w rv-tests-amomin_d
        rv-tests-amomin_w rv-tests-amominu_d rv-tests-amominu_w
        rv-tests-amoor_d rv-tests-amoor_w rv-tests-amoswap_d
        rv-tests-amoswap_w rv-tests-amoxor_d rv-tests-amoxor_w
        rv-tests-lrsc
        rv-tests-ld-misaligned rv-tests-lh-misaligned rv-tests-lw-misaligned
        rv-tests-sbreak rv-tests-scall
        rv-tests-sd-misaligned rv-tests-sh-misaligned rv-tests-sw-misaligned
        rv-tests-ssbreak rv-tests-sscall
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
        custom-clint-mti-irq-regwrite custom-rtthread
    """.split(),
}

GROUP_NAMES = tuple(GROUP_TESTS)

ALL_TEST_ORDER = (
    *GROUP_TESTS["am"],
    *GROUP_TESTS["rv-arch-test"],
    *GROUP_TESTS["rv-tests"],
    *GROUP_TESTS["snippy"],
    *GROUP_TESTS["custom"],
)

TEST_BINARY_DIRS = (
    "am-kernels",
    "riscv-arch-test",
    "riscv-tests",
    "snippy",
    "custom",
)

GROUP_BIN_DIRS = {
    "am": "am-kernels",
    "rv-arch-test": "riscv-arch-test",
    "rv-tests": "riscv-tests",
    "snippy": "snippy",
    "custom": "custom",
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
# self-check still run). Cosim-only tests skip tracecomp implicitly.
NO_TRACECOMP_TESTS = frozenset(
    {
        "custom-csr-test-2",
        "custom-clint-msi-mti",
    }
)

# Continue-after-trap tests not covered by custom_trap_continuation_tests().
EXTRA_TRAP_CONTINUATION_TESTS = frozenset({"am-yield-os"})

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
    # "csr",  # Accesses not implemented CSRs.
    # "illegal", # Not implemented instructions.
    "ld-misaligned",
    "lh-misaligned",
    "lw-misaligned",
    # "ma_addr",  # Currently mtval is read-only. Fail on tracecomp and arch mismatch with dromajo (misa).
    # "ma_fetch",  # Currently mtval is read-only. Fail on tracecomp and arch mismatch with dromajo (misa).
    # "mcsr",  # Arch mismatch with dromajo (misa).
    "sbreak",
    "scall",
    "sd-misaligned",
    "sh-misaligned",
    "sw-misaligned",
}

RV_TESTS_S_MODE_EXTENSION = {
    # "scsr",  # Need to fix issue with mstatus and sstatus csr access in log.
    # "sma_fetch",  # Currently mtval is read-only. Fail on tracecomp and arch mismatch with dromajo (misa).
    "ssbreak",
    "sscall",
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


def trap_continuation_tests() -> frozenset[str]:
    return custom_trap_continuation_tests() | EXTRA_TRAP_CONTINUATION_TESTS


def cosim_only_tests() -> frozenset[str]:
    return COSIM_ONLY_TESTS


def no_tracecomp_tests() -> frozenset[str]:
    return NO_TRACECOMP_TESTS


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
    if group == "rv-tests":
        short_name = test_name.removeprefix("rv-tests-")
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
    if group == "snippy":
        return test_name
    if group == "custom":
        return f"{test_name.removeprefix('custom-')}-riscv64-nemu"
    raise ValueError(f"Unknown test group in catalog: {group}")
