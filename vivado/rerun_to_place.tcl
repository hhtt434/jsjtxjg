# 功能：重新综合并运行到 place_design，验证旧版空设计错误已经消失。
# 使用方式：关闭 Vivado 图形界面后，在项目根目录执行
# vivado -mode batch -source vivado/rerun_to_place.tcl

set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir ".."]]
set project_file [file join $root "vivado_project" "riscv_cpu_pipeline.xpr"]

if {![file exists $project_file]} {
    error "Vivado project not found: $project_file"
}

# 打开工程后先清除旧的 synth_1、impl_1 失败状态和旧网表。
open_project $project_file
reset_run synth_1
reset_run impl_1

# 重新综合。必须等待综合完成后才能启动实现，否则实现仍会使用旧网表。
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "SYNTH_PROGRESS=[get_property PROGRESS [get_runs synth_1]]"
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis failed; place_design was not started."
}

# 只运行到 place_design，不继续路由和生成比特流。
launch_runs impl_1 -to_step place_design -jobs 4
wait_on_run impl_1
puts "IMPLEMENTATION_PROGRESS=[get_property PROGRESS [get_runs impl_1]]"
puts "IMPLEMENTATION_STATUS=[get_property STATUS [get_runs impl_1]]"

# 有 placed checkpoint 说明 place_design 已经实际完成。
set impl_dir [get_property DIRECTORY [get_runs impl_1]]
set placed_dcp [file join $impl_dir "riscv_cpu_placed.dcp"]
if {![file exists $placed_dcp]} {
    error "place_design checkpoint not found: $placed_dcp"
}

puts "PLACE_DESIGN_COMPLETE: $placed_dcp"
