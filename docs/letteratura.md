# Agenti LLM su cluster Slurm: stato dell'arte

Questo documento raccoglie i lavori (paper e progetti open-source) che abbiamo
usato come riferimento per progettare **ClusterAgent**: un agente Python che usa un
LLM servito con vLLM sul cluster e che può leggere/scrivere file e gestire job Slurm.

Ricerca effettuata il 21 ottobre 2026.

---

## 1. Fondamenti: come funziona un agente

### ReAct: Synergizing Reasoning and Acting in Language Models
- **Autori:** Shunyu Yao et al. (Princeton / Google), ICLR 2023
- **Link:** https://arxiv.org/abs/2210.03629
- **Idea:** il modello alterna *ragionamento* (pensa a cosa fare), *azione*
  (chiama un tool) e *osservazione* (legge il risultato), in un ciclo che si
  ripete fino alla fine del compito. È lo schema di base di quasi tutti gli
  agenti moderni, compreso il nostro.

### SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering
- **Autori:** John Yang, Carlos E. Jimenez, Alexander Wettig, Kilian Lieret,
  Shunyu Yao, Karthik Narasimhan, Ofir Press (Princeton / Stanford), NeurIPS 2024
- **Link:** https://arxiv.org/abs/2405.15793
- **Sito:** https://swe-agent.com
- **Idea:** introduce il concetto di **Agent-Computer Interface (ACI)**, cioè
  l'insieme di comandi con cui l'agente osserva e modifica il sistema, e il
  formato del feedback che riceve. La tesi centrale è che il design di questa
  interfaccia conta quanto (o più) del modello: comandi strutturati e ben
  documentati, output compatti e feedback espliciti migliorano molto le
  prestazioni, senza cambiare i pesi del modello.
- **Cosa prendiamo:** tool con nomi e descrizioni chiari, output brevi, messaggi
  di errore che spiegano cosa correggere.

### mini-swe-agent
- **Autori:** lo stesso gruppo di SWE-agent (Princeton / Stanford)
- **Link:** https://github.com/SWE-agent/mini-swe-agent
- **Documentazione:** https://mini-swe-agent.com/latest/
- **Idea:** un agente di circa 100 righe di Python che dà al modello solo una
  shell bash, tiene una cronologia di messaggi completamente lineare ed esegue
  ogni azione con un `subprocess.run` indipendente. Nonostante la semplicità
  ottiene ottimi risultati su SWE-bench. Supporta anche Singularity/Apptainer.
- **Cosa prendiamo:** il ciclo semplice e la cronologia lineare (facile da
  leggere, registrare e riprendere). **Non** prendiamo la shell libera: per un
  cluster condiviso preferiamo tool limitati.

---

## 2. Agenti LLM in ambiente HPC / Slurm

### LARA: Validation-Driven Agentic Supercomputer Workflows for Atomistic Modeling
- **Anno:** 2026
- **Link:** https://arxiv.org/abs/2604.22571
- **Idea:** framework agentico per simulazioni atomistiche su HPC basato su tre
  componenti: (i) un **livello di esecuzione controllato** che fa da
  intermediario per tutte le interazioni con le risorse HPC; (ii) una
  **validazione tramite dry-run**, che verifica il lavoro senza consumare
  risorse; (iii) una pipeline a più fasi con raffinamento iterativo.
  Gli autori notano che la strategia "riprova finché funziona" degli agenti
  attuali va bene solo quando costi, latenza e rischi sono bassi, cosa che su
  un supercomputer non è vera.
- **Cosa prendiamo:** tutte le azioni passano da un unico punto controllato;
  prima di sottomettere un job si usa `sbatch --test-only`.

