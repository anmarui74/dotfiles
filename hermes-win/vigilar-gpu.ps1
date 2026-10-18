<#
    vigilar-gpu.ps1 - Registro continuo del estado de la GPU para diagnosticar los
    cuelgues WATCHDOG (LiveKernelReports) de este equipo.

    Escribe una linea CSV cada $IntervaloSegundos en
    %LOCALAPPDATA%\hermes\diagnostico\gpu-AAAAMMDD.csv

    - Sin privilegios de administrador (usa nvidia-smi, que no los necesita).
    - Vuelca cada linea a disco al escribirla: en un cuelgue se conserva lo ultimo.
    - Marca los instantes en que aparece un volcado nuevo en LiveKernelReports,
      que es lo que delata que la GPU acaba de fallar.
    - Rota: conserva los ultimos 10 dias de CSV.

    Se lanza al iniciar sesion desde la tarea programada HermesVigilarGPU.
#>
param(
    [int]$IntervaloSegundos = 15,
    [int]$DiasConservar = 10,
    [int]$Iteraciones = 0          # 0 = sin limite (uso normal); >0 solo para pruebas
)

$ErrorActionPreference = 'SilentlyContinue'
$dir = Join-Path $env:LOCALAPPDATA 'hermes\diagnostico'
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
if (-not (Test-Path -LiteralPath $smi)) {
    $cmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($cmd) { $smi = $cmd.Source } else { exit 2 }
}

# Guarda anti-duplicados: si ya hay otra instancia de este mismo script, salir.
$otras = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
           Where-Object { $_.CommandLine -match 'vigilar-gpu\.ps1' -and $_.ProcessId -ne $PID })
if ($otras.Count -gt 0) { exit 0 }

$volcados = Join-Path $env:SystemRoot 'LiveKernelReports'
$cabecera = 'instante;temp_gpu_C;temp_mem_C;potencia_W;limite_W;uso_gpu_pct;uso_mem_pct;' +
            'vram_usada_MB;vram_total_MB;sm_MHz;mem_MHz;pstate;motivo_throttle;pid_top_vram;MB_top_vram;volcado_nuevo'
$ultimoVolcado = ''

# Estado inicial de los volcados, para detectar los nuevos
$refVolcados = ''
$f = Get-ChildItem -LiteralPath $volcados -Recurse -File | Sort-Object LastWriteTime | Select-Object -Last 1
if ($f) { $refVolcados = $f.Name + '|' + $f.LastWriteTime.ToString('o') }

$n = 0
while ($true) {
    $ahora = Get-Date
    $log = Join-Path $dir ('gpu-' + $ahora.ToString('yyyyMMdd') + '.csv')
    if (-not (Test-Path -LiteralPath $log)) {
        Add-Content -LiteralPath $log -Value $cabecera -Encoding UTF8
    }

    $principal = (& $smi --query-gpu=timestamp,temperature.gpu,power.draw,power.limit,utilization.gpu,utilization.memory,memory.used,memory.total,clocks.sm,clocks.mem,pstate --format=csv,noheader,nounits) -join ' '
    $campos = $principal -split ',\s*'
    if ($campos.Count -ge 11) {
        $tempMem = (& $smi --query-gpu=temperature.memory --format=csv,noheader,nounits) -join ' '
        $throttle = (& $smi --query-gpu=clocks_throttle_reasons.active --format=csv,noheader) -join ' '
        $apps = (& $smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits) -join '; '
        $pidTop = ''; $memTop = ''
        if ($apps -match '(\d+),\s*(\d+)') { $pidTop = $Matches[1]; $memTop = $Matches[2] }

        $volcadoNuevo = ''
        $g = Get-ChildItem -LiteralPath $volcados -Recurse -File | Sort-Object LastWriteTime | Select-Object -Last 1
        if ($g) {
            $ref = $g.Name + '|' + $g.LastWriteTime.ToString('o')
            if ($ref -ne $refVolcados) { $volcadoNuevo = 'SI:' + $g.Name; $refVolcados = $ref }
        }

        $linea = (@($ahora.ToString('yyyy-MM-dd HH:mm:ss'), $campos[1], $tempMem, $campos[2], $campos[3],
                    $campos[4], $campos[5], $campos[6], $campos[7], $campos[8], $campos[9], $campos[10],
                    $throttle, $pidTop, $memTop, $volcadoNuevo) -join ';')
        Add-Content -LiteralPath $log -Value $linea -Encoding UTF8
    }

    # Rotacion
    if (($n % 240) -eq 0) {
        Get-ChildItem -LiteralPath $dir -Filter 'gpu-*.csv' |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DiasConservar) } |
            Remove-Item -Force
    }

    $n++
    if ($Iteraciones -gt 0 -and $n -ge $Iteraciones) { break }
    Start-Sleep -Seconds $IntervaloSegundos
}
