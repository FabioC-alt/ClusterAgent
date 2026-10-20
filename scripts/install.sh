#!/bin/bash
# Installa vLLM e scarica il modello dentro la cartella della repo.
# Da lanciare UNA SOLA VOLTA sul nodo di login:  bash scripts/install.sh
# Clona la repo in scratch, non nella home: servono circa 30 GB.
set -euo pipefail

# Cartella di lavoro = cartella principale della repo (quella che contiene scripts/),
# ricavata dalla posizione di questo script. Tutto (Python, pacchetti, cache,
# modelli, log) finisce lì dentro; .gitignore esclude questi file da git.
D=${LLM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
MODEL=${MODEL:-Qwen/Qwen3-8B}
mkdir -p "$D/logs" && cd "$D"

# Cache di uv e Python scaricato da uv: anche questi nella repo, non nella home.
export UV_CACHE_DIR=$D/cache/uv
export UV_PYTHON_INSTALL_DIR=$D/uv-python
export HF_HOME=$D/hf

# 1. Installa uv (gestore di pacchetti Python) in $D/uv-bin, senza toccare PATH o .bashrc.
if [ ! -x "$D/uv-bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=$D/uv-bin UV_NO_MODIFY_PATH=1 sh
fi

# 2. Crea l'ambiente con un Python scaricato da uv: contiene Python.h,
#    che manca nel Python di sistema del cluster e serve a vLLM per compilare.
"$D/uv-bin/uv" venv "$D/vllm-env" --python 3.12 --managed-python

# 3. Installa vLLM e il client di Hugging Face nell'ambiente.
"$D/uv-bin/uv" pip install --python "$D/vllm-env/bin/python" vllm huggingface_hub

# 4. Scarica il modello (circa 16 GB per Qwen3-8B) in $D/models/<nome>.
"$D/vllm-env/bin/hf" download "$MODEL" --local-dir "$D/models/$(basename "$MODEL")"

ls "$D/vllm-env/bin/vllm" > /dev/null && echo "INSTALL OK"
