"""Chat da terminale con il modello servito da vLLM.

Uso (sul PC, con il tunnel SSH aperto):
    pip install openai
    python chat.py

Per un altro indirizzo:  set LLM_URL=http://localhost:8001/v1  (Windows)
                         export LLM_URL=...                    (Linux/macOS)
"""
import os

from openai import OpenAI

URL = os.environ.get("LLM_URL", "http://localhost:8001/v1")
client = OpenAI(base_url=URL, api_key="none")  # vLLM non richiede una chiave

# Prende il nome del modello dal server (nel nostro caso "qwen").
model = client.models.list().data[0].id
print(f"Connesso a {URL} ({model}). Scrivi 'esci' per uscire.")

messages = []  # cronologia: il modello vede tutta la conversazione a ogni turno
while True:
    text = input("\ntu> ").strip()
    if text.lower() in ("esci", "exit", "quit"):
        break
    messages.append({"role": "user", "content": text})

    # stream=True: la risposta arriva un pezzo alla volta, come in una chat.
    stream = client.chat.completions.create(model=model, messages=messages, stream=True)
    answer = ""
    for chunk in stream:
        # Con --reasoning-parser il ragionamento arriva in un campo separato:
        # qui stampiamo solo la risposta finale.
        piece = chunk.choices[0].delta.content or ""
        print(piece, end="", flush=True)
        answer += piece
    print()
    messages.append({"role": "assistant", "content": answer})
