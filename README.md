# olah-docker

[![CI](https://github.com/romkey/olah-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/romkey/olah-docker/actions/workflows/ci.yml)
[![Release](https://github.com/romkey/olah-docker/actions/workflows/release.yml/badge.svg)](https://github.com/romkey/olah-docker/actions/workflows/release.yml)
[![Olah on PyPI](https://img.shields.io/pypi/v/olah?label=olah&logo=pypi&logoColor=white)](https://pypi.org/project/olah/)
[![Image](https://img.shields.io/badge/ghcr.io-romkey%2Folah--docker-blue?logo=docker&logoColor=white)](https://github.com/romkey/olah-docker/pkgs/container/olah-docker)
[![Last commit](https://img.shields.io/github/last-commit/romkey/olah-docker)](https://github.com/romkey/olah-docker/commits/main)

Docker image for [Olah](https://github.com/vtuber-plan/olah), a self-hosted Hugging Face mirror/proxy.
A GitHub Action checks PyPI daily for a new Olah release and publishes a new image when one appears.

## AI disclosure

This project was written with AI assistance (Claude) under human supervision.

## Usage

```bash
docker run -p 8090:8090 -v olah-data:/data ghcr.io/romkey/olah-docker:latest
```

Tags:

| Tag | Meaning |
| --- | --- |
| `latest` | Newest Olah release |
| `X.Y.Z` | Specific Olah version (e.g. `0.5.1`) |
| `X.Y` | Newest patch release of that minor version |

Images are multi-arch (`linux/amd64`, `linux/arm64`) and ship with SBOM and provenance attestations.

- Base: `python:3.13-slim-trixie` (Debian), runs as non-root user `olah`.
- Cached repos and logs live under the `/data` volume.
- The server listens on `0.0.0.0:8090`. Override by passing your own command, e.g. `olah-cli --config /data/olah.toml`.
- Debugging tools included: `ping`, `host`, `dig`, `nc`, `curl`, `ip`, `ps`.

```bash
docker run --rm ghcr.io/romkey/olah-docker:latest dig huggingface.co
```

## Docker Compose

[`compose.example.yaml`](compose.example.yaml) is a ready-to-use starting point:

```bash
docker compose -f compose.example.yaml up -d
```

Olah is configured with command-line flags (or a `--config` file), so the example overrides `command`. Things to adjust:

- `--mirror-netloc` / `--mirror-lfs-netloc`: set these to the `host:port` your clients use to reach Olah (e.g. `olah.example.com:8090`), and `--mirror-scheme` to `http` or `https`.
- `--cache-size-limit`: uncomment to cap the cache size (e.g. `100GB`).
- `image`: pin a version tag such as `0.5.1` instead of `latest` for reproducible deploys.

Point Hugging Face clients at it with `HF_ENDPOINT`:

```bash
HF_ENDPOINT=http://localhost:8090 huggingface-cli download gpt2
```

The cache lives in the `olah-data` volume. If you replace `command`, keep `--host=0.0.0.0` or the server won't be reachable from outside the container.

## How the build works

- **Release** (daily): compares PyPI's latest Olah version with the tags in GHCR and builds if it's new.
- **Weekly rebuild**: republishes the current version to pick up base-image security fixes.
- Every build is smoke-tested and scanned with Trivy (results in the Security tab; fixable CRITICAL vulnerabilities fail the build).
- **CI** lints the Dockerfile (hadolint), workflows (actionlint) and scripts (shellcheck), then builds, tests and scans on every PR.
- A keep-alive step stops GitHub from disabling the schedule after 60 days of inactivity.
- Dependabot keeps actions and the base image current.
