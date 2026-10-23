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
    @google/gemini-cli \
    && npm cache clean --force

# codex's sandboxing wants bubblewrap; without it, it just falls back to a
# bundled copy with a harmless warning, but the system package is better
# maintained than trusting the bundled fallback indefinitely.
RUN apt-get update && apt-get install -y --no-install-recommends bubblewrap \
    && rm -rf /var/lib/apt/lists/*

# Grok Build (xAI's coding agent CLI) - BYO subscription, same as Claude Code
# and Codex above. The installer defaults to $HOME/.grok/bin + editing shell
# rc files, both keyed off whatever $HOME is active when it runs (/root
# during this build) - useless for jovyan at runtime. GROK_BIN_DIR points it
# at /opt/conda/bin instead, same fix as the Node 22 binaries above: already
# on PATH for every user regardless of $HOME.
RUN curl -fsSL https://x.ai/cli/install.sh | GROK_BIN_DIR=/opt/conda/bin bash

# Jupyter AI (native LiteLLM backend, no external proxy). `notebook` is
# pinned alongside it, in the same resolve, because jupyter-ai[jupyternaut]
# pulls in a jupyterlab newer than the base image's pinned notebook 7.2.2
# supports - installing them together instead of letting notebook's old
# pin dangle avoids a broken (but silent) dependency conflict.
RUN pip install --no-cache-dir \
    "jupyter-ai[jupyternaut]" \
    "notebook>=7.3" \
    google-cloud-aiplatform

# BearBorg persona (source: engageLively/galyleo-deployment's
# galyleo-ai-persona package, same LiteLLM/Vertex AI backend as Jupyternaut
# above but with a curated, brandable model list instead of Jupyternaut's
# unfiltered ~1000+ model picker) - kept *alongside* Jupyternaut, not
# replacing it (Rick's call: Berkeley wants both available). Wheel built
# fresh from that repo and passed in via build arg, not committed to git -
# same pattern as galyleo-deployment's own Dockerfile.base.
ARG GALYLEO_PERSONA_WHEEL
COPY jupyter-ai-image/${GALYLEO_PERSONA_WHEEL} /tmp/
RUN pip install --no-cache-dir "/tmp/${GALYLEO_PERSONA_WHEEL}" && \
    rm "/tmp/${GALYLEO_PERSONA_WHEEL}"

# The searchable-model-picker + toolbar-flicker fixes engageLively forked
# jupyter_ai_persona_manager for (PRs #115/#116) are upstream now - #116
# merged into main 2026-08-18, #115 closed the same day as redundant (its
# commits were already folded into #116). First stock release carrying it
# was 0.1.3 (also 2026-08-18); current 0.2.2 is well past that point.
# Verified 2026-09-30 by content, not just merge status: searchable-picker
# code is present in upstream main's src/persona-controls.tsx. No fork
# install needed - jupyter-ai[jupyternaut] resolves a compatible stock
# version on its own.

# The installed labextension's settings schema (title/description) is a
# static file baked in at build time, but GALYLEO_PERSONA_NAME is meant to
# be deploy-time/no-rebuild ("BearBorg" here) - before-notebook.d hook below
# rewrites this one file from that env var on every pod start. Needs to be
# writable by $NB_UID since before-notebook.d hooks run as that user, not
# root. See galyleo-deployment/setup-ai.md's "Per-hub branding" section for
# the full reasoning - this mirrors it exactly.
RUN fix-permissions "/opt/conda/share/jupyter/labextensions/galyleo-ai-persona"

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

# Keeps the BearBorg persona's Settings Editor title in sync with
# GALYLEO_PERSONA_NAME - see the fix-permissions call above this file's own
# comment for why this needs to be a separate hook rather than baked in.
COPY jupyter-ai-image/before-notebook.d/12-galyleo-persona-settings-schema.py /usr/local/bin/before-notebook.d/12-galyleo-persona-settings-schema.py
RUN chmod +x /usr/local/bin/before-notebook.d/12-galyleo-persona-settings-schema.py

ARG BUILD_DATE=unknown
RUN echo "${BUILD_DATE}" > /srv/build.txt

USER ${NB_UID}

CMD ["start-notebook.sh"]
