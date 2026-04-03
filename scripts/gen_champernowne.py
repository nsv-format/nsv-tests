#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["nsv"]
# ///
"""Generate Champernowne-style NSV test fixture.

Produces a single file containing the concatenation of every byte sequence
over a 3-symbol alphabet (LF, backslash, 'n') for lengths 0 through
--max-length, in lexicographic order of their base-3 digit representation
(0=LF, 1='\\', 2='n').

Same iteration order as gen_enum.py, but all bytes go into one file.
"""

import argparse
import itertools
from pathlib import Path

import nsv

ALPHABET = {
    "0": b"\x0a",  # LF
    "1": b"\x5c",  # backslash
    "2": b"\x6e",  # 'n'
}
DIGITS = list(ALPHABET.keys())

_BUF_SIZE = 1 << 20  # 1 MiB flush threshold


def expected_byte_count(max_length: int) -> int:
    """Sum of k * 3^k for k in 0..max_length."""
    total = 0
    for k in range(max_length + 1):
        total += k * (3**k)
    return total


def generate(max_length: int, out: Path) -> int:
    out.parent.mkdir(parents=True, exist_ok=True)

    total_bytes = 0
    buf = bytearray()
    with open(out, "wb") as f:
        for length in range(max_length + 1):
            if length == 0:
                continue

            for combo in itertools.product(DIGITS, repeat=length):
                buf.extend(b"".join(ALPHABET[d] for d in combo))
                if len(buf) >= _BUF_SIZE:
                    f.write(buf)
                    total_bytes += len(buf)
                    buf.clear()

        if buf:
            f.write(buf)
            total_bytes += len(buf)
            buf.clear()

    return total_bytes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-length",
        type=int,
        default=14,
        help="Maximum sequence length (default: 14)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("fixtures/champernowne.nsv"),
        help="Output file (default: fixtures/champernowne.nsv)",
    )
    args = parser.parse_args()

    total_bytes = generate(args.max_length, args.out)
    expect = expected_byte_count(args.max_length)

    print(f"Wrote {total_bytes} bytes to {args.out}")
    assert total_bytes == expect, f"Expected {expect} bytes, got {total_bytes}"
    print(f"Sanity check passed: {total_bytes} == {expect}")

    # Generate fixed-point: decode as NSV and re-encode.
    raw = args.out.read_text()
    fixed = nsv.dumps(nsv.loads(raw))
    fixed_out = args.out.with_name("champernowne-fixed.nsv")
    fixed_out.write_text(fixed)
    print(f"Wrote {len(fixed)} bytes to {fixed_out}")


if __name__ == "__main__":
    main()
