#!/usr/bin/env bash
# CI entry point, same on a GitHub runner and a local Ubuntu VM: install, fetch toml-test, run the gate.
set -euo pipefail
cd "$(dirname "$0")/.."
TOML_TEST_VERSION=v2.2.0
command -v uv >/dev/null || { echo "FAIL setup: uv not installed"; exit 1; }
uv sync || { echo "FAIL setup: uv sync"; exit 1; }
mkdir -p .work
bin=.work/toml-test
if [ ! -x "$bin" ]; then
  curl -fsSL "https://github.com/toml-lang/toml-test/releases/download/$TOML_TEST_VERSION/toml-test-$TOML_TEST_VERSION-linux-amd64.gz" \
    | gunzip > "$bin" || { echo "FAIL setup: download toml-test"; exit 1; }
  chmod +x "$bin"
fi
TOML_TEST="$PWD/$bin" scripts/conformance.sh
