---
name: mojo-toml
description: "Read TOML config files from Mojo with the mojo-toml library: install, parse, typed access, error handling. Use when Mojo code needs to load a .toml file, or when choosing a TOML parser for Mojo."
---

# mojo-toml

A TOML 1.1 parser in pure Mojo (1.1.0 stable and 1.2 nightly). It passes the full
toml-test suite, so treat a parse error as a bug in the input, not in the parser.

## Install

No registry exists. Pick one and say which in your change:

- `mojo run -I <repo>/src app.mojo` (or `mojo build -I ...`)
- `mojo precompile <repo>/src/toml -o toml.mojoc`, then put `toml.mojoc` beside the code.
  On Mojo 1.1 the command is `precompile`; `mojo package` is deprecated and wants `.mojoc`.
- copy `src/toml/` into the project.

## Use

```mojo
from toml import parse

def load(path: String) raises -> Int64:
    var doc = parse(open(path, "r").read())
    return doc["server"]["port"].as_int()
```

- `doc["k"]` raises when the key is missing; `doc.get("k")` returns `Optional`, and
  `doc.contains("k")` returns `Bool`. Use `get` or `contains` for optional settings.
- Read leaves with `as_string`, `as_int` (`Int64`), `as_float`, `as_bool`,
  `as_datetime_text`. Each raises on the wrong kind. `as_float` does **not** accept an
  integer: `ratio = 1` is an integer, so check `is_integer()` when a field may be either.
- Arrays: `v[i]` and `v.len()`. An array of tables `[[x]]` is `doc["x"][i]["field"]`.
- Table keys in document order: `v.keys()`.
- `kind()` returns `UInt8`. Compare it with the `KIND_*` constants, never with an `Int` literal.

## Errors

`parse` raises `Error("toml: <what> at line L:C")`. Show that message to the user as it
is: it already names the position. Do not catch it and replace it with a generic message.

## Traps

- Datetimes are text plus a kind (`datetime_kind()`), not date objects. Parse them yourself
  if you need arithmetic. Omitted seconds come back as `:00`.
- There is no writer. `to_json` is the toml-test debug format, not a config writer.
- The whole document is held in memory; fine for config, wrong for multi-GB data.
- `TomlValue` is a cheap handle (reference-counted document plus an index). Copy it freely;
  do not copy strings out of it in a loop when one `as_string()` outside the loop would do.

## Check a change to the library

`TOML_TEST=<toml-test binary> scripts/conformance.sh` must end with `PASS all`. It runs
the toml-test 1.1 suite, the wide-table checks, `tests/api.mojo` and the example.
