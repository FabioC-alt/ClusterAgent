# ClusterAgent

Un LLM servito con [vLLM](https://github.com/vllm-project/vllm) sul cluster Slurm del DISI,
e (in sviluppo) un agente Python che lo usa per leggere e scrivere file e gestire job Slurm.

## Contenuto

| Percorso | Cosa contiene |
|---|---|
| `scripts/install.sh` | Installa vLLM e scarica il modello dentro la repo (una sola volta) |
| `scripts/start.sh` | Lancia il job del server da qualunque cartella (log sempre in `logs/`) |
| `scripts/llm.sbatch` | Job Slurm che avvia il server vLLM su una GPU L40S |
| `docs/connessione.md` | Guida: avvio del job, tunnel SSH, Open WebUI, problemi noti |
| `docs/letteratura.md` | Paper e progetti di riferimento per l'agente |

## Avvio rapido

1. Sul cluster, dalla cartella della repo (clonata in scratch): `bash scripts/install.sh` la prima volta,
   poi `bash scripts/start.sh` e attendi `Application startup complete` in `logs/llm-NUMERO.log`.
2. Sul PC: apri il tunnel SSH verso l'IP del nodo (vedi `docs/connessione.md`).
3. Apri Open WebUI su http://localhost:3000.
