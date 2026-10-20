#!/bin/bash
# Avvia il server vLLM (API compatibile OpenAI) su un nodo GPU.
# Uso, dal nodo di login:  sbatch scripts/llm.sbatch
#SBATCH --job-name=llm
#SBATCH --partition=l40s
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=/scratch.hpc/fabio.ciraci2/GPULLM/llm-%j.log

D=/scratch.hpc/fabio.ciraci2/GPULLM
MODEL_DIR=$D/models/Qwen3-8B

# Stampa nome e IP del nodo all'inizio del log: servono per il tunnel SSH,
# perché il nodo di login non risolve il nome dei nodi GPU.
echo "NODE: $(hostname)"
echo "NODE IP: $(hostname -I)"

# Usa l'ambiente creato da install.sh.
export PATH=$D/vllm-env/bin:$PATH

# Tutte le cache in scratch, non nella home (quota piena).
export HF_HOME=$D/hf
export XDG_CACHE_HOME=$D/cache
export VLLM_CACHE_ROOT=$D/cache/vllm
export TRITON_CACHE_DIR=$D/cache/triton
export TORCHINDUCTOR_CACHE_DIR=$D/cache/inductor

# Niente statistiche d'uso inviate a vLLM.
export VLLM_NO_USAGE_STATS=1
# Il campionatore FlashInfer richiede nvcc, che sul cluster non c'è:
# usiamo quello interno di vLLM.
export VLLM_USE_FLASHINFER_SAMPLER=0

# --served-model-name qwen          nome del modello nelle API
# --host 0.0.0.0 --port 8000        accetta connessioni da altri nodi sulla porta 8000
# --max-model-len 16384             lunghezza massima di contesto (token)
# --enable-auto-tool-choice         abilita il tool calling (richiesto da Open WebUI e dall'agente)
# --tool-call-parser hermes         formato delle chiamate ai tool usato da Qwen3
# --reasoning-parser qwen3          separa il "thinking" (<think>...</think>) dalla risposta
vllm serve "$MODEL_DIR" \
  --served-model-name qwen \
  --host 0.0.0.0 --port 8000 \
  --max-model-len 16384 \
  --enable-auto-tool-choice --tool-call-parser hermes \
  --reasoning-parser qwen3
