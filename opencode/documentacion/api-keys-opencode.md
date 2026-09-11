# 🔑 API Keys de OpenCode

Listado de todas las API keys configuradas en OpenCode para Antonio.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

---

## 📑 Índice
1. [Variables de entorno .env](#variables-de-entorno-env)
2. [Credenciales auth.json](#credenciales-authjson)

---

## Variables de entorno .env
Archivo: `~/.config/opencode/.env`

| Variable | Valor |
|----------|-------|
| OLLAMA_API_KEY | `ollama` |
| AEMET_API_KEY | `eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhbm1hcnVpNzRAZ21haWwuY29tIiwianRpIjoiZWI4ZjE0MWMtOTYyZC00OWUxLTg2NTQtMzI1NTE2NWNkMDVlIiwiZXhwIjoxNzk3MjA2MTYyLCJpc3MiOiJBRU1FVCIsImlhdCI6MTc4ODU2NjE2MiwidXNlcklkIjoiZWI4ZjE0MWMtOTYyZC00OWUxLTg2NTQtMzI1NTE2NWNkMDVlIiwicm9sZSI6IiJ9.2wX9afiHV6iM1-XWll6YxdwvSaUpdjmTKnNyKvtjD_Y` |

---

## Credenciales auth.json
Archivo: `~/.local/share/opencode/auth.json`

| Proveedor | Tipo | Key |
|-----------|------|-----|
| opencode | api | `sk-f6M8V5axCnj1y3OftlSu90xpGaomM300q0Sgw1JG18nMRah1aOFXI9qQfkDsiraM` |
| ollama | api | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8/RlC9ZaWnAcF4upJfc/8vLjd1NnzAyF7SpftYKkC2` |
| ollama-cloud | api | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8/RlC9ZaWnAcF4upJfc/8vLjd1NnzAyF7SpftYKkC2` |
| opencode-go | api | `sk-f6M8V5axCnj1y3OftlSu90xpGaomM300q0Sgw1JG18nMRah1aOFXI9qQfkDsiraM` |
| nvidia | api | `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` |

> Notas:
> - OLLAMA_API_KEY es el placeholder `ollama`, sin autenticación real.
> - AEMET_API_KEY se usa para consultas de tiempo de Pechina 04074 vía OpenData AEMET.
> - Las claves de `opencode` y `opencode-go` son idénticas.
> - Las claves SSH de `ollama` y `ollama-cloud` son idénticas.

> 📁 ~/.config/opencode/.env · ~/.local/share/opencode/auth.json
