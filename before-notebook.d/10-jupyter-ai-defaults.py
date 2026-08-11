#!/usr/bin/env python3
"""Seed a default Jupyter AI model so chat works with no user setup.

Runs once per container start (docker-stacks' start.sh executes every
executable file under before-notebook.d before launching the server). Only
writes the config if it does not already exist, so a user's own model
choice - made through the AI Settings UI - is never overwritten.

The default model is Gemini served through Vertex AI, authenticated via
GKE Workload Identity (see the jupyter-ai-deployment repo) rather than
anything baked into this image. Users can still add their own API key for
a different provider through the AI Settings UI; it is stored alongside,
not instead of, this default.

DEFAULT_MODEL must be a model actually available in the deploying
project/region - not every Gemini model ID is enabled everywhere.
gemini-2.0-flash-001 (an earlier guess) returned 404 "Publisher model not
found" against civil-pattern-439416-k1/us-central1; gemini-2.5-flash was
confirmed working there via a live litellm.completion() call.
"""
import json
import os

from jupyter_core.paths import jupyter_data_dir

DEFAULT_MODEL = "vertex_ai/gemini-2.5-flash"

config_path = os.path.join(jupyter_data_dir(), "jupyter_ai", "config.json")

if os.path.exists(config_path):
    raise SystemExit(0)

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump({"model_provider_id": DEFAULT_MODEL}, f, indent=4)
