# Parse + access bench: N tables of 8 keys each; prints node size, parse ms, lookup ms.
from std.sys import size_of
from std.time import perf_counter_ns
from toml import parse
from toml.value import TomlNode


def main() raises:
    comptime N = 20000
    var text = String()
    for t in range(N):
        text += "[t" + String(t) + "]\nname = \"node " + String(t) + "\"\nport = " + String(t)
        text += "\nratio = 0.5\non = true\nwhen = 1979-05-27T07:32:00Z\ntags = [\"a\", \"b\", \"c\"]\n"
        text += "inline = { x = 1, y = 2 }\nnote = 'literal'\n"
    var t0 = perf_counter_ns()
    var root = parse(text)
    var t1 = perf_counter_ns()
    var sum: Int64 = 0
    for t in range(0, N, 10):
        var tbl = root["t" + String(t)]
        sum += tbl["port"].as_int() + Int64(tbl.len()) + Int64(tbl["tags"].len())
    var t2 = perf_counter_ns()
    print("bytes", text.byte_length(), "node_B", size_of[TomlNode]())
    print("parse_ms", (t1 - t0) // 1000000, "lookup_ms", (t2 - t1) // 1000000, "check", sum)
