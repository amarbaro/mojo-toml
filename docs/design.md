# Design

The parser is one pass over the input bytes into a flat pool of nodes. That layout
explains every cost: memory is the pool, lookups are indexes into it.

## Data layout

```
TomlDoc
  pool:  List[TomlNode]                  every value in the document, in parse order
  index: Dict[node, Dict[key, node]]     only for tables with more than 16 keys

TomlValue = (ArcPointer[TomlDoc], node index)
```

A `TomlNode` is 96 bytes: one `String` (string and datetime text), two lists (`kids`
holds array elements, or a table's values in the same order as `tkeys`), the integer and
float payloads, and a `UInt8` kind with the flags packed after it. A node is never both
an array and a table, which is why one `kids` list serves both.

`TomlValue` accessors borrow the node in the pool. Nothing is copied on a lookup except
the returned `String` from `as_string()` and the `List` from `keys()`.

## Key lookup

A table with up to 16 keys is searched linearly and costs no extra memory. The threshold
of 16 was chosen, not tuned: most config tables are smaller. When a table gets its 17th key, the document builds a
hash index for that table and keeps it updated. On a document with 20,000 tables in one
parent, this took parse time from 408 ms to 104 ms and cost 0.3 MB.

The index lives on the document, not on the node, so the 96-byte node does not grow and
small tables pay nothing.

## What was measured

`tests/bench.mojo` parses a 3.1 MB document with 20,000 tables of 8 keys each, then does
2,000 nested lookups. Two runs agree to within 3%.

| Change | Peak memory | Parse | Lookups |
|---|---|---|---|
| first version | 135.3 MB | 473 ms | 83 ms |
| move the pool out at the end of `parse` instead of copying it; borrow nodes in accessors instead of copying them; 152 B → 96 B node | 93.7 MB | 408 ms | 37 ms |
| hash index past 16 keys | 94.0 MB | 104 ms | 4 ms |

The remaining memory is mostly one small heap block per table for its key and value
lists, and the pool doubling its capacity as it grows.

## Conformance

`scripts/conformance.sh` is the only gate. It runs, in order:

1. [toml-test](https://github.com/toml-lang/toml-test) v2.2.0 with `-toml 1.1` through
   `tests/decoder.mojo`: 214 valid and 467 invalid documents.
2. Two wide-table checks. The suite has no table large enough to reach the index, so a
   duplicate key and a readback at 30 keys are checked separately.
3. `tests/api.mojo`: every behaviour [api.md](api.md) promises.
4. `examples/quickstart.mojo` runs.

A change that does not pass all four does not go in.
