#!/bin/bash
# Starts the vLLM server (OpenAI-compatible API) on a GPU node.
# Usage: from the repository root, after install.sh:
#   cd ClusterAgent && sbatch scripts/llm.sbatch
#SBATCH --job-name=llm
#SBATCH --partition=l40s
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=logs/llm-%j.log

# Slurm copies this script elsewhere before running it, so the repository folder
# cannot be derived from the script's location. We use the folder sbatch was
# launched from (SLURM_SUBMIT_DIR): that is why it must be launched from the repo.
# The relative --output path (logs/) also starts from that folder.
D=${LLM_DIR:-$SLURM_SUBMIT_DIR}
MODEL_DIR=${MODEL_DIR:-$D/models/Qwen3-8B}

if [ ! -x "$D/vllm-env/bin/vllm" ]; then
  echo "ERROR: vLLM not found in $D/vllm-env."
  echo "Run sbatch from the repository root, after scripts/install.sh."
  exit 1
fi

# Print node name and IP at the top of the log: they are needed for the SSH tunnel,
# because the login node cannot resolve GPU node names.
echo "NODE: $(hostname)"
echo "NODE IP: $(hostname -I)"

# Use the environment created by install.sh.
export PATH=$D/vllm-env/bin:$PATH

# Keep all caches inside the repository, not in home (the home quota is small).
export HF_HOME=$D/hf
export XDG_CACHE_HOME=$D/cache
export VLLM_CACHE_ROOT=$D/cache/vllm
export TRITON_CACHE_DIR=$D/cache/triton
export TORCHINDUCTOR_CACHE_DIR=$D/cache/inductor

# Do not send usage statistics to vLLM.
export VLLM_NO_USAGE_STATS=1
# The FlashInfer sampler needs nvcc, which the cluster does not have:
# use vLLM's built-in sampler instead.
export VLLM_USE_FLASHINFER_SAMPLER=0

# --served-model-name qwen          model name exposed by the API
# --host 0.0.0.0 --port 8000        accept connections from other nodes on port 8000
# --max-model-len 16384             maximum context length (tokens)
# --enable-auto-tool-choice         enable tool calling (needed by Open WebUI and the agent)
# --tool-call-parser hermes         tool-call format used by Qwen3
# --reasoning-parser qwen3          separate the "thinking" (<think>...</think>) from the answer
vllm serve "$MODEL_DIR" \
  --served-model-name qwen \
  --host 0.0.0.0 --port 8000 \
  --max-model-len 16384 \
  --enable-auto-tool-choice --tool-call-parser hermes \
  --reasoning-parser qwen3
