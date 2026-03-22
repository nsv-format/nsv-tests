#!/bin/sh
# DuckDB roundtrip conformance test.
#
# Reads each .nsv fixture via the nsv-duckdb extension, writes it back,
# and checks byte-exact identity.  All columns are kept as VARCHAR to
# avoid type-narrowing changing values.
#
# Fixtures whose first row has zero cells are skipped because DuckDB
# requires at least one column.
#
# Usage: roundtrip_duckdb.sh <dir>
#
# Environment variables:
#   DUCKDB       Path to DuckDB binary      (default: duckdb)
#   NSV_EXT      Path to .duckdb_extension   (default: nsv.duckdb_extension)

set -e

dir="$1"
duckdb="${DUCKDB:-duckdb}"
ext="${NSV_EXT:-nsv.duckdb_extension}"

passed=0
failed=0
skipped=0
fails=""

for f in "$dir"/*.nsv; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"

    # Skip zero-column fixtures (empty file or first row has no cells).
    # A first row with zero cells starts with 0x0A (the row terminator).
    first_byte=$(od -An -tx1 -N1 "$f" | tr -d ' ')
    if [ -z "$first_byte" ] || [ "$first_byte" = "0a" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    out="$(mktemp)"

    if ! "$duckdb" -unsigned -noheader -csv :memory: <<SQL
LOAD '${ext}';
COPY (SELECT * FROM read_nsv('${f}', all_varchar=true))
  TO '${out}' (FORMAT 'nsv');
SQL
    then
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
        rm -f "$out"
        continue
    fi

    if cmp -s "$f" "$out"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
    fi
    rm -f "$out"
done

total=$((passed + failed))
echo "  ${passed}/${total} passed (${skipped} skipped)"
if [ -n "$fails" ]; then
    printf '%s' "$fails"
    exit 1
fi
