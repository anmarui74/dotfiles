<#
.SYNOPSIS
    Historial COMPLETO de peticiones de OpenCode (PowerShell 5.1).
    Equivalente al script Linux ~/.local/bin/timeline-completo.

.DESCRIPTION
    El timeline de la TUI de OpenCode solo muestra las últimas ~6 peticiones
    (límite hardcodeado; PR #26861 sin mergear). Este script lee la BD SQLite
    directamente y muestra TODAS las peticiones de una sesión.

    La BD se consulta con el módulo sqlite3 de Python (no hay CLI sqlite3 en
    Windows). El script PowerShell localiza python.exe, escribe un script Python
    temporal que inspecciona primero el esquema real (SELECT name FROM
    sqlite_master) y luego imprime fecha/hora + texto de cada petición.

.PARAMETER SessionId
    ID de sesión concreta (formato "ses_xxxxx"). Si se omite, se usa la sesión
    más reciente (por time_updated), que es la "sesión actual".

.PARAMETER Sesiones
    Lista las sesiones recientes con su título, ID y última actualización.

.PARAMETER Buscar
    Busca un texto en las peticiones de TODAS las sesiones.

.PARAMETER Ayuda
    Muestra esta ayuda.

.EXAMPLE
    .\timeline-completo.ps1
    Historial completo de la sesión más reciente.

.EXAMPLE
    .\timeline-completo.ps1 ses_abc123
    Historial completo de la sesión indicada.

.EXAMPLE
    .\timeline-completo.ps1 -Sesiones
    Lista de sesiones recientes.

.EXAMPLE
    .\timeline-completo.ps1 -Buscar "nvidia"
    Busca "nvidia" en todas las sesiones.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$SessionId,

    [switch]$Sesiones,

    [string]$Buscar,

    [switch]$Ayuda
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$DB_PATHS = @(
    "$env:USERPROFILE\.local\share\opencode\opencode.db"
)

function Show-Ayuda {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
}

function Get-PythonExe {
    $candidatos = @()
    if (Test-Path 'C:\Python314\python.exe') {
        $candidatos += 'C:\Python314\python.exe'
    }
    $encontrado = Get-Command python -ErrorAction SilentlyContinue
    if ($encontrado) { $candidatos += $encontrado.Source }
    foreach ($c in $candidatos) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Get-DatabasePath {
    foreach ($p in $DB_PATHS) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# ------------------------------------------------------------
# Script Python temporal que inspecciona el esquema real de la BD
# y extrae fecha/hora + texto de cada petición.
# Uso: python script.py <db> <modo> <extra> <salida>
#   modos: sesion | sesiones | buscar
# ------------------------------------------------------------
$PYTHON_SCRIPT = @'
# -*- coding: utf-8 -*-
import sys, sqlite3, json, datetime, os

def ts(ms):
    try:
        return datetime.datetime.fromtimestamp(int(ms) / 1000.0).strftime("%d/%m/%Y %H:%M:%S")
    except Exception:
        return ""

def texto_mensaje(md, pd):
    # El texto real vive en parts tipo "text"; en algunas versiones
    # tambien puede estar directamente en message.data.
    try:
        d = json.loads(pd) if pd else {}
    except Exception:
        d = {}
    if d.get("type") == "text" and d.get("text"):
        return d["text"]
    try:
        m = json.loads(md) if md else {}
    except Exception:
        m = {}
    if isinstance(m, dict):
        for k in ("text", "content"):
            if m.get(k): return m[k]
    return ""

def main():
    if len(sys.argv) < 5:
        print("USO: python timeline.py <db> <modo> <extra> <salida>")
        return 1
    db, modo, extra, salida = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    out = []
    if not os.path.exists(db):
        out.append("ERROR: BD no encontrada: " + db)
        return _flush(out, salida, 2)
    try:
        con = sqlite3.connect(db)
        con.row_factory = sqlite3.Row
        cur = con.cursor()
    except Exception as e:
        out.append("ERROR al abrir la BD: %s" % e)
        return _flush(out, salida, 2)

    # 1) Descubrir el esquema real
    try:
        tablas = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    except Exception as e:
        out.append("ERROR al inspeccionar el esquema: %s" % e)
        return _flush(out, salida, 2)

    if "session" not in tablas or "message" not in tablas:
        out.append("ERROR: la BD no tiene tablas session/message. Esquema detectado:")
        out.append(", ".join(tablas))
        return _flush(out, salida, 2)
    hay_parts = "part" in tablas

    # 2) Modo: listar sesiones
    if modo == "sesiones":
        try:
            rows = cur.execute(
                "SELECT id, title, time_created, time_updated FROM session "
                "ORDER BY time_updated DESC LIMIT 30"
            ).fetchall()
        except Exception as e:
            out.append("ERROR: %s" % e)
            return _flush(out, salida, 2)
        out.append("== Sesiones recientes (%d) ==" % len(rows))
        for r in rows:
            t = ts(r[3]) if r[3] else ts(r[2])
            tit = (r[1] or "").replace("\n", " ")
            if len(tit) > 60: tit = tit[:60] + "..."
            out.append("[%s] %s  |  %s" % (t, r[0], tit))
        out.append("")
        out.append("Uso: timeline-completo.ps1 <sessionId> para ver una sesion.")
        return _flush(out, salida, 0)

    # 3) Resolver la sesion (actual = mas reciente) o la indicada
    sid = extra.strip() if extra.strip() and extra.strip() != "_" else ""
    if not sid and modo == "sesion":
        try:
            row = cur.execute(
                "SELECT id FROM session ORDER BY time_updated DESC LIMIT 1"
            ).fetchone()
            if row: sid = row[0]
        except Exception:
            pass
        if not sid:
            out.append("ERROR: no hay ninguna sesion en la BD.")
            return _flush(out, salida, 2)
    if not sid:
        out.append("ERROR: sesion vacia.")
        return _flush(out, salida, 2)

    # 4) Modo: buscar texto en todas las sesiones
    if modo == "buscar":
        texto = extra.lower()
        try:
            if hay_parts:
                rows = cur.execute(
                    "SELECT m.session_id AS sid, m.time_created AS t, m.data AS md, p.data AS pd "
                    "FROM message m JOIN part p ON p.message_id = m.id ORDER BY p.time_created"
                ).fetchall()
            else:
                rows = cur.execute(
                    "SELECT session_id AS sid, time_created AS t, data AS md, NULL AS pd "
                    "FROM message ORDER BY time_created"
                ).fetchall()
        except Exception as e:
            out.append("ERROR: %s" % e)
            return _flush(out, salida, 2)
        n = 0
        for r in rows:
            txt = texto_mensaje(r["md"], r["pd"])
            if not txt or texto not in txt.lower():
                continue
            n += 1
            snippet = txt.strip().replace("\n", " ")[:160]
            out.append("[%s] %s | %s" % (ts(r["t"]), r["sid"], snippet))
        out.append("")
        out.append("Coincidencias: %d" % n)
        return _flush(out, salida, 0)

    # 5) Modo: historial completo de una sesion
    try:
        sinfo = cur.execute(
            "SELECT title, time_created FROM session WHERE id=?", (sid,)
        ).fetchone()
    except Exception as e:
        out.append("ERROR: %s" % e)
        return _flush(out, salida, 2)
    if not sinfo:
        out.append("ERROR: sesion no encontrada: %s" % sid)
        return _flush(out, salida, 2)
    out.append("== Sesion %s ==" % sid)
    if sinfo[0]:
        out.append("Titulo: %s" % sinfo[0])
    out.append("")

    try:
        if hay_parts:
            rows = cur.execute(
                "SELECT m.time_created AS t, m.data AS md, p.data AS pd "
                "FROM message m JOIN part p ON p.message_id = m.id "
                "WHERE m.session_id=? ORDER BY p.time_created", (sid,)
            ).fetchall()
        else:
            rows = cur.execute(
                "SELECT time_created AS t, data AS md, NULL AS pd "
                "FROM message WHERE session_id=? ORDER BY time_created", (sid,)
            ).fetchall()
    except Exception as e:
        out.append("ERROR: %s" % e)
        return _flush(out, salida, 2)

    total = 0
    for r in rows:
        txt = texto_mensaje(r["md"], r["pd"])
        if not txt:
            continue
        total += 1
        try:
            m = json.loads(r["md"]) if r["md"] else {}
        except Exception:
            m = {}
        rol = m.get("role", "?") if isinstance(m, dict) else "?"
        icono = "\U0001F464" if rol == "user" else ("\U0001F916" if rol == "assistant" else "\u2139\uFE0F")
        out.append("[%s] %s %s:" % (ts(r["t"]), icono, rol))
        out.append(txt.rstrip())
        out.append("")
    out.append("Total: %d peticiones" % total)
    return _flush(out, salida, 0)

def _flush(out, salida, code):
    with open(salida, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    return code

if __name__ == "__main__":
    sys.exit(main())
'@

if ($Ayuda) { Show-Ayuda; exit 0 }

$python = Get-PythonExe
if (-not $python) {
    Write-Error "No se encontro python.exe (se busco C:\Python314\python.exe y Get-Command python). Abortando."
    exit 1
}

$db = Get-DatabasePath
if (-not $db) {
    Write-Error "No se encontro la BD de OpenCode en: $($DB_PATHS -join ', ')"
    exit 1
}

# Argumentos y modo
$modo = "sesion"
$extra = ""
if ($Sesiones) {
    $modo = "sesiones"
} elseif ($Buscar) {
    if (-not $Buscar.Trim()) {
        Write-Error "El parametro -Buscar requiere un texto."
        exit 1
    }
    $modo = "buscar"
    $extra = $Buscar
} elseif ($SessionId) {
    $modo = "sesion"
    $extra = $SessionId
}

# Preparar temporales
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) 'opencode'
if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }
$pyFile = Join-Path $tmpDir 'opencode_timeline.py'
$outFile = Join-Path $tmpDir 'opencode_timeline_out.txt'

# Escribir el script Python (UTF-8 sin BOM es correcto para python)
[System.IO.File]::WriteAllText(
    $pyFile,
    $PYTHON_SCRIPT,
    (New-Object System.Text.UTF8Encoding($false))
)

# Ejecutar (PS 5.1 descarta argumentos vacios al llamar a nativos:
# se usa un centinela "_" cuando no hay valor extra)
if ($extra.Trim() -eq '') { $extra = '_' }
$salida = & $python $pyFile $db $modo $extra $outFile 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0 -and -not (Test-Path $outFile)) {
    Write-Error "Fallo al ejecutar el analizador Python: $salida"
    exit $exitCode
}

$contenido = Get-Content -LiteralPath $outFile -Encoding UTF8 -Raw
Write-Output $contenido
exit 0