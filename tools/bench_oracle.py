"""Same work as tests/bench.mojo with Python tomllib: same generated text, parse once, the same lookups and check."""
import time, tomllib
N = 20000
text = "".join(f'[t{t}]\nname = "node {t}"\nport = {t}\nratio = 0.5\non = true\nwhen = 1979-05-27T07:32:00Z\n'
               f'tags = ["a", "b", "c"]\ninline = {{ x = 1, y = 2 }}\nnote = \'literal\'\n' for t in range(N))
t0 = time.perf_counter_ns(); root = tomllib.loads(text); t1 = time.perf_counter_ns()
s = sum(root[f"t{t}"]["port"] + len(root[f"t{t}"]) + len(root[f"t{t}"]["tags"]) for t in range(0, N, 10))
t2 = time.perf_counter_ns()
print("bytes", len(text.encode()), "parse_ms", (t1 - t0) // 1000000, "lookup_ms", (t2 - t1) // 1000000, "check", s)
