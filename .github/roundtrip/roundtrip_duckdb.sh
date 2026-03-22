#!/bin/sh
# DuckDB roundtrip conformance test.
#
# Reads each .nsv fixture via the nsv-duckdb extension, writes it back,
# and checks byte-exact identity.  All columns are kept as VARCHAR to
# avoid type-narrowing changing values.
#
# Because read_nsv always interprets the first row as column names
# (and DuckDB rejects duplicate column names), we prepend a synthetic
# header row with unique names, roundtrip through DuckDB, then strip
# the synthetic header from the output before comparing.
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

# Count the number of cells in the first row of an NSV file.
# Parses the byte stream through the NSV state machine until end-of-row.
nsv_first_row_cols() {
    od -An -tx1 "$1" | tr -s ' ' '\n' | awk '
    BEGIN { s = 1; cols = 0 }
    !NF { next }
    {
        if (s == 1) {
            # S1: in-row, expecting cell or row-end
            if ($1 == "0a") { print cols; s = -1; exit }
            else if ($1 == "5c") { cols++; s = 3 }
            else { cols++; s = 2 }
        } else if (s == 2) {
            # S2: in-cell content
            if ($1 == "0a") { s = 1 }
            else if ($1 == "5c") { s = 4 }
        } else if (s == 3) {
            # After 5c in S1: if 0a, it was an empty cell; otherwise
            # the 5c started a non-empty cell (escape sequence in S2).
            if ($1 == "0a") { s = 1 } else { s = 2 }
        } else if (s == 4) {
            # After 5c in S2: consume escaped byte
            s = 2
        }
    }
    END { if (s == 1) print cols }'
}

for f in "$dir"/*.nsv; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"

    # Skip zero-column fixtures (empty file or first row has no cells).
    first_byte=$(od -An -tx1 -N1 "$f" | tr -d ' ')
    if [ -z "$first_byte" ] || [ "$first_byte" = "0a" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    ncols=$(nsv_first_row_cols "$f")

    # Build a synthetic header row with unique column names (c0, c1, ...).
    header_file="$(mktemp)"
    i=0
    while [ "$i" -lt "$ncols" ]; do
        printf 'c%d\n' "$i" >> "$header_file"
        i=$((i + 1))
    done
    printf '\n' >> "$header_file"   # row terminator
    header_len=$(wc -c < "$header_file")

    # Prepend the synthetic header to the fixture.
    input_file="$(mktemp)"
    cat "$header_file" "$f" > "$input_file"

    out="$(mktemp)"

    if ! "$duckdb" -unsigned -noheader -csv :memory: <<SQL
LOAD '${ext}';
COPY (SELECT * FROM read_nsv('${input_file}', all_varchar=true))
  TO '${out}' (FORMAT 'nsv');
SQL
    then
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
        rm -f "$out" "$input_file" "$header_file"
        continue
    fi

    # Strip the synthetic header from the output.
    stripped="$(mktemp)"
    tail -c +"$((header_len + 1))" "$out" > "$stripped"

    if cmp -s "$f" "$stripped"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        fails="${fails}  ${name}
"
    fi
    rm -f "$out" "$input_file" "$header_file" "$stripped"
done

total=$((passed + failed))
echo "  ${passed}/${total} passed (${skipped} skipped)"
if [ -n "$fails" ]; then
    printf '%s' "$fails"
    exit 1
fi
