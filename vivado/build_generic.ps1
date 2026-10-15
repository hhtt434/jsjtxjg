# 通用 Vivado 综合辅助脚本。
# 由于当前工作区路径会触发本机 Vivado 的 Tcl 工作目录解析问题，脚本先临时
# 映射一个盘符，再让 Vivado 使用真实本地路径创建并综合工程。
$ErrorActionPreference = "Stop"

# 定位项目根目录和本机 Vivado 可执行文件。
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$vivado = "C:\Xilinx\Vivado\2024.2\bin\vivado.bat"

if (-not (Test-Path $vivado)) {
    throw "Vivado 2024.2 was not found at $vivado"
}

# 从候选盘符中选择一个未被占用的盘符。
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

# 建立临时盘符映射，使 Vivado 能正常加载 Tcl 初始化文件。
& subst $drive $root
if ($LASTEXITCODE -ne 0) {
    throw "Failed to map $drive to $root"
}

# 保存旧环境变量和当前目录，便于 finally 中恢复。
$previousRoot = $env:RISCV_CPU_ROOT
$previousLocation = (Get-Location).Path
# create_project.tcl 通过该环境变量取得真实工程根目录。
$env:RISCV_CPU_ROOT = $root

try {
    # 从 C:\ 启动，避开 Vivado 对深层工作目录的错误解析。
    Set-Location "C:\"
    $source = Join-Path "$drive\" "vivado\create_project.tcl"
    & $vivado -mode batch -nolog -nojournal -source $source
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado synthesis failed with exit code $LASTEXITCODE"
    }
}
finally {
    # 恢复目录、环境和盘符映射，避免污染后续命令。
    Set-Location $previousLocation
    $env:RISCV_CPU_ROOT = $previousRoot
    & subst $drive /D
}
