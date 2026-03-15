#!/bin/sh
# Conformance test runner for NSV implementations.
#
# Verifies encode(decode(fixture)) == fixture (roundtrip identity)
# for every valid fixture.  This is the core conformance property: an
# implementation that roundtrips all canonical fixtures correctly
# implements the NSV format.
#
# Environment variables (provide EITHER roundtrip OR decode+encode):
#   NSV_ROUNDTRIP  Single command: stdin=NSV bytes, stdout=NSV bytes.
#   NSV_DECODE     Shell command: stdin=NSV bytes, stdout=decoded form.
#   NSV_ENCODE     Shell command: stdin=decoded form, stdout=NSV bytes.
#   NSV_STRESS     Set to "true" to include the Champernowne stress test.

set -e

SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALID_DIR="$SELF_DIR/fixtures/valid"

if [ -n "${NSV_ROUNDTRIP:-}" ]; then
    rt_cmd="$NSV_ROUNDTRIP"
elif [ -n "${NSV_DECODE:-}" ] && [ -n "${NSV_ENCODE:-}" ]; then
    rt_cmd="$NSV_DECODE | $NSV_ENCODE"
else
    echo "Set NSV_ROUNDTRIP, or both NSV_DECODE and NSV_ENCODE." >&2
    exit 1
fi

stress="${NSV_STRESS:-false}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

passed=0
failed=0
fail_list=""

roundtrip() {
    _fixture="$1"
    _name="$2"
    if eval "$rt_cmd" < "$_fixture" > "$tmpdir/out" 2>/dev/null &&
       cmp -s "$_fixture" "$tmpdir/out"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        fail_list="$fail_list  $_name
"
    fi
}

echo "--- valid fixtures (roundtrip) ---"

# The empty encoding (.nsv, 0 bytes) is a dotfile — the glob won't match it.
if [ -f "$VALID_DIR/.nsv" ]; then
    roundtrip "$VALID_DIR/.nsv" ".nsv"
fi

for f in "$VALID_DIR/"*.nsv; do
    [ -f "$f" ] || continue
    roundtrip "$f" "$(basename "$f")"
done

echo "  $passed/$((passed + failed)) passed"

if [ "$stress" = "true" ] && [ -f "$SELF_DIR/fixtures/champernowne.nsv" ]; then
    echo ""
    echo "--- champernowne (stress) ---"
    roundtrip "$SELF_DIR/fixtures/champernowne.nsv" "champernowne.nsv"
    echo "  done"
fi

echo ""
total=$((passed + failed))
echo "passed $passed/$total"

if [ "$failed" -gt 0 ]; then
    echo "failed $failed/$total"
    printf "%s" "$fail_list"
    exit 1
fi
