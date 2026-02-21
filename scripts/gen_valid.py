#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Generate valid NSV encodings via NDFA traversal.

DFS from S0 through all paths up to --max-transitions transitions.
Each path reaching acceptance produces a unique .nsv fixture file.

Filenames encode the state-machine path. State-changing transitions
use the destination state digit (0/1/2). S2 self-loops use a content
letter: a (add 'a'), b (escaped backslash), n (escaped newline).
The initial S0 and final S0+accept are implicit, so the filename is
the interior of the state sequence. Examples:

  .nsv        (empty)                              (empty encoding)
  1.nsv       S0 → S1 → S0                        (one empty row)
  12a1.nsv    S0 → S1 → S2 → S2 → S1 → S0        (row, cell with 'a')
"""

import argparse
import shutil
from pathlib import Path

# States
S0 = 0  # not-in-row (initial and accepting)
S1 = 1  # in-row
S2 = 2  # in-cell

# Transitions per state, in canonical DFS order.
# Each entry: (next_state, emitted_bytes, path_char)
# next_state is None for the accept transition.
# path_char encodes the transition in the filename:
#   State-changing transitions use the destination state digit.
#   S2 self-loops use a content letter: a, b, n.
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
        (S1, b"\x0a", "1"),         # end cell
        (S2, b"\x61", "a"),         # add 'a'
        (S2, b"\x5c\x5c", "b"),    # add escaped backslash
        (S2, b"\x5c\x6e", "n"),    # add escaped newline
    ],
}


def generate(max_transitions: int, out_dir: Path) -> int:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    count = 0

    # Iterative DFS: stack of (state, accumulated_bytes, transitions_used, path)
    stack: list[tuple[int, bytes, int, str]] = [(S0, b"", 0, "")]

    while stack:
        state, acc, used, path = stack.pop()

        if used >= max_transitions:
            continue

        children: list[tuple[int, bytes, int, str]] = []

        for next_state, emitted, path_char in TRANSITIONS[state]:
            new_acc = acc + emitted if emitted else acc
            new_used = used + 1

            if next_state is None:
                # Accept transition — write file.
                # Strip the trailing "0" (the S0 we accept from is implicit).
                stem = path.removesuffix("0")
                (out_dir / (stem + ".nsv")).write_bytes(new_acc)
                count += 1
            elif new_used < max_transitions:
                children.append((next_state, new_acc, new_used, path + path_char))

        # Push children in reverse order so first child is popped first (DFS)
        for child in reversed(children):
            stack.append(child)

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


if __name__ == "__main__":
    main()
