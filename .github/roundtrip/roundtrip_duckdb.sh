#!/bin/sh
# DuckDB roundtrip conformance test.
#
# Reads each .nsv fixture via the nsv-duckdb extension, writes it back,
# and checks byte-exact identity.  All columns are kept as VARCHAR to
# avoid type-narrowing changing values.
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
fails=""

for f in "$dir"/*.nsv; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    out="$(mktemp)"

    "$duckdb" -noheader -csv :memory: <<SQL >/dev/null 2>&1
LOAD '${ext}';
COPY (SELECT * FROM read_nsv('${f}', all_varchar=true, header=false))
  TO '${out}' (FORMAT 'nsv', header false);
SQL

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
echo "  ${passed}/${total} passed"
if [ -n "$fails" ]; then
    printf '%s' "$fails"
    exit 1
fi
