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

## Builtin key (TBD)

Every user gets a working default model - Gemini via Vertex AI
(`vertex_ai/gemini-2.0-flash-001`) - with no setup, seeded by
[`before-notebook.d/10-jupyter-ai-defaults.py`](before-notebook.d/10-jupyter-ai-defaults.py)
on container start. This only works once the deployment supplies:

- `GOOGLE_APPLICATION_CREDENTIALS` - path to a mounted GCP service-account
  key with Vertex AI access
- `GOOGLE_CLOUD_PROJECT` / `VERTEXAI_PROJECT` / `VERTEXAI_LOCATION` - the
  target GCP project and region

None of that is baked into the image - how the shared key gets provisioned
and mounted (Kubernetes secret, `.env`, something else) is still an open
question, decided per-deployment. Until it's wired up, users can still add
their own provider key for any model through the AI Settings UI - the
builtin default coexists with, and doesn't block, a per-user key.

## Build

```bash
./docker-build.sh            # builds & pushes rickmcgeer/jupyter-ai-image:<today>
PUSH=0 ./docker-build.sh dev # build only, tag "dev"
```

## Before this builds

`ai_tools_launcher` isn't published to PyPI - the Dockerfile installs it
straight from GitHub, so [`ai-tools-launcher`](https://github.com/rickmcgeer/ai-tools-launcher)
needs to be pushed there first. For local iteration before that, swap the
`pip install` line in the [Dockerfile](Dockerfile) for a bind-mounted local
install instead.
