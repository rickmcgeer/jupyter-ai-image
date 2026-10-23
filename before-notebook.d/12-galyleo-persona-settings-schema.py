#!/usr/bin/env python3
"""Rewrite the BearBorg persona's Settings Editor title/description from
GALYLEO_PERSONA_NAME on every container start.

The labextension's schema/plugin.json (title/description shown in
JupyterLab's Advanced Settings Editor) is a static file baked in at image
build time, but GALYLEO_PERSONA_NAME is meant to be deploy-time/no-rebuild -
see galyleo-deployment/setup-ai.md's "Per-hub branding" section for the
full design reasoning (this hook is a straight port of that one).

Unlike 10-jupyter-ai-defaults.py above, this is *not* idempotent-once: this
is a single shared file per pod, not a per-user seed, so there's no existing
user customization to protect, and always resyncing to the env var is
strictly more correct.
"""
import json
import os

SCHEMA_PATH = (
    "/opt/conda/share/jupyter/labextensions/galyleo-ai-persona/"
    "schemas/galyleo-ai-persona/plugin.json"
)
PERSONA_NAME = os.environ.get("GALYLEO_PERSONA_NAME") or "Galyleo"

if not os.path.exists(SCHEMA_PATH):
    raise SystemExit(0)

with open(SCHEMA_PATH) as f:
    schema = json.load(f)

schema["title"] = f"{PERSONA_NAME} AI"
schema["description"] = (
    f"Per-user override for the {PERSONA_NAME} persona's default chat "
    "model. Leave unset to use this hub's configured default."
)

with open(SCHEMA_PATH, "w") as f:
    json.dump(schema, f, indent=2)
