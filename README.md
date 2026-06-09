# nsv-tests
NSV, testing infrastructure

Canonical cross-language corpora ([fixtures/README.md](fixtures/README.md))
and the conformance suites that run every NSV implementation against them
(`.github/workflows/conformance.yml`: Python, JS, Java, Scala, Rust, plus
DuckDB for roundtrip).

## Roundtrip — `scripts/conformance.sh`

Per implementation, asserts `encode(decode(x)) == x` over the valid fixtures.
The command in `NSV_ROUNDTRIP_DIR` takes a directory, roundtrips every `.nsv`
file in it, and exits non-zero on any failure. All per-language harnesses
(`.github/roundtrip/`) use the batch encode/decode APIs.

This only ever sees valid, terminated input, so it exercises zero coercion —
that is the next suite's job.

## Coercion — `scripts/coercion.sh`

Decodes raw byte sequences (the enum corpus and raw `champernowne.nsv`, dense
with dangling backslashes, bare escapes, and missing terminators) and
re-encodes them. The spec defines exactly how every rejected sequence is
coerced, so every implementation must produce the same bytes. No single
implementation is trusted as the oracle: each emits a manifest of sha256
hashes, and the `coercion-compare` CI job diffs the manifests across
implementations — the cross-impl consensus is the oracle. Each run also
asserts its output is a fixed point (coercing it again is the identity) and
that champernowne's coercion reproduces the committed
`champernowne-fixed.nsv` byte for byte.

The command in `NSV_COERCE` takes `<mode> <indir> <outdir>`; mode `batch`
uses the non-resumable decoder, mode `stream` the resumable/streaming
Reader + Writer. The stream mode runs over the enum corpus, which includes
unterminated inputs (no trailing `\n\n`) that the roundtrip suite never
feeds; the `coercion-compare-stream` CI job diffs those manifests and is
**expected red** until resumable-reader EOF semantics are aligned across
implementations (today Python/JS emit the incomplete trailing row where
Java/Rust/Scala buffer it, and the JS streaming `Reader` corrupts empty
rows).

Not yet in the coercion consensus: Swift/NSVCore (no public repo for CI to
clone yet), the DuckDB extension and the CLI (neither exposes a plain batch
decode→encode).
