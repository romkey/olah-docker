# syntax=docker/dockerfile:1
FROM python:3.13-slim-trixie AS builder

# Olah version to install from PyPI; empty installs the latest release.
ARG OLAH_VERSION=""

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Some dependencies (e.g. psutil) have no wheel for every platform, so a
# compiler is needed here; it does not end up in the final image.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# Olah still calls Starlette's pre-1.0 TemplateResponse(name, context) API,
# which Starlette 1.x removed (the index page 500s), so stay on 0.x.
RUN python -m venv /opt/olah
# hadolint ignore=DL3013
RUN /opt/olah/bin/pip install "olah${OLAH_VERSION:+==${OLAH_VERSION}}" "starlette<1"

# The PyPI package omits olah/static (the web UI templates), so the index page
# fails with "template not found". Fetch them from the matching GitHub tag.
RUN /opt/olah/bin/python - <<'PY'
import io, tarfile, urllib.request
from importlib.metadata import version
import olah, os

v = version("olah")
url = f"https://github.com/vtuber-plan/olah/archive/refs/tags/v{v}.tar.gz"
dest = os.path.dirname(olah.__file__)
with urllib.request.urlopen(url) as r, tarfile.open(fileobj=io.BytesIO(r.read())) as tar:
    prefix = f"olah-{v}/src/olah/static/"
    members = [m for m in tar.getmembers() if m.name.startswith(prefix)]
    assert members, f"no static files found in {url}"
    for m in members:
        m.name = "static/" + m.name[len(prefix):]
    tar.extractall(dest, members=members, filter="data")
PY

FROM python:3.13-slim-trixie

ENV PYTHONUNBUFFERED=1 \
    PATH="/opt/olah/bin:$PATH"

# git is required by Olah (GitPython); the rest are debugging tools.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bind9-dnsutils \
        bind9-host \
        ca-certificates \
        curl \
        git \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/olah /opt/olah

RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin olah \
    && mkdir /data \
    && chown olah:olah /data

USER olah
WORKDIR /data
VOLUME /data
EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD nc -z localhost 8090 || exit 1

CMD ["olah-cli", "--host", "0.0.0.0", "--port", "8090", "--repos-path", "/data/repos", "--log-path", "/data/logs"]
