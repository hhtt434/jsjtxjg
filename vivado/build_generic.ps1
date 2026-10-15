$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$vivado = "C:\Xilinx\Vivado\2024.2\bin\vivado.bat"

if (-not (Test-Path $vivado)) {
    throw "Vivado 2024.2 was not found at $vivado"
}

$drive = $null
foreach ($letter in @("X", "Y", "Z", "W", "V")) {
    if (-not (Test-Path "${letter}:\")) {
        $drive = "${letter}:"
        break
    }
}
if (-not $drive) {
    throw "No free drive letter is available for the Vivado path mapping"
}

& subst $drive $root
if ($LASTEXITCODE -ne 0) {
    throw "Failed to map $drive to $root"
}

$previousRoot = $env:RISCV_CPU_ROOT
$previousLocation = (Get-Location).Path
$env:RISCV_CPU_ROOT = $root

try {
    Set-Location "C:\"
    $source = Join-Path "$drive\" "vivado\create_project.tcl"
    & $vivado -mode batch -nolog -nojournal -source $source
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado synthesis failed with exit code $LASTEXITCODE"
    }
}
finally {
    Set-Location $previousLocation
    $env:RISCV_CPU_ROOT = $previousRoot
    & subst $drive /D
}
