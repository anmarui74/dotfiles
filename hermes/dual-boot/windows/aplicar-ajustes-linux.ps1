<#
  aplicar-ajustes-linux.ps1 — reproduce en el Hermes de Windows los ajustes locales
  que ya funcionan en el Hermes de Linux (cachyos):

    1) PARCHE DEL CLI (Ctrl+Q): corta la locución de TTS en curso y NO interrumpe el
       turno; Ctrl+C la corta además de interrumpir. Toca dos ficheros del repo:
       hermes_cli/cli_tui_mixin.py y tools/voice_mode.py.
    2) AGENTES/MODELOS: restaura los alias de modelo (nvidia, local, gpt-oss, glimmer,
       multimodal…), fija el modelo por defecto (deepseek-v4.1-flash via opencode-go, igual
       que en Linux) y el plugin `nvidia` que limita el catálogo del proveedor al whitelist
       de OpenCode, para que el selector /model muestre lo mismo que en Linux.

  Uso (sin administrador), desde esta carpeta (la carpeta windows/ de HermesSync):

      powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1
      powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1 -SoloEstado
      powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1 -Repo "C:\ruta\hermes-agent" -HermesHome "$env:LOCALAPPDATA\hermes"

  Es idempotente: si ya está todo aplicado no cambia nada. El parche del CLI no entra en
  una sesión de Hermes ya abierta: hay que reiniciar Hermes después.
#>
[CmdletBinding()]
param(
    [string]$Repo = "",
    [string]$HermesHome = "",
    [switch]$SoloEstado
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$comun = Split-Path -Parent $raiz
$parche = Join-Path $raiz "parches\ctrl-q-corta-audio.patch"
$jsonAlias = Join-Path $raiz "alias-modelos.json"
$pluginOrigen = Join-Path $raiz "plugins\model-providers\nvidia"

function Ok($m)    { Write-Host "   [ok] $m" -ForegroundColor Green }
function Aviso($m) { Write-Host "   [!]  $m" -ForegroundColor Yellow }
function Mal($m)   { Write-Host "   [x]  $m" -ForegroundColor Red }

# Ejecuta un programa externo y devuelve su código de salida sin que su salida pueda abortar
# el script. En Windows PowerShell 5.1, con $ErrorActionPreference = 'Stop', cualquier linea que
# un .exe escriba en stderr se convierte en error terminante (NativeCommandError): git escribe
# ahi en cuanto un --check falla, y el script moria en el primer git del paso 1.
# Deja la salida capturada en $script:SalidaNativa por si el llamador quiere mostrarla.
function Correr([string]$Exe, [string[]]$Argumentos) {
    $previo = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $script:SalidaNativa = (& $Exe @Argumentos 2>&1 | Out-String).Trim()
        return [int]$LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previo }
}

Write-Host "=== Ajustes de Linux para el Hermes de Windows ===" -ForegroundColor Cyan

# ── Localizar HERMES_HOME ──
if (-not $HermesHome) {
    if ($env:HERMES_HOME)      { $HermesHome = $env:HERMES_HOME }
    elseif ($env:LOCALAPPDATA) { $HermesHome = Join-Path $env:LOCALAPPDATA "hermes" }
    else                       { $HermesHome = Join-Path $env:USERPROFILE ".hermes" }
}
if (Test-Path $HermesHome) { Ok "HERMES_HOME: $HermesHome" }
else { Mal "no encuentro HERMES_HOME en $HermesHome"; exit 1 }

# ── Localizar el repo de Hermes ──
if (-not $Repo) {
    foreach ($c in @((Join-Path $HermesHome "hermes-agent"), "C:\hermes-agent", (Join-Path $env:USERPROFILE "hermes-agent"))) {
        if (Test-Path (Join-Path $c ".git")) { $Repo = $c; break }
    }
}
$gitDisponible = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

