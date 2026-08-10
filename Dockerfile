FROM quay.io/jupyter/minimal-notebook:python-3.11

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Node.js 22 + AI coding CLIs (BYO subscription - users log in themselves on
# first use). Newer CLI releases assume Node >=22, which conda's own nodejs
# package can't provide without forcing a full env re-solve, so install a
# standalone binary and swap it onto PATH instead. Architecture-detected
# (unlike coreshell's Dockerfile, this image has no amd64-only .deb
# dependency forcing a single platform) so it builds natively on both
# amd64 and arm64 hosts.
RUN NODE_VERSION=22.12.0 && \
    case "$(dpkg --print-architecture)" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz" -o /tmp/node.tar.gz && \
    mkdir -p /opt/node22 && \
    tar -xzf /tmp/node.tar.gz -C /opt/node22 --strip-components=1 && \
    rm /tmp/node.tar.gz && \
    for f in /opt/node22/bin/*; do ln -sf "$f" "/opt/conda/bin/$(basename "$f")"; done

# Must be explicit: npm auto-detects its install prefix from the swapped-in
# node/npm binaries' real path (/opt/node22), not the /opt/conda symlink -
# without this, `npm install -g` silently places executables off PATH.
ENV NPM_CONFIG_PREFIX=/opt/conda

RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    && npm cache clean --force

# codex's sandboxing wants bubblewrap; without it, it just falls back to a
# bundled copy with a harmless warning, but the system package is better
# maintained than trusting the bundled fallback indefinitely.
RUN apt-get update && apt-get install -y --no-install-recommends bubblewrap \
    && rm -rf /var/lib/apt/lists/*

# Jupyter AI (native LiteLLM backend, no external proxy). `notebook` is
# pinned alongside it, in the same resolve, because jupyter-ai[jupyternaut]
# pulls in a jupyterlab newer than the base image's pinned notebook 7.2.2
# supports - installing them together instead of letting notebook's old
# pin dangle avoids a broken (but silent) dependency conflict.
RUN pip install --no-cache-dir \
    "jupyter-ai[jupyternaut]" \
    "notebook>=7.3" \
    google-cloud-aiplatform

# AI Tools launcher (Claude Code / Codex launcher tiles) - installed from the
# sibling repo, not PyPI (not published there). The build context is this
# repo's parent directory (see docker-build.sh) so both repos build in
# lockstep without needing ai-tools-launcher pushed to GitHub first.
COPY ai-tools-launcher /tmp/ai-tools-launcher
RUN pip install --no-cache-dir /tmp/ai-tools-launcher && rm -rf /tmp/ai-tools-launcher

# Seeds a default model (Gemini via Vertex AI) into every user's Jupyter AI
# config on container start, so chat works with no setup. See the script for
# details; the mounted GCP credentials it relies on are set up in the
# deployment, not here - see README "Builtin key" section.
COPY jupyter-ai-image/before-notebook.d/10-jupyter-ai-defaults.py /usr/local/bin/before-notebook.d/10-jupyter-ai-defaults.py
RUN chmod +x /usr/local/bin/before-notebook.d/10-jupyter-ai-defaults.py

ARG BUILD_DATE=unknown
RUN echo "${BUILD_DATE}" > /srv/build.txt

USER ${NB_UID}

CMD ["start-notebook.sh"]
