#!/usr/bin/env bash
# Smoke-test an Olah image: tools present, CLI works, server answers HTTP.
# Usage: smoke-test.sh IMAGE [EXPECTED_OLAH_VERSION]
set -euo pipefail

image=${1:?usage: smoke-test.sh IMAGE [EXPECTED_OLAH_VERSION]}
expected=${2:-}

for tool in ping host dig nc curl git; do
    docker run --rm "$image" sh -c "command -v $tool" >/dev/null \
        || { echo "missing tool: $tool"; exit 1; }
done

docker run --rm "$image" olah-cli --help >/dev/null

if [[ -n "$expected" ]]; then
    actual=$(docker run --rm "$image" python -c 'from importlib.metadata import version; print(version("olah"))')
    [[ "$actual" == "$expected" ]] || { echo "version mismatch: got $actual, want $expected"; exit 1; }
fi

cid=$(docker run -d -p 8090:8090 "$image")
trap 'docker logs "$cid" || true; docker rm -f "$cid" >/dev/null' EXIT

for _ in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/ || true)
    if [[ "$code" == "200" ]]; then
        echo "server answered HTTP $code"
        exit 0
    fi
    sleep 1
done

echo "server did not return HTTP 200 within 30s (last status: ${code:-none})"
exit 1
