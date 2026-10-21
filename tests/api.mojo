# Every behaviour docs/api.md promises, checked.
from std.testing import assert_equal, assert_true, assert_false, assert_raises
from toml import parse, KIND_TABLE, KIND_ARRAY, DATETIME_OFFSET, DATETIME_LOCAL, DATE_LOCAL, TIME_LOCAL


def main() raises:
    var doc = parse("""
s = "x"
i = 7
f = 1.5
b = true
odt = 1979-05-27 07:32-07:00
ldt = 1979-05-27T07:32:00
ld = 1979-05-27
lt = 07:32
arr = [1, 2]
[[item]]
name = "first"
[[item]]
name = "second"
""")
    assert_equal(doc.keys()[0], "s")
    assert_equal(doc.keys()[8], "arr")
    assert_equal(doc.len(), 10)
    assert_equal(doc["s"].as_string(), "x")
    assert_equal(doc["i"].as_int(), 7)
    assert_equal(doc["f"].as_float(), 1.5)
    assert_true(doc["b"].as_bool())
    assert_equal(doc["odt"].as_datetime_text(), "1979-05-27 07:32:00-07:00")
    assert_equal(doc["odt"].datetime_kind(), DATETIME_OFFSET)
    assert_equal(doc["ldt"].datetime_kind(), DATETIME_LOCAL)
    assert_equal(doc["ld"].datetime_kind(), DATE_LOCAL)
    assert_equal(doc["lt"].datetime_kind(), TIME_LOCAL)
    assert_equal(doc["lt"].as_datetime_text(), "07:32:00")
    assert_equal(doc["item"][1]["name"].as_string(), "second")
    assert_equal(doc["item"].kind(), KIND_ARRAY)
    assert_equal(doc["item"][0].kind(), KIND_TABLE)
    # missing keys and wrong kinds
    assert_false(doc.get("nope").__bool__())
    assert_false(doc.contains("nope"))
    assert_false(doc["arr"].contains("x"))
    assert_false(doc["arr"].get("x").__bool__())
    assert_equal(doc["s"].len(), 0)
    assert_equal(len(doc["s"].keys()), 0)
    with assert_raises(contains="key not found"):
        _ = doc["nope"]
    with assert_raises(contains="key not found"):
        _ = doc["arr"]["x"]
    with assert_raises(contains="not an array"):
        _ = doc["s"][0]
    with assert_raises(contains="out of range"):
        _ = doc["arr"][2]
    with assert_raises(contains="out of range"):
        _ = doc["arr"][-1]
    with assert_raises(contains="not a float"):
        _ = doc["i"].as_float()
    with assert_raises(contains="not a string"):
        _ = doc["i"].as_string()
    with assert_raises(contains="duplicate key 'a' at line 2:6"):
        _ = parse("a = 1\na = 2")
    print("api: ok")
