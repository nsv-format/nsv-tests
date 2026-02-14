#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Generate enumerated NSV test fixtures.

Produces every possible byte sequence over a 3-symbol alphabet
(LF, backslash, 'n') for lengths 0 through --max-length.
"""

import argparse
import itertools
import shutil
from pathlib import Path

ALPHABET = {
    "0": b"\x0a",  # LF
    "1": b"\x5c",  # backslash
    "2": b"\x6e",  # 'n'
}
DIGITS = list(ALPHABET.keys())


def expected_count(max_length: int) -> int:
    """Geometric sum: 3^0 + 3^1 + ... + 3^max_length = (3^(max_length+1) - 1) // 2."""
    return (3 ** (max_length + 1) - 1) // 2


def generate(max_length: int, out_dir: Path) -> int:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    count = 0

    for length in range(max_length + 1):
        if length == 0:
            # Empty sequence -> filename is just ".nsv", contents empty
            (out_dir / ".nsv").write_bytes(b"")
            count += 1
            continue

        for combo in itertools.product(DIGITS, repeat=length):
            name = "".join(combo) + ".nsv"
            data = b"".join(ALPHABET[d] for d in combo)
            (out_dir / name).write_bytes(data)
            count += 1

    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-length", type=int, default=6, help="Maximum sequence length (default: 6)"
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("fixtures/enum"),
        help="Output directory (default: fixtures/enum)",
    )
    args = parser.parse_args()

    count = generate(args.max_length, args.out_dir)
    expect = expected_count(args.max_length)

    print(f"Generated {count} files in {args.out_dir}")
    assert count == expect, f"Expected {expect} files, got {count}"
    print(f"Sanity check passed: {count} == {expect}")


if __name__ == "__main__":
    main()
