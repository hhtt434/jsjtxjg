# 一键运行 ModelSim 全量回归测试。
# 流程：生成测试 hex、创建 work 库、编译 RTL/测试平台，逐个运行测试，
# 并同时检查退出码、TEST PASS 文本和 ModelSim Error 文本。
$ErrorActionPreference = "Stop"

# 计算项目根目录和 ModelSim 工作库目录。
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$work = Join-Path $PSScriptRoot "work"
# 收集所有 RTL Verilog 源文件。
$sources = Get-ChildItem (Join-Path $root "rtl\*.v") | ForEach-Object { $_.FullName }
# 单元测试清单：每个模块独立验证。
$unitTests = @(
    "tb_alu",
    "tb_imm_gen",
    "tb_control_unit",
    "tb_regfile",
    "tb_forwarding_unit",
    "tb_hazard_unit"
)
# CPU 集成测试清单：分别验证指令、冒险和控制流。
$cpuTests = @(
    "tb_cpu_base",
    "tb_cpu_hazards",
    "tb_cpu_control"
)

# 通用命令执行函数：打印完整输出，并在外部命令返回非零时立即报错。
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
    # 每次测试前重新汇编源码，确保 hex 与 .S 文件一致。
    python tools\assemble.py tb\programs\base.S -o tb\programs\base.hex
    python tools\assemble.py tb\programs\hazards.S -o tb\programs\hazards.hex
    python tools\assemble.py tb\programs\control.S -o tb\programs\control.hex

    # 重建干净工作库，避免旧编译结果掩盖源文件错误。
    if (Test-Path $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work | Out-Null
    # 创建库并编译全部 RTL 与测试平台。
    Invoke-Checked "vlib" { vlib $work }
    Invoke-Checked "vlog" {
        vlog -work $work +incdir+$root\rtl $sources `
            $cpuTests.ForEach({ Join-Path $root "tb\$_.v" }) `
            $unitTests.ForEach({ Join-Path $root "tb\$_.v" })
    }

    # 逐个运行 ModelSim，脚本级检查测试是否真正输出 PASS。
    foreach ($test in ($unitTests + $cpuTests)) {
        # Windows PowerShell 会把 vsim 的非致命 stderr 文本包装成错误记录。
        # 这里临时允许继续执行，最终仍由退出码和 TEST PASS 文本严格判定。
        $savedErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = & vsim -c -work $work $test -do "run -all; quit -f" 2>&1
        $vsimExitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorAction
        $output | ForEach-Object { Write-Host $_ }
        $text = $output -join "`n"
        if (($vsimExitCode -ne 0) -or
            ($text -notmatch "TEST PASS: $test") -or
            ($text -match "TEST FAIL:|Error:")) {
            throw "$test failed"
        }
    }
}
finally {
    # 无论测试是否失败，都恢复到调用脚本前的当前目录。
    Pop-Location
}

# 所有测试均通过时输出统一成功标记。
Write-Host "ALL TESTS PASS"
