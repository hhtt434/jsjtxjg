# Five-Stage RISC-V CPU

本工程实现课程设计要求的五级流水线 RISC-V CPU，包含基础指令、扩展指令、
数据转发、Load-use 冒险处理，以及定制 `mac` 指令。

## 已支持指令

- 基础指令：`add`、`slt`、`sltu`、`ori`、`lw`、`sw`、`beq`、`jal`、`lui`
- 移位扩展：`sll`、`srl`、`sra`、`slli`、`srli`、`srai`
- 分支扩展：`bne`、`blt`、`bge`
- 其他扩展：`addi`、`auipc`
- 定制指令：`mac rd, rs1, rs2`，执行 `rd = rd + low32(rs1 * rs2)`

`mac` 使用 `custom-0` 主操作码 `0001011`，编码为
`funct7=0000000, funct3=000, opcode=0001011`。

## 目录

- `rtl/`：可综合 Verilog RTL
- `tb/`：ModelSim 自检测试平台
- `tb/programs/`：汇编测试程序和生成的 hex 文件
- `tools/assemble.py`：项目指令子集汇编器
- `sim/run_all.ps1`：一键运行全部 ModelSim 测试
- `vivado/create_project.tcl`：创建通用 Zynq-7020 工程
- `docs/`：设计说明和实现计划

## 运行仿真

在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\sim\run_all.ps1
```

脚本会重新生成测试程序，编译全部 RTL 和测试平台，并依次运行：

- ALU、立即数、控制译码、寄存器堆、转发和冒险检测单元测试
- 基础指令与扩展指令集成测试
- 转发和 Load-use 集成测试
- 分支、跳转和控制冒险集成测试

全部通过后输出 `ALL TESTS PASS`。

## 通用 Vivado 工程

当前没有指定开发板具体型号，因此工程优先使用
`xc7z020clg400-1` 器件，仅用于综合和资源检查，不包含板级引脚约束。
如果本机 Vivado 未安装 Zynq-7020 器件数据，脚本会自动回退到可用的
7 系列器件完成综合检查。

```powershell
powershell -ExecutionPolicy Bypass -File .\vivado\build_generic.ps1
```

脚本会临时映射一个 Windows 盘符，避免 Vivado 在包含层级较多的路径下
初始化 Tcl 时出现工作目录解析问题。

## 自定义测试程序

汇编文件支持标签、十六进制或十进制立即数。例如：

```asm
ori x1, x0, 10
ori x2, x0, 20
add x3, x1, x2
mac x4, x3, x1
sw  x4, 0(x0)
lw  x5, 0(x0)
jal x0, 0
```

生成 ModelSim `$readmemh` 文件：

```powershell
python tools\assemble.py program.S -o program.hex
```
