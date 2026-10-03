#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Generate valid NSV encodings via NDFA traversal.

DFS from S0 through all paths up to --max-transitions transitions.
Each path reaching acceptance produces a unique .nsv fixture file.

Filenames encode the state-machine path. Structural moves use the
destination digit (0/1/2); cell content adds use a letter: a (add 'a'),
b (escaped backslash), n (escaped newline). The initial S0 and final
S0+accept are implicit, so the filename is the interior of the state
sequence. Examples:

  .nsv        (empty)                              (empty encoding)
  1.nsv       S0 → S1 → S0                        (one empty row)
  12a1.nsv    S0 → S1 → S2 → S3 → S1 → S0        (row, cell with 'a')
"""

import argparse
import shutil
from pathlib import Path

# States
S0 = 0  # not-in-row (initial and accepting)
S1 = 1  # in-row, between cells
S2 = 2  # in a non-empty cell, no content added yet
S3 = 3  # in a non-empty cell, with content

# Transitions per state, in canonical DFS order.
# Each entry: (next_state, emitted_bytes, path_char)
# next_state is None for the accept transition.
# path_char encodes the transition in the filename:
#   Structural moves use the destination digit: 1 (S1), 2 (entered a cell),
#   0 (S0, dropped when it is the final transition). Cell content adds use a
#   letter: a (add 'a'), b (escaped backslash), n (escaped newline).
#
# A non-empty cell must contain content, which is enforced structurally
# rather than with a precondition: S2 (cell just opened) has no transition
# back to S1. The only way to close a cell is via S3 (cell with content),
# which is reachable only by adding at least one content byte. A cell can
# therefore never emit a bare 0A, so end-cell and end-row never collide.
TRANSITIONS: dict[int, list[tuple[int | None, bytes, str]]] = {
    S0: [
        (None, b"", ""),            # accept
        (S1, b"", "1"),             # start row
    ],
    S1: [
        (S0, b"\x0a", "0"),         # end row
        (S1, b"\x5c\x0a", "1"),     # start empty cell
        (S2, b"", "2"),             # start non-empty cell
    ],
    S2: [
        (S3, b"\x61", "a"),         # add 'a'
        (S3, b"\x5c\x5c", "b"),     # add escaped backslash
        (S3, b"\x5c\x6e", "n"),     # add escaped newline
    ],
    S3: [
        (S1, b"\x0a", "1"),         # end cell
        (S3, b"\x61", "a"),         # add 'a'
        (S3, b"\x5c\x5c", "b"),     # add escaped backslash
        (S3, b"\x5c\x6e", "n"),     # add escaped newline
    ],
}

CONTENT = {"a": "a", "b": "\\", "n": "\n"}


def path_to_seqseq(name: str) -> list[list[str]]:
    """Derive expected Seq[Seq[String]] from NDFA path in filename."""
    stem = name.removesuffix(".nsv")
    if not stem:
        return []
    state = S0
    rows: list[list[str]] = []
    row: list[str] = []
    cell: list[str] = []
    for ch in stem:
        if state == S0:
            row = []; state = S1
        elif state == S1:
            if ch == "0": rows.append(row); state = S0
            elif ch == "1": row.append("")
            elif ch == "2": cell = []; state = S2
        elif state == S2:
            cell.append(CONTENT[ch]); state = S3
        elif state == S3:
            if ch == "1": row.append("".join(cell)); cell = []; state = S1
            else: cell.append(CONTENT[ch])
    if state == S1:
        rows.append(row)
    return rows


def _apply_semantic(state: int, next_state: int | None, path_char: str,
                    rows: list[list[str]], row: list[str],
                    cell: list[str]) -> tuple[list[list[str]], list[str], list[str]]:
    """Advance the decoded-seqseq state for one transition."""
    new_rows = [r[:] for r in rows]
    new_row = row[:]
    new_cell = cell[:]

    if state == S0:
        new_row = []
    elif state == S1:
        if path_char == "0":
            new_rows.append(new_row); new_row = []
        elif path_char == "1":
            new_row.append("")
        elif path_char == "2":
            new_cell = []
    elif state in (S2, S3):
        if path_char == "1":
            new_row.append("".join(new_cell)); new_cell = []
        else:
            new_cell.append(CONTENT[path_char])

    return new_rows, new_row, new_cell


def generate(max_transitions: int, out_dir: Path) -> int:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    count = 0
    mismatches = 0

    # Iterative DFS: stack of (state, accumulated_bytes, transitions_used, path,
    #                          rows, current_row, current_cell)
    stack: list[tuple[int, bytes, int, str,
                       list[list[str]], list[str], list[str]]] = [
        (S0, b"", 0, "", [], [], [])
    ]

    while stack:
        state, acc, used, path, rows, row, cell = stack.pop()

        if used >= max_transitions:
            continue

        children = []

        for next_state, emitted, path_char in TRANSITIONS[state]:
            new_acc = acc + emitted if emitted else acc
            new_used = used + 1

            new_rows, new_row, new_cell = _apply_semantic(
                state, next_state, path_char, rows, row, cell)

            if next_state is None:
                stem = path.removesuffix("0")
                (out_dir / (stem + ".nsv")).write_bytes(new_acc)
                count += 1

                expected = path_to_seqseq(stem + ".nsv")
                if expected != new_rows:
                    print(f"  MISMATCH {stem}.nsv: "
                          f"generator={new_rows!r} interpreter={expected!r}")
                    mismatches += 1
            elif new_used < max_transitions:
                children.append((next_state, new_acc, new_used,
                                 path + path_char,
                                 new_rows, new_row, new_cell))

        for child in reversed(children):
            stack.append(child)

    if mismatches:
        raise SystemExit(
            f"NDFA interpreter mismatches: {mismatches}/{count}")

    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-transitions",
        type=int,
        default=10,
        help="Maximum number of transitions per path (default: 10)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("fixtures/valid"),
        help="Output directory (default: fixtures/valid)",
    )
    args = parser.parse_args()

    count = generate(args.max_transitions, args.out_dir)
    print(f"Generated {count} files in {args.out_dir}")
    print(f"NDFA interpreter cross-check: all {count} match")


if __name__ == "__main__":
    main()
