from toml import parse


def main() raises:
    var doc = parse("""
[server]
host = "localhost"
port = 8080
""")
    var server = doc["server"]
    print(server["host"].as_string(), server["port"].as_int())
