FROM quay.io/jupyter/minimal-notebook:python-3.11

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Node.js 22 + AI coding CLIs (BYO subscription - users log in themselves on
# first use). Newer CLI releases assume Node >=22, which conda's own nodejs
# package can't provide without forcing a full env re-solve, so install a
# standalone binary and swap it onto PATH instead.
RUN NODE_VERSION=22.12.0 && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" -o /tmp/node.tar.gz && \
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

# Jupyter AI (native LiteLLM backend, no external proxy) + the AI Tools
# launcher extension (Claude Code / Codex launcher tiles). ai_tools_launcher
# isn't on PyPI yet - swap this for a local `pip install /path/to/repo` (via
# a bind-mounted build context) while iterating on it before its first
# GitHub push.
RUN pip install --no-cache-dir \
    "jupyter-ai[jupyternaut]" \
    google-cloud-aiplatform \
    "git+https://github.com/rickmcgeer/ai-tools-launcher.git"

# Seeds a default model (Gemini via Vertex AI) into every user's Jupyter AI
# config on container start, so chat works with no setup. See the script for
# details; the mounted GCP credentials it relies on are set up in the
# deployment, not here - see README "Builtin key" section.
COPY before-notebook.d/10-jupyter-ai-defaults.py /usr/local/bin/before-notebook.d/10-jupyter-ai-defaults.py
RUN chmod +x /usr/local/bin/before-notebook.d/10-jupyter-ai-defaults.py

ARG BUILD_DATE=unknown
RUN echo "${BUILD_DATE}" > /srv/build.txt

USER ${NB_UID}

CMD ["start-notebook.sh"]
