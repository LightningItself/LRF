set TEST_NAME "fusion_random"
set SRC_DIR "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"

file mkdir $WORKSPACE_DIR

set INPUT_HEX_OLD    "${WORKSPACE_DIR}/inputs_old.hex"
set INPUT_HEX_NEW    "${WORKSPACE_DIR}/inputs_new.hex"
set INPUT_HEX_GAUSS  "${WORKSPACE_DIR}/inputs_gauss.hex"
set OUTPUT_HEX_FUSED "${WORKSPACE_DIR}/outputs_fused.hex"

puts "Generating test pattern with expected outputs..."
puts ""

set has_pythonhome [info exists env(PYTHONHOME)]
set has_pythonpath [info exists env(PYTHONPATH)]
if {$has_pythonhome} { set saved_pythonhome $env(PYTHONHOME); unset env(PYTHONHOME) }
if {$has_pythonpath} { set saved_pythonpath $env(PYTHONPATH); unset env(PYTHONPATH) }

if {[catch {exec py $TEST_DIR/generate_data.py --out_dir $WORKSPACE_DIR} result]} {
    puts "ERROR running Python script:\n$result"
    return -code error
} else {
    puts $result
}

if {$has_pythonhome} { set env(PYTHONHOME) $saved_pythonhome }
if {$has_pythonpath} { set env(PYTHONPATH) $saved_pythonpath }

puts "Generating vivado project..."

create_project -force sim_project ${WORKSPACE_DIR}/sim_project

add_files -fileset sources_1 ${SRC_DIR}/multiplier.v
add_files -fileset sources_1 ${SRC_DIR}/axis_adder_2.v
add_files -fileset sources_1 ${SRC_DIR}/fusion.v

add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]
add_files -fileset sim_1 ${TEST_DIR}/tb_fusion.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_fusion.sv]

set_property include_dirs [list $WORKSPACE_DIR $TEST_DIR] [get_filesets sim_1]

add_files -fileset sim_1 $INPUT_HEX_OLD $INPUT_HEX_NEW $INPUT_HEX_GAUSS $OUTPUT_HEX_FUSED

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set ABS_INPUT_HEX_OLD    [file normalize $INPUT_HEX_OLD]
set ABS_INPUT_HEX_NEW    [file normalize $INPUT_HEX_NEW]
set ABS_INPUT_HEX_GAUSS  [file normalize $INPUT_HEX_GAUSS]
set ABS_OUTPUT_HEX_FUSED [file normalize $OUTPUT_HEX_FUSED]

set_property -name {xsim.simulate.xsim.more_options} \
-value "-testplusarg IN_FILE_NAME_OLD=$ABS_INPUT_HEX_OLD -testplusarg IN_FILE_NAME_NEW=$ABS_INPUT_HEX_NEW -testplusarg IN_FILE_NAME_GAUSS=$ABS_INPUT_HEX_GAUSS -testplusarg OUT_FILE_NAME_FUSED=$ABS_OUTPUT_HEX_FUSED" \
-objects [get_filesets sim_1]

puts "Running simulation..."

launch_simulation
run all