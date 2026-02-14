#!/bin/sh
# CI check: verify committed fixtures match a fresh generation.
#
# Re-runs the generator to a temporary directory and diffs against the
# committed fixtures. Exits non-zero if anything diverges.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/fixtures/enum"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

uv run "$REPO_ROOT/scripts/gen_enum.py" --out-dir "$tmpdir/enum"

if diff -r "$FIXTURES_DIR" "$tmpdir/enum"; then
    echo "Enum fixtures are up to date."
else
    echo "Enum fixtures differ from fresh generation." >&2
    exit 1
fi

# --- Champernowne fixture ---
CHAMPERNOWNE="$REPO_ROOT/fixtures/champernowne.nsv"

uv run "$REPO_ROOT/scripts/gen_champernowne.py" --out "$tmpdir/champernowne.nsv"

if diff "$CHAMPERNOWNE" "$tmpdir/champernowne.nsv"; then
    echo "Champernowne fixture is up to date."
else
    echo "Champernowne fixture differs from fresh generation." >&2
    exit 1
fi
