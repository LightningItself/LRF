set TEST_NAME "lsu_random"
set SRC_DIR "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"

file mkdir $WORKSPACE_DIR

set INPUT_HEX "${WORKSPACE_DIR}/inputs.hex"
set OUTPUT_HEX "${WORKSPACE_DIR}/outputs.hex"

puts "Generating test pattern with expected outputs..."
puts ""

set has_pythonhome [info exists env(PYTHONHOME)]
set has_pythonpath [info exists env(PYTHONPATH)]
if {$has_pythonhome} { set saved_pythonhome $env(PYTHONHOME); unset env(PYTHONHOME) }
if {$has_pythonpath} { set saved_pythonpath $env(PYTHONPATH); unset env(PYTHONPATH) }

if {[catch {exec py $TEST_DIR/generate_data.py --input $INPUT_HEX --output $OUTPUT_HEX} result]} {
    puts "ERROR running Python script:\n$result"
    return -code error
} else {
    puts $result
}

if {$has_pythonhome} { set env(PYTHONHOME) $saved_pythonhome }
if {$has_pythonpath} { set env(PYTHONPATH) $saved_pythonpath }


puts "Generating vivado project..."

create_project -force sim_project ${WORKSPACE_DIR}/sim_project

add_files -fileset sources_1 ${SRC_DIR}/lsu.v

add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]

add_files -fileset sim_1 ${TEST_DIR}/tb_lsu.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_lsu.sv]

set_property include_dirs $WORKSPACE_DIR [get_filesets sim_1]

add_files -fileset sim_1 $INPUT_HEX $OUTPUT_HEX

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set ABS_INPUT_HEX  [file normalize $INPUT_HEX]
set ABS_OUTPUT_HEX [file normalize $OUTPUT_HEX]
set_property -name {xsim.simulate.xsim.more_options} \
             -value "-testplusarg IN_FILE_NAME=$ABS_INPUT_HEX -testplusarg OUT_FILE_NAME=$ABS_OUTPUT_HEX" \
             -objects [get_filesets sim_1]

puts "Running simulation..."
launch_simulation
run all