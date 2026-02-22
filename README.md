# nsv-tests

NSV testing infrastructure.

## Fixtures

See [`fixtures/README.md`](fixtures/README.md).

## Conformance action

Roundtrip-test an NSV implementation against the canonical fixture set.

```yaml
- uses: nsv-format/nsv-tests@v1
  with:
    decode: 'python3 -c "..."'
    encode: 'python3 -c "..."'
```

Both commands are stdin→stdout byte filters.  The intermediate format
between decode and encode is opaque to the test runner — the only
property checked is `encode(decode(fixture)) == fixture`.

| Input    | Required | Default | Description |
|----------|----------|---------|-------------|
| `decode` | yes      | —       | Reads NSV bytes from stdin, writes decoded form to stdout |
| `encode` | yes      | —       | Reads decoded form from stdin, writes NSV bytes to stdout |
| `stress` | no       | `false` | Include the 93 MB Champernowne stress test |

Pin to a tag (`@v1`, `@v1.0.0`) or a commit SHA.  Floating on `@v1`
picks up new fixtures automatically.
