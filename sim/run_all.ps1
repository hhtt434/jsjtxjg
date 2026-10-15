$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$work = Join-Path $PSScriptRoot "work"
$sources = Get-ChildItem (Join-Path $root "rtl\*.v") | ForEach-Object { $_.FullName }
$unitTests = @(
    "tb_alu",
    "tb_imm_gen",
    "tb_control_unit",
    "tb_regfile",
    "tb_forwarding_unit",
    "tb_hazard_unit"
)
$cpuTests = @(
    "tb_cpu_base",
    "tb_cpu_hazards",
    "tb_cpu_control"
)

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [scriptblock] $Command
    )

    $output = & $Command 2>&1
    $output | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

Push-Location $root
try {
    python tools\assemble.py tb\programs\base.S -o tb\programs\base.hex
    python tools\assemble.py tb\programs\hazards.S -o tb\programs\hazards.hex
    python tools\assemble.py tb\programs\control.S -o tb\programs\control.hex

    if (Test-Path $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work | Out-Null
    Invoke-Checked "vlib" { vlib $work }
    Invoke-Checked "vlog" {
        vlog -work $work +incdir+$root\rtl $sources `
            $cpuTests.ForEach({ Join-Path $root "tb\$_.v" }) `
            $unitTests.ForEach({ Join-Path $root "tb\$_.v" })
    }

    foreach ($test in ($unitTests + $cpuTests)) {
        $output = & vsim -c -work $work $test -do "run -all; quit -f" 2>&1
        $output | ForEach-Object { Write-Host $_ }
        $text = $output -join "`n"
        if (($LASTEXITCODE -ne 0) -or
            ($text -notmatch "TEST PASS: $test") -or
            ($text -match "TEST FAIL:|Error:")) {
            throw "$test failed"
        }
    }
}
finally {
    Pop-Location
}

Write-Host "ALL TESTS PASS"
