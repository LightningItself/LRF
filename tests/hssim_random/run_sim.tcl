set TEST_NAME     "hssim_random"
set SRC_DIR       "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR      "../tests/${TEST_NAME}"
set UTILS_SV_DIR  "../utils/sv"

# FIX: Get the true absolute launch directory before Vivado shifts its internal directory focus
set LAUNCH_DIR    [pwd]

set INPUT_OLD_HEX "${WORKSPACE_DIR}/input_old.hex"
set INPUT_AVG_HEX "${WORKSPACE_DIR}/input_avg.hex"
set INPUT_NEW_HEX "${WORKSPACE_DIR}/input_new.hex"
set OUTPUT_HEX    "${WORKSPACE_DIR}/outputs.hex"

file mkdir $WORKSPACE_DIR

puts "--- \[TCL\] Step 1: Running Python Data Generator ---"

set has_pythonhome [info exists env(PYTHONHOME)]
set has_pythonpath [info exists env(PYTHONPATH)]

if {$has_pythonhome} {
    set saved_pythonhome $env(PYTHONHOME)
    unset env(PYTHONHOME)
}
if {$has_pythonpath} {
    set saved_pythonpath $env(PYTHONPATH)
    unset env(PYTHONPATH)
}

if {[catch {
    exec py $TEST_DIR/generate_data.py \
        --input_old $INPUT_OLD_HEX \
        --input_avg $INPUT_AVG_HEX \
        --input_new $INPUT_NEW_HEX \
        --output    $OUTPUT_HEX
} result]} {
    puts "ERROR running Python script:\n$result"
    return -code error
} else {
    puts $result
}

if {$has_pythonhome} {
    set env(PYTHONHOME) $saved_pythonhome
}
if {$has_pythonpath} {
    set env(PYTHONPATH) $saved_pythonpath
}

puts "--- \[TCL\] Step 2: Creating Vivado Project ---"

create_project -force sim_project ${WORKSPACE_DIR}/sim_project

add_files -fileset sources_1 [file normalize ${SRC_DIR}/multiplier.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/conv_gauss.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/axis_sub.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/sig_xy.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/axis_adder.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/hssim.v]
update_compile_order -fileset sources_1

add_files -fileset sim_1 [file normalize ${UTILS_SV_DIR}/sim_axis.sv]
set_property file_type SystemVerilog \
    [get_files ${UTILS_SV_DIR}/sim_axis.sv]

add_files -fileset sim_1 [file normalize ${TEST_DIR}/tb_hssim.sv]
set_property file_type SystemVerilog \
    [get_files ${TEST_DIR}/tb_hssim.sv]

set_property include_dirs \
    [file normalize $WORKSPACE_DIR] \
    [get_filesets sim_1]

add_files -fileset sim_1 [file normalize $INPUT_OLD_HEX]
add_files -fileset sim_1 [file normalize $INPUT_AVG_HEX]
add_files -fileset sim_1 [file normalize $INPUT_NEW_HEX]
add_files -fileset sim_1 [file normalize $OUTPUT_HEX]

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# FIX: Explicitly normalize these relative to our captured launch workspace directory
set ABS_INPUT_OLD_HEX [file normalize [file join $LAUNCH_DIR $INPUT_OLD_HEX]]
set ABS_INPUT_AVG_HEX [file normalize [file join $LAUNCH_DIR $INPUT_AVG_HEX]]
set ABS_INPUT_NEW_HEX [file normalize [file join $LAUNCH_DIR $INPUT_NEW_HEX]]
set ABS_OUTPUT_HEX    [file normalize [file join $LAUNCH_DIR $OUTPUT_HEX]]

# FIX: Wrapped option values securely inside clean quotes to handle system separator spacing issues
set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg IN_FILE_NAME_0=\"$ABS_INPUT_OLD_HEX\" \
            -testplusarg IN_FILE_NAME_1=\"$ABS_INPUT_AVG_HEX\" \
            -testplusarg IN_FILE_NAME_2=\"$ABS_INPUT_NEW_HEX\" \
            -testplusarg OUT_FILE_NAME_0=\"$ABS_OUTPUT_HEX\"" \
    -objects [get_filesets sim_1]

puts "--- \[TCL\] Step 3: Launching Simulation ---"

launch_simulation
run all