# ── 1. Parche del CLI (Ctrl+Q corta la locución) ──
Write-Host ""
Write-Host "1. Parche del CLI (Ctrl+Q corta la locución, Ctrl+C además interrumpe)"
if (-not (Test-Path $parche)) { Mal "falta el parche: $parche" }
elseif (-not $gitDisponible)  { Mal "no hay git en el PATH: aplica el parche a mano (git apply) o instala Git for Windows" }
elseif (-not $Repo -or -not (Test-Path (Join-Path $Repo ".git"))) {
    Aviso "no encuentro el repo de Hermes (¿hermes-agent?). Indícalo con -Repo <ruta>"
}
else {
    $rev = Correr "git" @("-C", $Repo, "apply", "--reverse", "--check", $parche)
    if ($rev -eq 0) {
        Ok "parche ya aplicado en $Repo"
    }
    else {
        $fwd = Correr "git" @("-C", $Repo, "apply", "--check", $parche)
        if ($fwd -eq 0) {
            if ($SoloEstado) { Aviso "parche PENDIENTE de aplicar en $Repo" }
            else {
                $apl = Correr "git" @("-C", $Repo, "apply", $parche)
                if ($apl -eq 0) { Ok "parche aplicado (reinicia Hermes para que la tecla cambie)" }
                else { Mal "git apply falló: aplica el parche a mano y revisa $Repo"; Write-Host "      git: $script:SalidaNativa" -ForegroundColor DarkGray }
            }
        }
        else {
            Mal "el parche no aplica limpio (el código aguas arriba cambió): revisa $parche contra $Repo"
            Write-Host "      git: $script:SalidaNativa" -ForegroundColor DarkGray
        }
    }
}

# ── 2. Plugin nvidia (catálogo limitado al whitelist de OpenCode) ──
Write-Host ""
Write-Host "2. Plugin de agentes/modelos NVIDIA"
if (-not (Test-Path $pluginOrigen)) { Mal "falta el plugin de origen: $pluginOrigen" }
elseif ($SoloEstado) { Aviso "estado: se copiaría el plugin a $HermesHome\plugins\model-providers\nvidia" }
else {
    $destino = Join-Path $HermesHome "plugins\model-providers\nvidia"
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    Copy-Item -Path (Join-Path $pluginOrigen "*") -Destination $destino -Recurse -Force
    # El bytecode compilado de la version anterior sobrevive a la copia y se seguiria usando.
    $cache = Join-Path $destino "__pycache__"
    if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }
    if (Test-Path (Join-Path $destino "__init__.py")) { Ok "plugin nvidia en $destino" }
    else { Mal "no pude copiar el plugin a $destino" }
}

# ── 3. Alias de modelo (los "agentes") ──
Write-Host ""
Write-Host "3. Alias de modelo (agentes)"
$datos = $null
if (Test-Path $jsonAlias) { $datos = Get-Content $jsonAlias -Raw -Encoding UTF8 | ConvertFrom-Json }
if (-not $datos) { Mal "falta o no puedo leer $jsonAlias" }
else {
    $nombres = @($datos.aliases.PSObject.Properties.Name)
    if ($SoloEstado) {
        Aviso ("estado: alias a asegurar -> " + ($nombres -join ", "))
    }
    elseif (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
        Mal "no encuentro el comando 'hermes' en el PATH: abre una consola nueva o instala Hermes"
    }
    else {
        $puestos = 0
        foreach ($n in $nombres) {
            $modelo = $datos.aliases.$n
            $code = Correr "hermes" @("config", "set", "model.aliases.$n", "$modelo", "--force")
            if ($code -eq 0) { $puestos++ } else { Aviso "no pude fijar el alias '$n' -> $modelo ($script:SalidaNativa)" }
        }
        Ok "$puestos/$($nombres.Count) alias de modelo aplicados"
    }
}

# ── 3a. Modelo por defecto (el «agente general») ──
Write-Host ""
Write-Host "3a. Modelo por defecto (agente general)"
# El export trae el modelo por defecto que tiene Linux. Sin este paso, Windows solo heredaba
# los alias y el modelo por defecto se quedaba como estuviera en cada equipo.
$def = $null
if ($datos) { $def = $datos.agente_por_defecto }
if (-not $def) { Aviso "el export no trae agente_por_defecto: no toco el modelo por defecto" }
elseif (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Mal "no encuentro el comando 'hermes' en el PATH: abre una consola nueva o instala Hermes"
}
elseif ($SoloEstado) {
    Aviso "estado: se fijaria model.default = $($def.modelo) (provider $($def.proveedor))"
}
else {
    $mod = [string]$def.modelo
    $prov = [string]$def.proveedor
    $c1 = Correr "hermes" @("config", "set", "model.default", "$mod")
    $c2 = Correr "hermes" @("config", "set", "model.provider", "$prov")
    if ($c1 -eq 0 -and $c2 -eq 0) { Ok "modelo por defecto: $mod (proveedor $prov)" }
    else { Mal "no pude fijar el modelo por defecto ($mod / $prov): $script:SalidaNativa" }
    # Un base_url/api_mode heredados de otro proveedor dejarian el modelo nuevo apuntando al
    # relay viejo (paso al cambiar de nvidia a opencode-go): se limpian solo si estan puestos.
    $limpiados = 0
    foreach ($k in @("model.base_url", "model.api_mode")) {
        if ((Correr "hermes" @("config", "get", $k)) -eq 0) {
            $viejo = $script:SalidaNativa
            if ((Correr "hermes" @("config", "unset", $k)) -eq 0) { Ok "limpiado ${k} (era $viejo)"; $limpiados++ }
            else { Aviso "no pude limpiar ${k}: $script:SalidaNativa" }
        }
    }
    if ($limpiados -eq 0) { Ok "sin ruta de proveedor heredada (base_url/api_mode ya vacios)" }
}

