# jupyter-ai-image

A JupyterLab image with:

- **Jupyter AI v3**, installed as `jupyter-ai[jupyternaut]` - the stock
  extension with its native LiteLLM model backend. No custom provider code,
  no external LiteLLM proxy: any of the ~1000 models LiteLLM knows about can
  be selected directly through the AI Settings UI.
- **[ai-tools-launcher](https://github.com/rickmcgeer/ai-tools-launcher)** -
  a minimal companion extension adding an "AI Tools" row to the Launcher
  with tiles for Claude Code and Codex.
- **Claude Code and Codex CLIs** (`@anthropic-ai/claude-code`,
  `@openai/codex`), installed via npm. Both are BYO-subscription - the
  image just makes them available on `PATH`; each user logs in themselves
  the first time they open a tile.

## Builtin default model

Every user gets a working default model - Gemini via Vertex AI
(`vertex_ai/gemini-2.5-flash`) - with no setup, seeded by
[`before-notebook.d/10-jupyter-ai-defaults.py`](before-notebook.d/10-jupyter-ai-defaults.py)
on container start. This just needs `GOOGLE_CLOUD_PROJECT` /
`VERTEXAI_PROJECT` / `VERTEXAI_LOCATION` set in the environment - actual
Vertex AI credentials come from GKE Workload Identity (see
[jupyter-ai-deployment](https://github.com/rickmcgeer/jupyter-ai-deployment)),
not from anything baked into this image or passed as a key file. Users can
still add their own provider key for any model through the AI Settings UI -
the builtin default coexists with, and doesn't block, a per-user key.

## Build

Requires the [`ai-tools-launcher`](https://github.com/rickmcgeer/ai-tools-launcher)
repo checked out as a sibling directory (`../ai-tools-launcher`) - the build
context is the parent directory so the Dockerfile can `COPY` it in directly,
without needing it published anywhere first.

```bash
./docker-build.sh            # builds & pushes rickmcgeer/jupyter-ai-image:<today>, native arch
PUSH=0 ./docker-build.sh dev # build only, tag "dev"

# Cross-build for a real GKE cluster (standard node pools are amd64) when
# testing/building from an arm64 (Apple Silicon) machine:
PLATFORM=linux/amd64 ./docker-build.sh dev
```
