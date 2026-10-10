<#
.SYNOPSIS
    Volcado completo del sistema para el informe de hardware (Windows / PowerShell 5.1).

.DESCRIPTION
    Recopila los bloques que en Linux genera `sysinfo-priv.sh` con pkexec:
    sistema/BIOS/placa, CPU, modulos de RAM, GPU (nvidia-smi), discos, red, monitores y
    Bluetooth. Es de SOLO LECTURA. Para BIOS/placa/discos conviene ejecutarlo elevado (UAC).

    Equivalente Windows de `documentacion/09-informe-sistema.md`.
    Ver tambien `hardware-query.ps1` (resumen rapido) y la funcion `hw_query`.

.PARAMETER OutFile
    Ruta del fichero de salida. Si se omite, vuelca por pantalla.

.EXAMPLE
    .\sysinfo.ps1
    .\sysinfo.ps1 -OutFile "$env:USERPROFILE\informe-sistema-sysinfo.txt"
#>
[CmdletBinding()]
param(
    [string]$OutFile = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$script:lineas = New-Object System.Collections.ArrayList

function Emit([string]$s) {
    [void]$script:lineas.Add([string]$s)
    if (-not $OutFile) { Write-Host $s }
}
function Section([string]$t) {
    Emit ''
    Emit ('#################### ' + $t + ' ####################')
}
function Dump([string]$t, [scriptblock]$b) {
    Section $t
    & $b
}
function Tabla($objetos) {
    Emit (($objetos | Format-Table -AutoSize | Out-String).TrimEnd())
}
function Lista($objetos) {
    Emit (($objetos | Format-List | Out-String).TrimEnd())
}

Dump 'SISTEMA / BIOS / PLACA' {
    Lista (Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,@{n='RAM (GB)';e={ '{0:N1}' -f ($_.TotalPhysicalMemory/1GB) }},SystemType)
    Lista (Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber)
    Lista (Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version,SerialNumber)
}

Dump 'CPU' {
    Lista (Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,Architecture)
}

Dump 'RAM (modulos)' {
    Tabla (Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,DeviceLocator,@{n='Capacity (GB)';e={ '{0:N1}' -f ($_.Capacity/1GB) }},Speed,Manufacturer,PartNumber)
}

Dump 'GPU' {
    Emit ((nvidia-smi 2>&1 | Out-String).TrimEnd())
    Emit ((nvidia-smi -q 2>&1 | Out-String).TrimEnd())
    Tabla (Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate)
}

Dump 'DISCOS' {
    Tabla (Get-PhysicalDisk | Select-Object FriendlyName,MediaType,BusType,@{n='Size (GB)';e={ '{0:N1}' -f ($_.Size/1GB) }},HealthStatus,OperationalStatus)
    Tabla (Get-Disk | Select-Object Number,FriendlyName,PartitionStyle,@{n='Size (GB)';e={ '{0:N1}' -f ($_.Size/1GB) }},HealthStatus)
    Tabla (Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,@{n='Free (GB)';e={ '{0:N1}' -f ($_.SizeRemaining/1GB) }},@{n='Size (GB)';e={ '{0:N1}' -f ($_.Size/1GB) }})
}

Dump 'RED' {
    Tabla (Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress)
    Emit ((ipconfig /all 2>&1 | Out-String).TrimEnd())
}

Dump 'MONITORES' {
    Lista (Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams)
}

Dump 'BLUETOOTH' {
    Tabla (Get-PnpDevice -Class Bluetooth | Select-Object Status,FriendlyName)
}

if ($OutFile) {
    $script:lineas -join [Environment]::NewLine | Set-Content -LiteralPath $OutFile -Encoding UTF8
    Write-Host ''
    Write-Host ('🟢 Informe escrito en: ' + $OutFile + '  (' + $script:lineas.Count + ' entradas)')
}
