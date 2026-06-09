#!/bin/sh
# Cross-implementation coercion conformance — manifest generator.
#
# conformance.sh checks roundtrip identity on inputs that are already
# valid NSV, which exercises zero coercion: the interesting edge cases
# (dangling backslashes, bare escapes, missing terminators) only appear
# when decoding RAW byte sequences.  The spec defines exactly how every
# rejected sequence is coerced, so encode(decode(raw)) must produce the
# SAME bytes in every implementation.  No single implementation is
# trusted as the oracle: each one emits a manifest of sha256 hashes
# (this script's stdout), and CI diffs the manifests across
# implementations — the cross-impl consensus is the oracle.
#
# The command in NSV_COERCE takes <mode> <indir> <outdir>: for every
# .nsv file in <indir> (including dotfiles), decode it with the
# implementation's non-resumable batch decoder (mode "batch") or its
# resumable/streaming Reader + Writer (mode "stream"), re-encode, and
# write the result to <outdir> under the same filename.
#
# Corpora and checks:
#   - enum corpus, batch:  manifest + fixed point (coercing the coerced
#     output again must be the identity).
#   - enum corpus, stream: manifest only.  The enum corpus includes
#     unterminated inputs (no trailing "\n\n"), so diffing these
#     manifests across implementations surfaces resumable-reader EOF
#     divergences that the roundtrip suite (valid, terminated fixtures
#     only) can never see.  No fixed-point check: stream consensus is
#     judged only cross-impl, in CI.
#   - raw champernowne.nsv, batch: manifest + fixed point + must equal
#     the committed champernowne-fixed.nsv byte for byte, so the fixture
#     is re-derived by every implementation instead of trusted from the
#     single-impl build that generated it.
#
# The manifest (stdout) has one tab-separated line per mode/file:
#   <mode> <filename> <sha256>
# Progress and failures go to stderr.
#
# Environment variables:
#   NSV_COERCE  Coercion command (takes <mode> <indir> <outdir>).

set -e

SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cmd="${NSV_COERCE:?Set NSV_COERCE to your coercion command}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# sha256 of every .nsv file in a directory, sorted by filename.
hashes() {
    (cd "$1" && find . -maxdepth 1 -name '*.nsv' | sed 's|^\./||' \
        | LC_ALL=C sort | xargs -r sha256sum)
}

# sha256sum prints "<hash>  <filename>"; manifest wants "<mode> <filename> <hash>".
manifest() {
    awk -v mode="$1" 'BEGIN { OFS = "\t" } { print mode, $2, $1 }'
}

echo "--- enum (batch coercion) ---" >&2
mkdir "$workdir/enum-batch" "$workdir/enum-batch-2"
eval "$cmd" batch "$SELF_DIR/fixtures/enum" "$workdir/enum-batch"
eval "$cmd" batch "$workdir/enum-batch" "$workdir/enum-batch-2"
hashes "$workdir/enum-batch"   > "$workdir/enum-batch.sums"
hashes "$workdir/enum-batch-2" > "$workdir/enum-batch-2.sums"
if ! diff "$workdir/enum-batch.sums" "$workdir/enum-batch-2.sums" >&2; then
    echo "FAIL: enum batch coercion is not a fixed point" >&2
    exit 1
fi
manifest batch < "$workdir/enum-batch.sums"

echo "--- enum (stream coercion) ---" >&2
mkdir "$workdir/enum-stream"
eval "$cmd" stream "$SELF_DIR/fixtures/enum" "$workdir/enum-stream"
hashes "$workdir/enum-stream" | manifest stream

echo "--- champernowne (batch coercion) ---" >&2
mkdir "$workdir/champ-in" "$workdir/champ-batch" "$workdir/champ-batch-2"
ln -s "$SELF_DIR/fixtures/champernowne.nsv" "$workdir/champ-in/champernowne.nsv"
eval "$cmd" batch "$workdir/champ-in" "$workdir/champ-batch"
if ! cmp "$workdir/champ-batch/champernowne.nsv" \
         "$SELF_DIR/fixtures/champernowne-fixed.nsv" >&2; then
    echo "FAIL: batch coercion of champernowne.nsv does not reproduce champernowne-fixed.nsv" >&2
    exit 1
fi
eval "$cmd" batch "$workdir/champ-batch" "$workdir/champ-batch-2"
if ! cmp "$workdir/champ-batch/champernowne.nsv" \
         "$workdir/champ-batch-2/champernowne.nsv" >&2; then
    echo "FAIL: champernowne batch coercion is not a fixed point" >&2
    exit 1
fi
hashes "$workdir/champ-batch" | manifest batch
