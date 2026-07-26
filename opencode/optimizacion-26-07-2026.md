# Optimización de modelos locales - 26/07/2026

## Cambios realizados

### 1. Parámetros de sampling corregidos
Motivo: presence_penalty 1.5 causaba respuestas cortadas a mitad de frase.

| Modelo | Antes | Después |
|--------|-------|---------|
| qwen3.5:9b | presence_penalty=1.5, temp=1.0 | presence_penalty=0.3, temp=0.7 |
| deepseek-v4-flash | presence_penalty=1.5, temp=1.0 | presence_penalty=0.3, temp=0.7 |
| gemma4:e4b | temp=1.0 | temp=0.7 |
| llama3.1:8b | sin parámetros | temp=0.7, top_k=40, top_p=0.9 |
| deepseek-r1:8b | temp=0.6 (bien) | añadido top_k=40 |

### 2. Contexto aumentado (según VRAM disponible)
RTX 16 GB VRAM:
- qwen3.5:9b (6.6 GB) → 49.152 tokens
- deepseek-v4-flash (6.6 GB) → 49.152 tokens
- deepseek-r1:8b (5.2 GB) → 65.536 tokens
- llama3.1:8b (4.9 GB) → 65.536 tokens
- gemma4:e4b (9.6 GB) → 32.768 tokens (límite por tamaño)

### 3. maxTokens aumentado a 8192
Todos los modelos configurados con maxTokens: 8192.

### 4. Proxy actualizado
- num_predict por defecto: 8192
- Paso automático de max_tokens del cliente a Ollama

### Backups de modelos disponibles
ollama cp -> qwen3.5:9b-stock, deepseek-v4-flash-stock, gemma4:e4b-stock, deepseek-r1:8b-stock, llama3.1:8b-stock
