#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""CI check: verify committed fixtures match a fresh generation.

Re-runs the generator to a temporary directory and diffs against the
committed fixtures. Exits non-zero if anything diverges.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
GENERATOR = SCRIPTS_DIR / "gen_enum.py"
FIXTURES_DIR = REPO_ROOT / "fixtures" / "enum"


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_enum = Path(tmp) / "enum"

        # Re-generate into temp dir
        result = subprocess.run(
            [sys.executable, str(GENERATOR), "--out-dir", str(tmp_enum)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print("Generator failed:", file=sys.stderr)
            print(result.stderr, file=sys.stderr)
            sys.exit(1)

        # diff -r the two directories
        diff = subprocess.run(
            ["diff", "-r", str(FIXTURES_DIR), str(tmp_enum)],
            capture_output=True,
            text=True,
        )
        if diff.returncode != 0:
            print("Fixtures differ from fresh generation:", file=sys.stderr)
            print(diff.stdout, file=sys.stderr)
            sys.exit(1)

    print("Fixtures are up to date.")


if __name__ == "__main__":
    main()
