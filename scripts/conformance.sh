#!/usr/bin/env bash
# Build the decoder and run toml-test (TOML 1.1). TOML_TEST = path to the toml-test binary.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TOML_TEST:?FAIL setup: set TOML_TEST to the toml-test v2 binary}"
mkdir -p .work
.venv/bin/mojo build -I src tests/decoder.mojo -o .work/decoder || { echo "FAIL build: decoder"; exit 1; }
"$TOML_TEST" test -toml 1.1 -decoder ./.work/decoder -timeout 5s || { echo "FAIL conformance: toml-test 1.1"; exit 1; }
# wide tables go through the hash index (more than INDEX_AT = 16 keys)
wide=$(for i in $(seq 0 29); do echo "k$i = $i"; done)
printf '%s\nk19 = 0\n' "$wide" | ./.work/decoder >/dev/null 2>&1 && { echo "FAIL wide: duplicate key past the index threshold accepted"; exit 1; }
printf '%s\n' "$wide" | ./.work/decoder | grep -q '"k29":{"type":"integer","value":"29"}' || { echo "FAIL wide: k29 lost in indexed table"; exit 1; }
echo "wide tables: ok"
.venv/bin/mojo run -I src tests/api.mojo || { echo "FAIL api: tests/api.mojo"; exit 1; }
.venv/bin/mojo run -I src examples/quickstart.mojo >/dev/null || { echo "FAIL example: examples/quickstart.mojo"; exit 1; }
echo "PASS all"