### The Socratic Scientist: Designing LLM Agentic Harness for Long-Running Computational Science (Superscientist)
- **Conferenza:** ICML 2026
- **Link:** https://icml.cc/virtual/2026/73606
- **Idea:** pensato per simulazioni che restano ore in coda su HPC, dove
  un'ipotesi sbagliata può far perdere giorni di calcolo. Tre pilastri:
  *Specify* (prima di calcolare, un dialogo strutturato fissa parametri e
  criteri di successo), *Persist* (tutto lo stato è salvato continuamente su
  disco come JSON, log e script, così una nuova sessione può riprendere senza
  perdere contesto), e la ripresa dopo errori.
- **Cosa prendiamo:** ogni sessione dell'agente salvata su disco in JSON, con il
  log di tutte le azioni, riprendibile in un secondo momento.

### TSAgent: An Agentic Workflow for Autonomous Transition State Search
- **Anno:** 2026
- **Link:** https://arxiv.org/abs/2605.14154
- **Idea:** sistema multi-agente per chimica computazionale. L'agente dedicato
  alla sottomissione non scrive script Slurm da zero: invoca uno script
  `sbatch` già configurato, passando solo pochi parametri (cartella, nome del
  job, numero di task), e legge l'ID del job dall'output.
- **Cosa prendiamo:** template `sbatch` predefiniti per le partizioni del
  cluster, che l'agente compila invece di inventare.

