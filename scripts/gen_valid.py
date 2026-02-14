#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Generate valid NSV encodings via NDFA traversal.

DFS from S0 through all paths up to --max-transitions transitions.
Each path reaching acceptance produces a unique .nsv fixture file.
"""

import argparse
import shutil
from pathlib import Path

# States
S0 = 0  # not-in-row (initial and accepting)
S1 = 1  # in-row
S2 = 2  # in-cell

# Transitions per state, in canonical DFS order.
# Each entry: (next_state, emitted_bytes)
# next_state is None for the accept transition.
TRANSITIONS: dict[int, list[tuple[int | None, bytes]]] = {
    S0: [
        (None, b""),            # accept
        (S1, b""),              # start row
    ],
    S1: [
        (S0, b"\x0a"),          # end row
        (S1, b"\x5c\x0a"),      # start empty cell
        (S2, b""),              # start non-empty cell
    ],
    S2: [
        (S1, b"\x0a"),          # end cell
        (S2, b"\x61"),          # add 'a'
        (S2, b"\x5c\x5c"),     # add escaped backslash
        (S2, b"\x5c\x6e"),     # add escaped newline
    ],
}


def generate(max_transitions: int, out_dir: Path) -> int:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    encodings: list[bytes] = []

    # Iterative DFS: stack of (state, accumulated_bytes, transitions_used)
    stack: list[tuple[int, bytes, int]] = [(S0, b"", 0)]

    while stack:
        state, acc, used = stack.pop()

        if used >= max_transitions:
            continue

        children: list[tuple[int, bytes, int]] = []

        for next_state, emitted in TRANSITIONS[state]:
            new_acc = acc + emitted if emitted else acc
            new_used = used + 1

            if next_state is None:
                # Accept transition
                encodings.append(new_acc)
            elif new_used < max_transitions:
                children.append((next_state, new_acc, new_used))

        # Push children in reverse order so first child is popped first (DFS)
        for child in reversed(children):
            stack.append(child)

    # Write files with uniform zero-padded names (minimum 6 digits)
    width = max(6, len(str(len(encodings) - 1))) if len(encodings) > 1 else 6
    for i, data in enumerate(encodings):
        name = f"{i:0{width}d}.nsv"
        (out_dir / name).write_bytes(data)

    return len(encodings)


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
