<#
.SYNOPSIS
    Consulta del hardware del equipo (PowerShell 5.1).
    Equivalente a ~/.config/opencode/hardware-query.sh en Linux.

.DESCRIPTION
    Muestra informacion de CPU, GPU, RAM, discos y red usando cmdlets CIM.
    Toda la salida en tablas y en espanol.

.PARAMETER Campo
    Valores: cpu, gpu, ram, disco, red, todo (por defecto: todo).

.EXAMPLE
    .\hardware-query.ps1 cpu
    .\hardware-query.ps1 gpu
    .\hardware-query.ps1 todo
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('cpu', 'gpu', 'ram', 'disco', 'red', 'todo')]
    [string]$Campo = 'todo'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'

function Format-GB([double]$bytes) {
    if ($bytes -le 0) { return '0' }
    $gb = $bytes / 1GB
    return ('{0:N1}' -f $gb).Replace('.', ',').Replace(' ', '')
}

function Get-InfoCpu {
    Write-Output ''
    Write-Output '== 💻 CPU =='
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cpu) {
        $tabla = [PSCustomObject]@{
            'Nombre' = $cpu.Name
            'Nucleos' = $cpu.NumberOfCores
            'Hilos' = $cpu.NumberOfLogicalProcessors
            'Velocidad (GHz)' = '{0:N1}' -f ($cpu.MaxClockSpeed / 1000)
        }
        $tabla | Format-List | Out-String | Write-Output
    } else {
        Write-Output '  (no se pudo consultar la CPU)'
    }
}

function Get-InfoGpu {
    Write-Output ''
    Write-Output '== 🎮 GPU =='
    $gpus = Get-CimInstance Win32_VideoController
    if ($gpus) {
        $rows = @()
        foreach ($g in $gpus) {
            $mem = if ($g.AdapterRAM -gt 0) { Format-GB ([double]$g.AdapterRAM) } else { 'n/d' }
            $rows += [PSCustomObject]@{
                'Nombre' = $g.Name
                'VRAM (GB)' = $mem
                'Controlador' = $g.DriverVersion
            }
        }
        $rows | Format-Table -AutoSize | Out-String | Write-Output
    } else {
        Write-Output '  (no se detectaron GPUs)'
    }
}

function Get-InfoRam {
    Write-Output ''
    Write-Output '== 🧠 RAM =='
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs) {
        $ram = Format-GB ([double]$cs.TotalPhysicalMemory)
        $tabla = [PSCustomObject]@{
            'Memoria total (GB)' = $ram
            'Fabricante' = $cs.Manufacturer
            'Modelo' = $cs.Model
        }
        $tabla | Format-List | Out-String | Write-Output
    } else {
        Write-Output '  (no se pudo consultar la RAM)'
    }
}

function Get-InfoDisco {
    Write-Output ''
    Write-Output '== 💾 Discos =='
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($disks) {
        $rows = @()
        foreach ($d in $disks) {
            $rows += [PSCustomObject]@{
                'Nombre' = $d.FriendlyName
                'Tipo' = $d.MediaType
                'Tamano (GB)' = Format-GB ([double]$d.Size)
                'Estado' = $d.HealthStatus
            }
        }
        Write-Output '  --- Unidades fisicas ---'
        $rows | Format-Table -AutoSize | Out-String | Write-Output
    }

    Write-Output '  --- Volumenes montados ---'
    $ps = Get-PSDrive -PSProvider FileSystem
    $rows2 = @()
    foreach ($d in $ps) {
        if ($null -eq $d.Used -or $null -eq $d.Free) { continue }
        $rows2 += [PSCustomObject]@{
            'Unidad' = $d.Name
            'Tamano (GB)' = Format-GB ([double]($d.Used + $d.Free))
            'Libre (GB)' = Format-GB ([double]$d.Free)
            'Usado (GB)' = Format-GB ([double]$d.Used)
        }
    }
    $rows2 | Format-Table -AutoSize | Out-String | Write-Output
}

function Get-InfoRed {
    Write-Output ''
    Write-Output '== 🌐 Red =='
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    if ($adapters) {
        $rows = @()
        foreach ($a in $adapters) {
            $vel = if ($a.LinkSpeed) { ('{0:N0}' -f ($a.LinkSpeed / 1MB)).Replace('.', ',').Replace(' ', '') } else { 'n/d' }
            $rows += [PSCustomObject]@{
                'Nombre' = $a.Name
                'Estado' = $a.Status
                'Velocidad (Mbps)' = $vel
            }
        }
        $rows | Format-Table -AutoSize | Out-String | Write-Output
    } else {
        Write-Output '  (no se pudieron consultar los adaptadores de red)'
    }
}

function Get-Resumen {
    Write-Output ''
    Write-Output '== 📋 Resumen =='
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $cs = Get-CimInstance Win32_ComputerSystem
    $disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $null -ne $_.Free -and $null -ne $_.Used } | Measure-Object -Property Free -Sum

    $linea = '   💻 ' + $(if ($cpu) { $cpu.Name.Trim() } else { 'n/d' }) + ' | '
    $linea += '🎮 ' + $(if ($gpu) { $gpu.Name.Trim() } else { 'n/d' }) + ' | '
    $linea += '🧠 ' + $(if ($cs) { Format-GB ([double]$cs.TotalPhysicalMemory) } else { 'n/d' }) + ' GB RAM'
    Write-Output $linea
    $linea2 = '   💾 Espacio libre total: ' + $(if ($disk.Sum) { Format-GB ([double]$disk.Sum) } else { '0' }) + ' GB'
    Write-Output $linea2
    Write-Output ''
}

switch ($Campo) {
    'cpu'   { Get-InfoCpu }
    'gpu'   { Get-InfoGpu }
    'ram'   { Get-InfoRam }
    'disco' { Get-InfoDisco }
    'red'   { Get-InfoRed }
    'todo'  {
        Get-InfoCpu
        Get-InfoGpu
        Get-InfoRam
        Get-InfoDisco
        Get-InfoRed
        Get-Resumen
    }
}