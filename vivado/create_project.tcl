# Vivado Tcl 脚本：创建通用 RISC-V CPU 工程并运行综合。
# 工程优先使用 Zynq-7020；如果本机未安装该器件数据，则回退到可用的
# 7 系列器件，仅做逻辑综合检查。

# 确定项目真实根目录，允许 PowerShell 通过环境变量传入本地绝对路径。
if {[info exists ::env(RISCV_CPU_ROOT)] && ($::env(RISCV_CPU_ROOT) ne "")} {
    set root [file normalize $::env(RISCV_CPU_ROOT)]
} else {
    set script_dir [file normalize [file dirname [info script]]]
    set root [file normalize [file join $script_dir ".."]]
}
# 工程放在项目根目录下的 vivado_project，默认优先器件为 Zynq-7020。
set project_dir [file join $root "vivado_project"]
set preferred_part "xc7z020clg400-1"
set fallback_part "xc7k70tfbv676-1"

# 根据当前 Vivado 安装的器件数据选择首选器件或回退器件。
if {[lsearch -exact [get_parts] $preferred_part] >= 0} {
    set part_name $preferred_part
} elseif {[lsearch -exact [get_parts] $fallback_part] >= 0} {
    set part_name $fallback_part
} else {
    set part_name [lindex [get_parts] 0]
}

# 强制重建工程，并把所有 RTL 和头文件加入 sources_1。
create_project riscv_cpu_pipeline $project_dir -part $part_name -force

set rtl_files [concat \
    [glob -nocomplain [file join $root "rtl" "*.v"]] \
    [glob -nocomplain [file join $root "rtl" "*.vh"]]]
add_files -fileset sources_1 $rtl_files

# 设置头文件搜索路径和顶层模块，然后刷新编译顺序。
set_property include_dirs [list [file join $root "rtl"]] [current_fileset]
set_property top riscv_cpu [current_fileset]
update_compile_order -fileset sources_1

puts "Created generic RISC-V CPU project at $project_dir"
puts "Part: $part_name"

# 启动综合并等待完成，最后检查进度必须达到 100%。
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_progress [get_property PROGRESS [get_runs synth_1]]
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis progress: $synth_progress"
puts "Synthesis status: $synth_status"

if {$synth_progress ne "100%"} {
    error "Synthesis did not complete: $synth_status"
}
