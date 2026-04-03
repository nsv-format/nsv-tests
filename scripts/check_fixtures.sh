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

CHAMPERNOWNE_FIXED="$REPO_ROOT/fixtures/champernowne-fixed.nsv"

if diff "$CHAMPERNOWNE_FIXED" "$tmpdir/champernowne-fixed.nsv"; then
    echo "Fixed-point Champernowne fixture is up to date."
else
    echo "Fixed-point Champernowne fixture differs from fresh generation." >&2
    exit 1
fi

# --- Valid encoding fixtures ---
VALID_DIR="$REPO_ROOT/fixtures/valid"

uv run "$REPO_ROOT/scripts/gen_valid.py" --out-dir "$tmpdir/valid"

if diff -r "$VALID_DIR" "$tmpdir/valid"; then
    echo "Valid encoding fixtures are up to date."
else
    echo "Valid encoding fixtures differ from fresh generation." >&2
    exit 1
fi
