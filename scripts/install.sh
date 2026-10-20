#!/bin/bash
# Installs vLLM and downloads the model inside the repository folder.
# Run ONCE on the login node:  bash scripts/install.sh
# Clone the repository in scratch, not in your home: it needs about 30 GB.
set -euo pipefail

# Working directory = repository root (the folder that contains scripts/),
# derived from the location of this script. Everything (Python, packages, caches,
# models, logs) goes there; .gitignore keeps these files out of git.
D=${LLM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
MODEL=${MODEL:-Qwen/Qwen3-8B}
mkdir -p "$D/logs" && cd "$D"

# uv cache and the Python downloaded by uv: also inside the repository, not in home.
export UV_CACHE_DIR=$D/cache/uv
export UV_PYTHON_INSTALL_DIR=$D/uv-python
export HF_HOME=$D/hf

# 1. Install uv (Python package manager) in $D/uv-bin, without touching PATH or .bashrc.
if [ ! -x "$D/uv-bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=$D/uv-bin UV_NO_MODIFY_PATH=1 sh
fi

# 2. Create the environment with a Python downloaded by uv: it includes Python.h,
#    which the cluster's system Python lacks and vLLM needs to compile kernels.
"$D/uv-bin/uv" venv "$D/vllm-env" --python 3.12 --managed-python

# 3. Install vLLM and the Hugging Face client into the environment.
"$D/uv-bin/uv" pip install --python "$D/vllm-env/bin/python" vllm huggingface_hub

# 4. Download the model (about 16 GB for Qwen3-8B) into $D/models/<name>.
"$D/vllm-env/bin/hf" download "$MODEL" --local-dir "$D/models/$(basename "$MODEL")"

ls "$D/vllm-env/bin/vllm" > /dev/null && echo "INSTALL OK"
