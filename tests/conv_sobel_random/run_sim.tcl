set TEST_NAME "conv_sobel_random"
set SRC_DIR "../src"
set WORKSPACE_DIR [file normalize "./${TEST_NAME}"]
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"
set IP_DIR "${SRC_DIR}/ips/cordic/cordic_0"

# Clean and recreate workspace
if {[file exists $WORKSPACE_DIR]} { file delete -force $WORKSPACE_DIR }
file mkdir $WORKSPACE_DIR

set INPUT_HEX "${WORKSPACE_DIR}/inputs.hex"
set OUTPUT_HEX "${WORKSPACE_DIR}/outputs.hex"

puts "Generating test pattern with expected outputs..."
puts ""

# -----------------------------
# Python (Environment Cleanup)
# -----------------------------
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

# -----------------------------
# PROJECT (Note: Replace with your actual part number if different)
# -----------------------------
puts "Generating Vivado project..."
create_project -force sim_project ${WORKSPACE_DIR}/sim_project -part xc7z010clg225-1

# -----------------------------
# ADD CORDIC IP (Using IMPORT to keep .gen in Workspace)
# -----------------------------
set IP_FILE "${IP_DIR}/cordic_0.xci"

if {[file exists $IP_FILE]} {
    # This command copies the IP into the project workspace
    import_ip -files $IP_FILE -name cordic_0
    
    # Generate targets locally in the workspace
    generate_target all [get_ips cordic_0]
    export_ip_user_files -of_objects [get_ips cordic_0] -no_script -sync -force -quiet
} else {
    puts "ERROR: CORDIC IP not found at $IP_FILE"
    return -code error
}

# -----------------------------
# RTL & SIM FILES
# -----------------------------
add_files -fileset sources_1 ${SRC_DIR}/conv_sobel.v

if {[file exists ${UTILS_SV_DIR}/sim_axis.sv]} {
    add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
    set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]
}

add_files -fileset sim_1 ${TEST_DIR}/tb_axis_buff.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_axis_buff.sv]

# Include the generated config from workspace
add_files -fileset sim_1 ${WORKSPACE_DIR}/tb_config.svh

# -----------------------------
# CONFIGURATION & RUN
# -----------------------------
set_property include_dirs [list "${TEST_DIR}" "${WORKSPACE_DIR}"] [get_filesets sim_1]
add_files -fileset sim_1 [list $INPUT_HEX $OUTPUT_HEX]

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg IN_FILE_NAME=$INPUT_HEX -testplusarg OUT_FILE_NAME=$OUTPUT_HEX" \
    -objects [get_filesets sim_1]

puts "Running simulation..."
launch_simulation
run all