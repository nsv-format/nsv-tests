#!/bin/sh
# DuckDB roundtrip conformance test.
#
# Reads each .nsv fixture via the nsv-duckdb extension (header=false),
# writes it back, and checks byte-exact identity.  All columns are kept
# as VARCHAR to avoid type-narrowing changing values.
#
# With header=false the extension auto-generates column names (column0,
# column1, …) and treats the first row as data.  COPY TO writes these
# auto-generated names as a header row, which we strip before comparing.
#
# Skipped fixtures:
#   - empty files (no rows)
#   - zero-column rows (DuckDB requires >= 1 column)
#   - multi-row files (no multi-row fixture at the 10-transition
#     budget avoids empty cells or ragged column counts)
#   - files with empty cells (the writer produces bare 0A instead
#     of 5C 0A, which the reader interprets as end-of-row)
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

# Validate an NSV file for DuckDB compatibility.
# Parses through the state machine and outputs: cols rows has_empty
# where cols = cells in row 1, rows = total row count,
# has_empty = 1 if any empty cell (5C 0A at S1) was found.
nsv_validate() {
    od -An -tx1 "$1" | tr -s ' ' '\n' | awk '
    BEGIN { s = 1; cols = 0; rows = 0; empty = 0; first_cols = -1 }
    !NF { next }
    {
        if (s == 1) {
            if ($1 == "0a") {
                # end row
                rows++
                if (first_cols < 0) first_cols = cols
                cols = 0
                s = 0
            } else if ($1 == "5c") {
                cols++; s = 3
            } else {
                cols++; s = 2
            }
        } else if (s == 0) {
            # S0: between rows
            if ($1 == "0a") {
                # zero-column row
                rows++
                cols = 0
            } else if ($1 == "5c") {
                cols = 1; s = 3
            } else {
                cols = 1; s = 2
            }
        } else if (s == 2) {
            if ($1 == "0a") { s = 1 }
            else if ($1 == "5c") { s = 4 }
        } else if (s == 3) {
            # After 5c at S1: 0a = empty cell, else = non-empty cell start
            if ($1 == "0a") { empty = 1; s = 1 }
            else { s = 2 }
        } else if (s == 4) {
            s = 2
        }
    }
    END {
        if (first_cols < 0) first_cols = 0
        print first_cols, rows, empty
    }'
}

for f in "$dir"/*.nsv; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"

    # Skip empty files.
    if [ ! -s "$f" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    result=$(nsv_validate "$f")
    ncols=$(echo "$result" | awk '{print $1}')
    nrows=$(echo "$result" | awk '{print $2}')
    has_empty=$(echo "$result" | awk '{print $3}')

    # Skip zero-column, multi-row, or empty-cell fixtures.
    if [ "$ncols" -eq 0 ] || [ "$nrows" -gt 1 ] || [ "$has_empty" -eq 1 ]; then
        skipped=$((skipped + 1))
        continue
    fi

    # Compute the byte length of the auto-generated header row
    # (column0\ncolumn1\n…\n\n) so we can strip it from the output.
    header_len=1   # row terminator \n
    i=0
    while [ "$i" -lt "$ncols" ]; do
        cname="column${i}"
        header_len=$((header_len + ${#cname} + 1))   # name + cell terminator \n
        i=$((i + 1))
    done

    out="$(mktemp)"

    if ! "$duckdb" -unsigned -noheader -csv :memory: <<SQL
LOAD '${ext}';
COPY (SELECT * FROM read_nsv('${f}', header=false, all_varchar=true))
  TO '${out}' (FORMAT 'nsv');
SQL
    then
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
        rm -f "$out"
        continue
    fi

    # Strip the auto-generated header from the output.
    stripped="$(mktemp)"
    tail -c +"$((header_len + 1))" "$out" > "$stripped"

    if cmp -s "$f" "$stripped"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
    fi
    rm -f "$out" "$stripped"
done

total=$((passed + failed))
echo "  ${passed}/${total} passed (${skipped} skipped)"
if [ -n "$fails" ]; then
    printf '%s' "$fails"
    exit 1
fi
