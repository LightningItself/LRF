set TEST_NAME "hssim_random"
set SRC_DIR "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"

file mkdir $WORKSPACE_DIR

set INPUT_HEX_X      "${WORKSPACE_DIR}/inputs_x.hex"
set INPUT_HEX_Y      "${WORKSPACE_DIR}/inputs_y.hex"
set OUTPUT_HEX_PACKED "${WORKSPACE_DIR}/outputs_packed.hex"

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
add_files -fileset sources_1 ${SRC_DIR}/axis_buff.v
add_files -fileset sources_1 ${SRC_DIR}/axis_adder.v
add_files -fileset sources_1 ${SRC_DIR}/conv_gauss.v
add_files -fileset sources_1 ${SRC_DIR}/sig_xy.v
add_files -fileset sources_1 ${SRC_DIR}/axis_sub.v
add_files -fileset sources_1 ${SRC_DIR}/hssim.v

add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]
add_files -fileset sim_1 ${TEST_DIR}/tb_hssim.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_hssim.sv]

set_property include_dirs $WORKSPACE_DIR [get_filesets sim_1]

add_files -fileset sim_1 $INPUT_HEX_X $INPUT_HEX_Y $OUTPUT_HEX_PACKED

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set ABS_INPUT_HEX_X      [file normalize $INPUT_HEX_X]
set ABS_INPUT_HEX_Y      [file normalize $INPUT_HEX_Y]
set ABS_OUTPUT_HEX_PACKED [file normalize $OUTPUT_HEX_PACKED]

set_property -name {xsim.simulate.xsim.more_options} \
-value "-testplusarg IN_FILE_NAME_X=$ABS_INPUT_HEX_X -testplusarg IN_FILE_NAME_Y=$ABS_INPUT_HEX_Y -testplusarg OUT_FILE_NAME_PACKED=$ABS_OUTPUT_HEX_PACKED" \
-objects [get_filesets sim_1]

puts "Running simulation..."

launch_simulation
run all