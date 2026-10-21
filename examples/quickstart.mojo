from toml import parse, to_json, KIND_TABLE


def main() raises:
    var doc = parse("""
title = "demo"
[server]
host = "localhost"
port = 8080
ratio = 0.75
debug = true
started = 1979-05-27T07:32:00Z
tags = ["a", "b"]
""")
    var server = doc["server"]
    print(server["host"].as_string(), server["port"].as_int())
    print(server["ratio"].as_float(), server["debug"].as_bool())
    print(server["started"].as_datetime_text(), server["tags"].len(), server["tags"][1].as_string())
    print(doc.contains("title"), doc.get("missing").__bool__(), server.kind() == KIND_TABLE)
    for k in server.keys():
        print("key", k)
    print(to_json(doc["title"]))
    try:
        _ = parse("a = 1\na = 2")
    except e:
        print("error:", e)
