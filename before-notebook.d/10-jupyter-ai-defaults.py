#!/usr/bin/env python3
"""Seed a default Jupyter AI model so chat works with no user setup.

Runs once per container start (docker-stacks' start.sh executes every
executable file under before-notebook.d before launching the server). Only
writes the config if it does not already exist, so a user's own model
choice - made through the AI Settings UI - is never overwritten.

The default model is Gemini served through Vertex AI, authenticated with
the credentials at GOOGLE_APPLICATION_CREDENTIALS (mounted into the
container by the deployment - see README). Users can still add their own
API key for a different provider through the AI Settings UI; it is stored
alongside, not instead of, this default.
"""
import json
import os

from jupyter_core.paths import jupyter_data_dir

DEFAULT_MODEL = "vertex_ai/gemini-2.0-flash-001"

config_path = os.path.join(jupyter_data_dir(), "jupyter_ai", "config.json")

if os.path.exists(config_path):
    raise SystemExit(0)

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump({"model_provider_id": DEFAULT_MODEL}, f, indent=4)
