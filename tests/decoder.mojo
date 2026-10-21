from std.ffi import c_ssize_t, external_call
from std.sys import stderr, exit
from toml import parse, to_json


def read_all_stdin() raises -> String:
    var buf = List[UInt8]()
    var chunk = List[UInt8](unsafe_uninit_length=65536)
    while True:
        var n = external_call["read", c_ssize_t](0, chunk.unsafe_ptr(), 65536)
        if n <= 0:
            break
        for i in range(Int(n)):
            buf.append(chunk[i])
    return String(from_utf8=Span[UInt8](buf))


def main():
    try:
        var text = read_all_stdin()
        var v = parse(text)
        print(to_json(v))
    except e:
        print(e, file=stderr)
        exit(1)
