# nsv-tests

NSV testing infrastructure.

## Fixtures

See [`fixtures/README.md`](fixtures/README.md).

## Conformance action

Roundtrip-test an NSV implementation against the canonical fixture set.

```yaml
- uses: nsv-format/nsv-tests@v1
  with:
    roundtrip: 'python3 -c "import sys, nsv; sys.stdout.write(nsv.dumps(nsv.loads(sys.stdin.read())))"'
```

Or with separate decode and encode commands:

```yaml
- uses: nsv-format/nsv-tests@v1
  with:
    decode: 'python3 -c "..."'
    encode: 'python3 -c "..."'
```

All commands are stdin→stdout byte filters.  When using `roundtrip`,
the single command reads NSV and writes NSV — no intermediate format
needed.  When using `decode`+`encode`, the intermediate format between
them is opaque to the test runner; the only property checked is
`encode(decode(fixture)) == fixture`.

| Input       | Required            | Default | Description |
|-------------|---------------------|---------|-------------|
| `roundtrip` | yes (or decode+encode) | —    | Reads NSV from stdin, writes NSV to stdout |
| `decode`    | yes (or roundtrip)  | —       | Reads NSV from stdin, writes decoded form to stdout |
| `encode`    | yes (or roundtrip)  | —       | Reads decoded form from stdin, writes NSV to stdout |
| `stress`    | no                  | `false` | Include the 93 MB Champernowne stress test |

Pin to a tag (`@v1`, `@v1.0.0`) or a commit SHA.  Floating on `@v1`
picks up new fixtures automatically.
