# Guida: avviare il modello e collegarsi da Windows

Schema generale:

```
PC Windows                     nodo di login                  nodo GPU
(Open WebUI / chat.html)  ──SSH──▶  slogin2  ──────────────▶  vLLM :8000
localhost:8001 ◀───────────── tunnel SSH ─────────────────────┘
```

Il nodo GPU non è raggiungibile direttamente dal PC: il tunnel SSH passa dal nodo
di login e porta la porta 8000 del nodo GPU sulla porta **8001** del PC.
(Usiamo 8001 perché sul PC la 8000 è già occupata da un altro container.)

---

## 0. Installazione (una sola volta)

Sul cluster (nodo di login):

```bash
cd /scratch.hpc/$USER                    # in scratch, non nella home: servono ~30 GB
git clone https://github.com/FabioC-alt/ClusterAgent.git
cd ClusterAgent
bash scripts/install.sh                  # alla fine deve stampare INSTALL OK
```

Ambiente Python, modello, cache e log vengono creati **dentro la cartella della
repo** (`vllm-env/`, `models/`, `cache/`, `hf/`, `logs/`, ...). Il file
`.gitignore` li esclude da git.

---

## 1. Avviare il modello (cluster)

Sempre dalla cartella principale della repo:

```bash
cd /scratch.hpc/$USER/ClusterAgent
sbatch scripts/llm.sbatch                # stampa: Submitted batch job NUMERO
squeue -u $USER                          # stato del job e nodo assegnato
tail -f logs/llm-NUMERO.log              # attendi "Application startup complete"
```

L'avvio richiede 2–5 minuti. Poi premi Ctrl+C: il server continua a girare.
Il job si ferma da solo dopo 8 ore (`--time` nello script) o con `scancel NUMERO`.

## 2. Trovare l'IP del nodo GPU (cluster)

Il nodo di login non conosce il nome dei nodi GPU, quindi serve l'IP.
Lo script lo scrive all'inizio del log:

```bash
grep "NODE IP" logs/llm-NUMERO.log
```

Se ci sono più indirizzi, prova il primo. Per verificare che il modello risponda:

```bash
curl http://IP:8000/v1/models            # deve comparire "qwen"
```

## 3. Aprire il tunnel SSH (PowerShell su Windows)

```powershell
ssh -N -L 0.0.0.0:8001:IP:8000 -l fabio.ciraci@unibo.it slogin2.disi.unibo.it
```

- Dopo la password **non stampa nulla**: è normale, il tunnel è aperto.
- Lascia la finestra aperta finché usi il modello.
- `0.0.0.0` serve a rendere il tunnel raggiungibile anche dal container di Open WebUI.
  Se Windows Firewall chiede il permesso, consenti solo le reti private.
- Prova: apri http://localhost:8001/v1/models nel browser, deve comparire `qwen`.

## 4a. Chattare con Open WebUI (Docker)

Prima volta: crea il container.

```powershell
docker run -d -p 3000:8080 -e OPENAI_API_BASE_URL=http://host.docker.internal:8001/v1 -e OPENAI_API_KEY=none -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

Poi apri http://localhost:3000 (al primo avvio può servire 1–2 minuti).

1. Crea un account (resta solo sul tuo PC; il primo è amministratore).
2. Controlla la connessione: **Admin Panel → Settings → Connections → OpenAI API**
   - URL: `http://host.docker.internal:8001/v1`
   - Key: `none`
   - verifica con l'icona di aggiornamento e salva.
3. Nuova chat → scegli il modello **qwen**.

Le volte successive il container riparte da solo con Docker Desktop:
basta avviare il job (punto 1) e il tunnel (punto 3).

## 4b. Alternative senza Docker

- `scripts/chat.html`: doppio clic, si apre nel browser e usa http://localhost:8001/v1.
- `scripts/chat.py`: chat da terminale (`pip install openai`, poi `python chat.py`).

---

## Problemi già incontrati

| Sintomo | Causa | Soluzione |
|---|---|---|
| `channel 2: open failed: connect failed: Name or service not known` nel tunnel | Il nodo di login non risolve il nome del nodo GPU | Usare l'IP (punto 2) invece del nome |
| `Bad local forwarding specification` | Spazi nella parte `-L` | Scriverla tutta attaccata: `8001:IP:8000` |
| `curl` in PowerShell: "remote name could not be resolved" | Comando lanciato sul PC invece che sul cluster | I comandi del punto 2 vanno eseguiti sul cluster |
| `localhost:3000` non raggiungibile | Open WebUI ancora in avvio | Attendere che `docker ps` mostri `(healthy)` |
| In Open WebUI compare un modello "llama" e non "qwen" | Open WebUI punta alla porta 8000 del PC, dove gira un altro servizio | Impostare l'URL su `:8001` (punto 4a) |
| `400 Bad Request` / `"auto" tool choice requires --enable-auto-tool-choice` | Tool calling non attivo in vLLM | Già risolto in `llm.sbatch` (`--enable-auto-tool-choice --tool-call-parser hermes`) |
| `Disk quota exceeded` nel log | Cache scritte nella home | Già risolto: lo script sposta tutte le cache in scratch |
| `Python.h: No such file or directory` | Python di sistema senza header | Già risolto: `install.sh` usa il Python scaricato da uv |
| `Could not find nvcc` | FlashInfer vuole compilare con CUDA | Già risolto: `VLLM_USE_FLASHINFER_SAMPLER=0` |
