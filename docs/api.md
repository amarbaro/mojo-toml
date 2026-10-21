# API

Everything is exported from the `toml` package.

```mojo
from toml import parse, to_json, TomlValue, KIND_TABLE, DATETIME_OFFSET
```

## `parse(text: String) raises -> TomlValue`

Parses a whole document and returns the root table. It raises `Error` on any invalid
input, with a message of the form `toml: <what> at line <line>:<column>`.

```mojo
try:
    var doc = parse(text)
except e:
    print(e)  # toml: duplicate key 'a' at line 2:6
```

## `TomlValue`

A handle to one value in a parsed document. It holds a reference-counted pointer to
the document and an index, so it is cheap to copy and keeps the document alive.
Handles never change: the document is read-only after `parse`.

### Navigate

| Method | Returns | On the wrong kind |
|---|---|---|
| `v["key"]` | the value at `key` in a table | raises `key not found` (also on a non-table) |
| `v.get("key")` | `Optional[TomlValue]`, `None` when missing | `None` |
| `v.contains("key")` | `Bool` | `False` |
| `v[i]` | element `i` of an array | raises `not an array` / `index out of range` |
| `v.len()` | number of keys (table) or elements (array) | `0` |
| `v.keys()` | `List[String]` of a table's keys, in document order | empty list |

An array of tables (`[[item]]`) is an array whose elements are tables:
`doc["item"][0]["name"]`.

### Read a value

| Method | Returns | Kind |
|---|---|---|
| `as_string()` | `String` | `KIND_STRING` |
| `as_int()` | `Int64` | `KIND_INTEGER` |
| `as_float()` | `Float64` | `KIND_FLOAT` |
| `as_bool()` | `Bool` | `KIND_BOOL` |
| `as_datetime_text()` | `String`, as written, `:00` added when seconds are omitted | `KIND_DATETIME` |
| `datetime_kind()` | `UInt8`, one of the four constants below | `KIND_DATETIME` |

Each one raises `toml: value is not a <type>` when the value has another kind.
An integer is not read by `as_float()`: check `is_integer()` first if a field may be either.

### Check the kind

`kind() -> UInt8` returns one of `KIND_STRING`, `KIND_INTEGER`, `KIND_FLOAT`, `KIND_BOOL`,
`KIND_DATETIME`, `KIND_ARRAY`, `KIND_TABLE`. The shortcuts are `is_string()`,
`is_integer()`, `is_float()`, `is_bool()`, `is_datetime()`, `is_array()`, `is_table()`.

Datetime kinds:

| Constant | Example |
|---|---|
| `DATETIME_OFFSET` | `1979-05-27T07:32:00Z`, `1979-05-27 07:32:00-07:00` |
| `DATETIME_LOCAL` | `1979-05-27T07:32:00` |
| `DATE_LOCAL` | `1979-05-27` |
| `TIME_LOCAL` | `07:32:00` |

## `to_json(v: TomlValue) raises -> String`

Writes `v` in the [toml-test](https://github.com/toml-lang/toml-test) tagged JSON format,
where every leaf is `{"type": ..., "value": ...}`. It is what the conformance decoder
prints. Use it to debug or to compare with another parser, not as a general JSON export.
