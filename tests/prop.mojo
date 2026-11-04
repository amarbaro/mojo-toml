# Property smoke step: parse never crashes. On random TOML-ish text and on random bytes it parses or raises.
from proptest import check, Lists, Strings, Byte
from toml import parse


def text(s: String) raises -> Bool:
    try:
        _ = parse(s)
    except:
        pass
    return True


def raw(b: List[UInt8]) raises -> Bool:
    return text(String(unsafe_from_utf8=Span(b)))   # invalid UTF-8 included: the parser must raise, not read past the end


def main() raises:
    var pool: List[String] = ["a", " ", "=", "[", "]", "{", "}", '"', "'", "\n", "#", "1", ".", "-", ":", ",", "é", "\\", "\"\"\"", "0x", "e"]
    check(Strings(40, pool^), text, n=3000)
    check(Lists(Byte(), 40), raw, n=3000)
    print("prop: ok")
