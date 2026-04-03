#!/bin/sh
# Conformance test runner for NSV implementations.
#
# Verifies encode(decode(fixture)) == fixture (roundtrip identity)
# for every valid fixture.  This checks that encode and decode are
# consistent with each other, not that either is independently correct.
#
# The command in NSV_ROUNDTRIP_DIR takes a directory path, roundtrips
# every .nsv file in it (including dotfiles), prints a summary, and
# exits non-zero if any fixture fails.
#
# Environment variables:
#   NSV_ROUNDTRIP_DIR  Roundtrip command (takes directory argument).
#   NSV_STRESS         Set to "true" to include the Champernowne stress test.

set -e

SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cmd="${NSV_ROUNDTRIP_DIR:?Set NSV_ROUNDTRIP_DIR to your roundtrip command}"
stress="${NSV_STRESS:-false}"

echo "--- valid fixtures (roundtrip) ---"
eval "$cmd" "$SELF_DIR/fixtures/valid"

if [ -f "$SELF_DIR/fixtures/champernowne-fixed.nsv" ]; then
    tmpdir_fixed="$(mktemp -d)"
    trap 'rm -rf "$tmpdir_fixed"' EXIT
    ln -s "$SELF_DIR/fixtures/champernowne-fixed.nsv" "$tmpdir_fixed/champernowne-fixed.nsv"
    echo ""
    echo "--- champernowne-fixed (roundtrip) ---"
    eval "$cmd" "$tmpdir_fixed"
fi

if [ "$stress" = "true" ] && [ -f "$SELF_DIR/fixtures/champernowne.nsv" ]; then
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    ln -s "$SELF_DIR/fixtures/champernowne.nsv" "$tmpdir/champernowne.nsv"
    echo ""
    echo "--- champernowne (stress) ---"
    eval "$cmd" "$tmpdir"
fi
