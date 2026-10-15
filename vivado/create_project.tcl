if {[info exists ::env(RISCV_CPU_ROOT)] && ($::env(RISCV_CPU_ROOT) ne "")} {
    set root [file normalize $::env(RISCV_CPU_ROOT)]
} else {
    set script_dir [file normalize [file dirname [info script]]]
    set root [file normalize [file join $script_dir ".."]]
}
set project_dir [file join $root "vivado_project"]
set preferred_part "xc7z020clg400-1"
set fallback_part "xc7k70tfbv676-1"

if {[lsearch -exact [get_parts] $preferred_part] >= 0} {
    set part_name $preferred_part
} elseif {[lsearch -exact [get_parts] $fallback_part] >= 0} {
    set part_name $fallback_part
} else {
    set part_name [lindex [get_parts] 0]
}

create_project riscv_cpu_pipeline $project_dir -part $part_name -force

set rtl_files [concat \
    [glob -nocomplain [file join $root "rtl" "*.v"]] \
    [glob -nocomplain [file join $root "rtl" "*.vh"]]]
add_files -fileset sources_1 $rtl_files

set_property include_dirs [list [file join $root "rtl"]] [current_fileset]
set_property top riscv_cpu [current_fileset]
update_compile_order -fileset sources_1

puts "Created generic RISC-V CPU project at $project_dir"
puts "Part: $part_name"

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_progress [get_property PROGRESS [get_runs synth_1]]
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis progress: $synth_progress"
puts "Synthesis status: $synth_status"

if {$synth_progress ne "100%"} {
    error "Synthesis did not complete: $synth_status"
}
