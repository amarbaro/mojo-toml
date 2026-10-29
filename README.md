# mojo-toml

[![CI](https://github.com/amarbaro/mojo-toml/actions/workflows/ci.yml/badge.svg)](https://github.com/amarbaro/mojo-toml/actions/workflows/ci.yml)

A TOML 1.1 parser written in pure Mojo. It passes the complete official
conformance suite, [toml-test](https://github.com/toml-lang/toml-test) v2.2.0:
**214/214 valid and 467/467 invalid** documents, on Mojo 1.1.0 and on the 1.2 nightly.

```mojo
from toml import parse

def main() raises:
    var doc = parse(open("config.toml", "r").read())
    var server = doc["server"]
    print(server["host"].as_string(), server["port"].as_int())
```

## Install

Requires Mojo 1.2 (`pip install "mojo>=1.1.0,<1.2"` or `uv sync` in this repo).
There is no package registry for Mojo yet, so pick one:

| Way | Command |
|---|---|
| Source path | `mojo run -I path/to/mojo-toml/src app.mojo` |
| Precompiled | `mojo precompile src/toml -o toml.mojoc`, then put `toml.mojoc` next to your code or in a `-I` dir |
| Vendor | copy `src/toml/` into your project |

## What you get

- **Every TOML type**: strings (all four kinds, every escape), integers in decimal, hex,
  octal and binary, floats including `inf` and `nan`, booleans, the four datetime kinds,
  arrays, tables, inline tables, arrays of tables, dotted keys.
- **TOML 1.1 additions**: optional seconds (`07:32`), the `\e` and `\xHH` escapes,
  newlines, comments and trailing commas inside inline tables.
- **Errors with positions**: `toml: duplicate key 'a' at line 2:6`. Every invalid document
  in the suite is rejected, including bad UTF-8, redefined tables and out-of-range dates.
- **Typed accessors** that raise on a type mismatch instead of returning garbage.

The API is in [docs/api.md](docs/api.md). How it works and what it costs is in
[docs/design.md](docs/design.md).

## Performance

`tests/bench.mojo`: a 3.1 MB document with 20,000 tables, on a Ryzen 7 7800X3D.

| | |
|---|---|
| parse | 104 ms |
| 2,000 nested lookups | 4 ms |
| peak memory | 94 MB |

## Limits

- **Parse only.** There is no encoder. `to_json` writes the toml-test tagged JSON format,
  which is useful for debugging but is not a TOML writer.
- **Datetimes stay as text.** You get the string as written (with `:00` filled in when
  seconds were left out) and its kind, not a date object.
- **Integers are `Int64`.** Values outside its range are rejected, as the spec requires.
- **Whole document in memory.** No streaming parser.
- **No strict TOML 1.0 mode.** 1.0 documents parse, and the 1.1 additions above are
  always accepted.

## Conformance check

```
scripts/ci.sh
```

It runs `uv sync`, downloads toml-test v2.2.0, then `scripts/conformance.sh`. CI runs the
same script on every push.

It builds `tests/decoder.mojo` (TOML on stdin, tagged JSON on stdout), runs the full
toml-test 1.1 suite, then two checks for tables wide enough to use the key index.

## For coding agents

[skills/mojo-toml/SKILL.md](skills/mojo-toml/SKILL.md) is a skill file that tells an agent how
to use this library correctly: install, the accessor rules, error handling and the traps.

## Licence

Apache-2.0, see [LICENSE](LICENSE).
