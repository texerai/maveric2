from __future__ import annotations

import subprocess
import sys
from pathlib import Path


_ROOT_DIR = Path(__file__).resolve().parents[1]
if str(_ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(_ROOT_DIR))

from scripts.test_catalog import BIN_ROOT, DISASM_ROOT, ROOT, discover_binary_inputs


OBJDUMP = "riscv64-unknown-elf-objdump"


def main() -> int:
    for input_file in discover_binary_inputs(ROOT):
        input_path = ROOT / BIN_ROOT / input_file
        output_path = ROOT / DISASM_ROOT / input_file.with_suffix(".txt")
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with output_path.open("w") as output_file:
            subprocess.run(
                _objdump_command(input_path),
                stdout=output_file,
                check=True,
            )

    return 0


def _objdump_command(input_path: Path) -> list[str]:
    command = [OBJDUMP, "-D", "--full-content", "-M", "no-aliases,numeric"]
    if input_path.suffix == ".bin":
        command.extend(
            [
                "--start-address=0x80000000",
                "-b",
                "binary",
                "--adjust-vma=0x80000000",
                "-m",
                "riscv:rv64",
            ]
        )
    command.append(str(input_path))
    return command


if __name__ == "__main__":
    raise SystemExit(main())
