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


def json_escape(s: String) raises -> String:
    var out: List[UInt8] = []
    var b = s.as_bytes()
    for i in range(len(b)):
        var c = b[i]
        if c == 34:
            out.append(92)
            out.append(34)
        elif c == 92:
            out.append(92)
            out.append(92)
        elif c == 10:
            out.append(92)
            out.append(UInt8(110))
        elif c == 13:
            out.append(92)
            out.append(UInt8(114))
        elif c == 9:
            out.append(92)
            out.append(UInt8(116))
        elif c == 8:
            out.append(92)
            out.append(UInt8(98))
        elif c == 12:
            out.append(92)
            out.append(UInt8(102))
        elif c < 0x20 or c == 0x7F:
            var hexdigits = "0123456789abcdef"
            var hb = hexdigits.as_bytes()
            out.append(92)
            out.append(UInt8(117))
            out.append(48)
            out.append(48)
            out.append(hb[Int(c) // 16])
            out.append(hb[Int(c) % 16])
        else:
            out.append(c)
    return String(from_utf8=Span(out))


def to_json(v: TomlValue) raises -> String:
    var k = v.kind()
    if k == KIND_TABLE:
        var out = String("{")
        var keys = v.keys()
        for i in range(len(keys)):
            if i > 0:
                out += ","
            out += '"' + json_escape(keys[i]) + '":'
            out += to_json(v[keys[i]])
        out += "}"
        return out^
    if k == KIND_ARRAY:
        var out = String("[")
        for i in range(v.len()):
            if i > 0:
                out += ","
            out += to_json(v[i])
        out += "]"
        return out^

    var type_tag: String
    var value_text: String
    if k == KIND_STRING:
        type_tag = "string"
        value_text = json_escape(v.as_string())
    elif k == KIND_INTEGER:
        type_tag = "integer"
        value_text = String(v.as_int())
    elif k == KIND_FLOAT:
        type_tag = "float"
        value_text = String(v.as_float())
    elif k == KIND_BOOL:
        type_tag = "bool"
        value_text = "true" if v.as_bool() else "false"
    else:
        var dk = v.datetime_kind()
        if dk == DATETIME_OFFSET:
            type_tag = "datetime"
        elif dk == DATETIME_LOCAL:
            type_tag = "datetime-local"
        elif dk == DATE_LOCAL:
            type_tag = "date-local"
        else:
            type_tag = "time-local"
        value_text = json_escape(v.as_datetime_text())
    return '{"type":"' + type_tag + '","value":"' + value_text + '"}'