### DREAMS: Density Functional Theory Based Research Engine for Agentic Materials Simulation
- **Anno:** 2025
- **Link:** https://arxiv.org/abs/2507.14267
- **Idea:** l'"HPC agent" propone le risorse a partire da una configurazione del
  cluster, sottomette i calcoli a Slurm tramite la libreria
  [pysqa](https://github.com/pyiron/pysqa), ne monitora lo stato e recupera i
  risultati. Testato su un cluster Slurm.
- **Cosa prendiamo:** la configurazione del cluster (partizioni, GPU, limiti)
  scritta in un file che l'agente legge, invece di lasciargliela indovinare.

### Trusted Credentials, Untrusted Behavior: Benchmarking LLM-Agent Security in High-Performance Computing
- **Autore:** Jie Li, 2026 (position/vision paper)
- **Link:** https://arxiv.org/abs/2607.18485
- **Idea:** gli agenti LLM iniziano a fare lavoro di routine sugli HPC
  (monitorare job, diagnosticare build fallite, leggere output). Per farlo
  agiscono con le credenziali dell'utente ed ereditano tutto il suo accesso a
  file e scheduler: un agente "dirottato" (ad esempio da un prompt injection in
  un file di log) può fare danni che i normali controlli sugli account non
  vedono. Il paper propone un benchmark (TaskBound) con scenari su azioni
  Slurm e permessi sul filesystem, e cita le avvertenze del centro di calcolo
  di Aalto agli utenti che usano agenti sul cluster.
- **Cosa prendiamo:** cartella di lavoro confinata, conferma umana per le
  azioni che scrivono o lanciano job, limite al numero di job, e trattare il
  contenuto dei file e dei log come dati, mai come istruzioni.

### Altri lavori correlati
- **Chat AI: A Seamless Slurm-Native Solution for HPC-Based Services** (GWDG, 2024)
  — come servire LLM con vLLM su Slurm come servizio interattivo per molti utenti.
  https://arxiv.org/abs/2407.00110
- **Scalable Engine and the Performance of Different LLM Models in a SLURM based HPC Architecture** (2025)
  — architettura Slurm per scalare l'inferenza di più modelli.
  https://arxiv.org/abs/2508.17814
- **Descriptive Dispatch of Computational Work** (2026)
  — un agente "segretario" trasforma una richiesta in linguaggio naturale in una
  specifica di job validata.
  https://arxiv.org/abs/2608.11524
- **VibeCodeHPC: An Agent-Based Iterative Prompting Auto-Tuner for HPC Code Generation Using LLMs** (2025)
  — sistema multi-agente che genera e ottimizza codice HPC lanciando job su
  PBS/Slurm.
  https://arxiv.org/abs/2510.00031
- **vLLM / PagedAttention: Efficient Memory Management for Large Language Model Serving with PagedAttention** (Kwon et al., SOSP 2023)
  — il motore di inferenza che usiamo sul cluster.
  https://arxiv.org/abs/2309.06180

---

## 3. Tool Slurm già esistenti (server MCP)

MCP (Model Context Protocol, https://modelcontextprotocol.io) è uno standard per
collegare tool a qualunque agente o interfaccia (Open WebUI, Qwen Code, ...).
Esistono già alcuni server MCP per Slurm, utili come riferimento per il design:

| Progetto | Link | Punto interessante |
|---|---|---|
| secure-cluster-mcp | https://github.com/FlorianSp2000/secure-cluster-mcp | Tool di sola lettura permessi automaticamente, tool che scrivono richiedono conferma, limiti di frequenza persistenti |
| srunx | https://github.com/ksterx/srunx | CLI + server MCP per sbatch, squeue, sacct e workflow |
| LLNL mada-tools (Slurm MCP Server) | https://software.llnl.gov/mada-tools/latest/user_guide/supported_servers/scheduler/slurm/ | Sottomissione con sbatch che restituisce gli ID reali dei job, monitoraggio, ispezione del cluster |

---

## 4. Agenti già pronti compatibili con vLLM

Alternative all'agente scritto da noi, collegabili all'endpoint OpenAI-compatibile
di vLLM:

| Agente | Link | Note |
|---|---|---|
| Qwen Code | https://github.com/QwenLM/qwen-code | Ottimizzato per i modelli Qwen; supporta endpoint locali vLLM |
| OpenCode | https://opencode.ai | Agente da terminale, collegabile a vLLM |
| Cline CLI | https://github.com/cline/cline | Legge/scrive file ed esegue comandi; qualsiasi endpoint OpenAI-compatibile |
| mini-swe-agent | https://github.com/SWE-agent/mini-swe-agent | Minimale, solo bash |

Tutti danno al modello un accesso ampio alla shell: potenti, ma con poche
protezioni per un cluster condiviso.

---

## 5. Sintesi: principi di progettazione di ClusterAgent

| # | Principio | Da dove viene | Come lo applichiamo |
|---|---|---|---|
| 1 | Ciclo ragiona → agisci → osserva | ReAct, mini-swe-agent | Ciclo semplice con il tool calling di vLLM e cronologia lineare |
| 2 | Tool strutturati, output compatti | SWE-agent (ACI) | `list_dir`, `read_file`, `write_file`, `submit_job`, `job_status`, `cancel_job`, `read_log` |
| 3 | Livello di esecuzione controllato | LARA-HPC | Tutte le azioni passano da funzioni Python; file solo dentro una cartella di lavoro |
| 4 | Dry-run prima di sottomettere | LARA-HPC | `sbatch --test-only` prima di ogni `sbatch` reale |
| 5 | Conferma umana per le azioni che scrivono | secure-cluster-mcp, paper sulla sicurezza | Domanda `[s/N]` prima di `sbatch` e `scancel`; numero massimo di job |
| 6 | Stato persistente su disco | Superscientist | Ogni sessione salvata in JSON con log delle azioni, riprendibile |
| 7 | Template invece di script liberi | TSAgent, DREAMS | Template `sbatch` per le partizioni del cluster (l40s, h100, ...) |
| 8 | Contenuti esterni = dati, non istruzioni | paper sulla sicurezza | Il system prompt lo dice esplicitamente; i log letti non possono autorizzare azioni |

### Requisiti lato modello
- Per un uso agentico affidabile conviene un modello più grande di Qwen3-8B
  (es. Qwen3-32B su 2× L40S) e un contesto di almeno 32k token
  (`--max-model-len 32768`).
- Il server vLLM deve essere avviato con `--enable-auto-tool-choice
  --tool-call-parser hermes` (già fatto nel nostro `llm.sbatch`).
