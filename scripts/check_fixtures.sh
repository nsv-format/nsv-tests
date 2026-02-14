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
    echo "Fixtures are up to date."
else
    echo "Fixtures differ from fresh generation." >&2
    exit 1
fi
