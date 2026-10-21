from toml.value import (
    TomlValue,
    KIND_STRING,
    KIND_INTEGER,
    KIND_FLOAT,
    KIND_BOOL,
    KIND_DATETIME,
    KIND_ARRAY,
    KIND_TABLE,
    DATETIME_OFFSET,
    DATETIME_LOCAL,
    DATE_LOCAL,
    TIME_LOCAL,
)
from toml.parser import parse
from toml.json import to_json
