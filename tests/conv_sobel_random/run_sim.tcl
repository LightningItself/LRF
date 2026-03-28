set TEST_NAME "conv_sobel_random"
set SRC_DIR "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"
# New path based on your screenshot
set IP_DIR "${SRC_DIR}/ips/cordic/cordic_0"

file mkdir $WORKSPACE_DIR

set INPUT_HEX "${WORKSPACE_DIR}/inputs.hex"
set OUTPUT_HEX "${WORKSPACE_DIR}/outputs.hex"

puts "Generating test pattern with expected outputs..."
puts ""

# -----------------------------
# Python (Environment Cleanup for Vivado's internal Python conflict)
# -----------------------------
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

# Running your updated generate_data.py
if {[catch {exec py $TEST_DIR/generate_data.py --input $INPUT_HEX --output $OUTPUT_HEX} result]} {
    puts "ERROR running Python script:\n$result"
    return -code error
} else {
    puts $result
}

if {$has_pythonhome} { set env(PYTHONHOME) $saved_pythonhome }
if {$has_pythonpath} { set env(PYTHONPATH) $saved_pythonpath }

# -----------------------------
# PROJECT
# -----------------------------
puts "Generating Vivado project..."
create_project -force sim_project ${WORKSPACE_DIR}/sim_project

# -----------------------------
# ADD CORDIC IP (Updated Path)
# -----------------------------
set IP_FILE "${IP_DIR}/cordic_0.xci"

if {[file exists $IP_FILE]} {
    add_files -norecurse $IP_FILE
    # Generate simulation targets
    generate_target all [get_files $IP_FILE]
    # Export sim sources
    export_ip_user_files -of_objects [get_files $IP_FILE] -no_script -sync -force -quiet
} else {
    puts "ERROR: CORDIC IP not found at $IP_FILE"
    return -code error
}

# -----------------------------
# RTL
# -----------------------------
add_files -fileset sources_1 ${SRC_DIR}/conv_sobel.v
# Add gauss if needed by sobel, otherwise leave as is
# add_files -fileset sources_1 ${SRC_DIR}/conv_gauss.v

# -----------------------------
# SIM FILES
# -----------------------------
# Adding the utility AXI stream master/slave models
if {[file exists ${UTILS_SV_DIR}/sim_axis.sv]} {
    add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
    set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]
}

add_files -fileset sim_1 ${TEST_DIR}/tb_axis_buff.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_axis_buff.sv]

add_files -fileset sim_1 ${TEST_DIR}/tb_config.svh

# -----------------------------
# INCLUDE DIR & HEX FILES
# -----------------------------
set_property include_dirs "${TEST_DIR}" [get_filesets sim_1]
add_files -fileset sim_1 [list $INPUT_HEX $OUTPUT_HEX]

# -----------------------------
# TOP CONFIGURATION
# -----------------------------
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Pass filenames to SystemVerilog via PlusArgs
set ABS_INPUT_HEX  [file normalize $INPUT_HEX]
set ABS_OUTPUT_HEX [file normalize $OUTPUT_HEX]

set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg IN_FILE_NAME=$ABS_INPUT_HEX -testplusarg OUT_FILE_NAME=$ABS_OUTPUT_HEX" \
    -objects [get_filesets sim_1]

# -----------------------------
# RUN SIMULATION
# -----------------------------
puts "Running simulation..."
launch_simulation
run all