# ── 3b. Whitelist NVIDIA que lee el plugin ──
Write-Host ""
Write-Host "3b. Whitelist NVIDIA (OpenCode)"
# El perfil que manda es el primero que traiga el bloque. En Windows la config activa de
# OpenCode es opencode.jsonc (JSONC), no opencode.json, que es la extensión de Linux: buscar
# sólo opencode.json dejaba el whitelist sin aplicar y el plugin sin filtrar el catálogo.
$cfgDir = Join-Path $env:USERPROFILE ".config\opencode"
$whitelist = @()
if ($datos) { $whitelist = @($datos.whitelist_nvidia) }
$perfilCfg = $null
if ($whitelist.Count -gt 0) {
    foreach ($n in @("opencode.json", "opencode.jsonc", "opencode-local.json", "opencode-cloud.json")) {
        $ruta = Join-Path $cfgDir $n
        if ((Test-Path $ruta) -and (Select-String -Path $ruta -Pattern '"whitelist"' -Quiet)) { $perfilCfg = $ruta; break }
    }
}
if (-not $datos) { Aviso "sin export de alias/whitelist: nada que hacer" }
elseif ($whitelist.Count -eq 0) { Aviso "el export no trae whitelist: nada que hacer" }
elseif ($SoloEstado) {
    if ($perfilCfg) { Aviso "estado: se pondria el whitelist ($($whitelist.Count) modelos) en $perfilCfg" }
    else { Aviso "estado: no hay perfil de OpenCode con whitelist; se crearia $cfgDir\opencode.json" }
}
elseif ($perfilCfg) {
    # Se reescribe solo el array, por texto y no con ConvertTo-Json: ese reformateaba todo el
    # perfil (formato y comentarios del JSONC incluidos) y no hace falta tocar nada más.
    $texto = Get-Content $perfilCfg -Raw -Encoding UTF8
    $eol = "`n"; if ($texto -match "`r`n") { $eol = "`r`n" }   # no mezclar finales de linea
    $renglones = ($whitelist | ForEach-Object { "        `"$_`"" }) -join ("," + $eol)
    $rx = [regex]'("whitelist"\s*:\s*\[)[^\]]*(\])'
    $m = $rx.Match($texto)
    if (-not $m.Success) { Mal "no encuentro el array del whitelist en $perfilCfg" }
    else {
        $nuevo = $texto.Substring(0, $m.Index) + $m.Groups[1].Value + $eol + $renglones + $eol + "      " + $m.Groups[2].Value + $texto.Substring($m.Index + $m.Length)
        if ($nuevo -eq $texto) { Ok "whitelist ya al dia en $perfilCfg ($($whitelist.Count) modelos)" }
        else {
            [System.IO.File]::WriteAllText($perfilCfg, $nuevo, (New-Object System.Text.UTF8Encoding($false)))
            Ok "whitelist actualizado en $perfilCfg ($($whitelist.Count) modelos)"
        }
    }
}
elseif (-not (Test-Path $cfgDir)) {
    Aviso "no existe $cfgDir (OpenCode no esta instalado aqui): el plugin no filtrara, pero los alias funcionan igual"
}
else {
    $destinoCfg = Join-Path $cfgDir "opencode.json"
    $renglones = ($whitelist | ForEach-Object { "        `"$_`"" }) -join ",`r`n"
    $contenido = "{`r`n  `"providers`": {`r`n    `"nvidia`": {`r`n      `"whitelist`": [`r`n$renglones`r`n      ]`r`n    }`r`n  }`r`n}`r`n"
    [System.IO.File]::WriteAllText($destinoCfg, $contenido, (New-Object System.Text.UTF8Encoding($false)))
    Ok "creado $destinoCfg con el whitelist ($($whitelist.Count) modelos)"
}

# ── 3c. LM Studio: la marca que hace aparecer el proveedor local ──
Write-Host ""
Write-Host "3c. LM Studio (proveedor local en /model)"
# Hermes no deduce LM Studio de ninguna credencial: sin LM_API_KEY (o LM_BASE_URL) el
# proveedor no existe para el selector, aunque el servidor del 1234 este levantado. Con el
# servidor sin auth el valor da igual, pero la variable tiene que estar.
$envFile = Join-Path $HermesHome ".env"
$valorLm = "lm-studio"
if ($datos) {
    $propEnv = $datos.PSObject.Properties["env"]
    if ($propEnv -and $propEnv.Value) {
        $propLm = $propEnv.Value.PSObject.Properties["LM_API_KEY"]
        if ($propLm -and $propLm.Value) { $valorLm = [string]$propLm.Value }
    }
}
if (-not (Test-Path $envFile)) { Mal "no existe $envFile" }
elseif (Select-String -Path $envFile -Pattern '^\s*LM_API_KEY\s*=' -Quiet) { Ok "LM_API_KEY ya esta en $envFile" }
elseif ($SoloEstado) { Aviso "estado: se anadiria LM_API_KEY a $envFile (sin ella el proveedor lmstudio no sale en /model)" }
else {
    $salto = ""
    $ultima = Get-Content $envFile -Tail 1 -ErrorAction SilentlyContinue
    if ($ultima) { $salto = "`r`n" }
    [System.IO.File]::AppendAllText($envFile, "$salto# LM Studio local (127.0.0.1:1234): marca el proveedor para el selector /model`r`nLM_API_KEY=$valorLm`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Ok "LM_API_KEY anadida a $envFile"
}

# ── 4. Verificación ──
Write-Host ""
Write-Host "4. Verificación"
if ($Repo -and (Test-Path (Join-Path $Repo ".git")) -and $gitDisponible -and (Test-Path $parche)) {
    if ((Correr "git" @("-C", $Repo, "apply", "--reverse", "--check", $parche)) -eq 0) { Ok "parche Ctrl+Q: aplicado" }
    else { Aviso "parche Ctrl+Q: pendiente" }
}
if ($pluginOrigen -and (Test-Path (Join-Path $pluginOrigen "__init__.py"))) {
    $plugDst = Join-Path $HermesHome "plugins\model-providers\nvidia\__init__.py"
    if (-not (Test-Path $plugDst)) { Aviso "plugin nvidia: no esta instalado" }
    elseif ((Get-FileHash (Join-Path $pluginOrigen "__init__.py")).Hash -eq (Get-FileHash $plugDst).Hash) { Ok "plugin nvidia: instalado y al dia" }
    else { Aviso "plugin nvidia: la copia instalada NO coincide con el origen" }
}
if ($perfilCfg) { Ok "perfil de OpenCode con whitelist: $perfilCfg" }
elseif ($whitelist.Count -gt 0) { Aviso "ningun perfil de OpenCode con whitelist: el catalogo NVIDIA saldra sin filtrar" }
$envFile = Join-Path $HermesHome ".env"
if ((Test-Path $envFile) -and (Select-String -Path $envFile -Pattern '^\s*LM_API_KEY\s*=' -Quiet)) { Ok "LM_API_KEY: presente (lmstudio sale en /model si el 1234 responde)" }
else { Aviso "LM_API_KEY: ausente -> lmstudio no aparecera en /model" }
$cacheModelos = Join-Path $HermesHome "provider_models_cache.json"
if ((Test-Path $cacheModelos) -and ($whitelist.Count -gt 0)) {
    try {
        $cc = Get-Content $cacheModelos -Raw -Encoding UTF8 | ConvertFrom-Json
        $ent = $cc.PSObject.Properties["nvidia"]
        if (-not $ent) { Aviso "cache del selector: sin entrada de nvidia (se creara al abrir /model)" }
        else {
            $nCache = @($ent.Value.models).Count
            if ($nCache -gt $whitelist.Count) {
                Aviso "cache del selector: nvidia con $nCache modelos y la whitelist son $($whitelist.Count): el selector la recompone al abrir /model (o con 'hermes model')"
            }
            else { Ok "cache del selector: nvidia con $nCache modelos" }
        }
    } catch { Aviso "no pude leer $cacheModelos" }
}
if (Get-Command hermes -ErrorAction SilentlyContinue) {
    Write-Host "   Modelo por defecto visto por Hermes:"
    & hermes config get model.default
    & hermes config get model.provider
    Write-Host "   Alias vistos por Hermes:"
    & hermes config get model.aliases
}
Write-Host ""
Write-Host "Recuerda: reinicia Hermes para que el parche de Ctrl+Q entre en la sesión." -ForegroundColor Cyan
Write-Host "Deja constancia en $(Join-Path $comun "NOTA-PARA-LINUX.md") cuando termines." -ForegroundColor Cyan
