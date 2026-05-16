#===========================================================
# Vivado Simulation Automation Script - SIG_XY
#===========================================================

# 1. Define Paths and Project Settings
set TEST_NAME     "sig_xy_random"
set SRC_DIR       "../src"
set WORKSPACE_DIR "./${TEST_NAME}"
set TEST_DIR      "../tests/${TEST_NAME}"
set UTILS_SV_DIR  "../utils/sv"

# Define Hex file paths for simulation
set INPUT_HEX_X   "${WORKSPACE_DIR}/inputs_x.hex"
set INPUT_HEX_Y   "${WORKSPACE_DIR}/inputs_y.hex"
set OUTPUT_HEX    "${WORKSPACE_DIR}/outputs.hex"

# Create the workspace directory if it doesn't exist
file mkdir $WORKSPACE_DIR

puts "--- \[TCL\] Step 1: Running Python Data Generator ---"

# Handle Python environment variables (avoids common PATH issues in batch mode)
set has_pythonhome [info exists env(PYTHONHOME)]
set has_pythonpath [info exists env(PYTHONPATH)]
if {$has_pythonhome} { set saved_pythonhome $env(PYTHONHOME); unset env(PYTHONHOME) }
if {$has_pythonpath} { set saved_pythonpath $env(PYTHONPATH); unset env(PYTHONPATH) }

# Execute the Python script and capture results
# Note: uses 'py' as per your environment; change to 'python' if necessary
if {[catch {exec py $TEST_DIR/generate_data.py --input_x $INPUT_HEX_X --input_y $INPUT_HEX_Y --output $OUTPUT_HEX} result]} {
    puts "ERROR running Python script:\n$result"
    return -code error
} else {
    puts $result
}

# Restore Python environment variables
if {$has_pythonhome} { set env(PYTHONHOME) $saved_pythonhome }
if {$has_pythonpath} { set env(PYTHONPATH) $saved_pythonpath }

puts "--- \[TCL\] Step 2: Creating Vivado Project ---"

# Create a clean project in the workspace
create_project -force sim_project ${WORKSPACE_DIR}/sim_project

# 2. Add Source Files
# Added multiplier.v to fix the "Module <MULTIPLIER> not found" error
add_files -fileset sources_1 [file normalize ${SRC_DIR}/multiplier.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/conv_gauss.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/sig_xy.v]
add_files -fileset sources_1 [file normalize ${SRC_DIR}/axis_sub.v]


# Ensure the hierarchy is updated
update_compile_order -fileset sources_1

# 3. Add Simulation Files
add_files -fileset sim_1 [file normalize ${UTILS_SV_DIR}/sim_axis.sv]
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]

add_files -fileset sim_1 [file normalize ${TEST_DIR}/tb_sig.sv]
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_sig.sv]

# 4. CRITICAL: Set Include Directories for Macros
# This allows `include "tb_config.svh" to work inside the testbench
set_property include_dirs [file normalize $WORKSPACE_DIR] [get_filesets sim_1]

# 5. Add Test Data Files to the simulation fileset
add_files -fileset sim_1 [file normalize $INPUT_HEX_X] 
add_files -fileset sim_1 [file normalize $INPUT_HEX_Y] 
add_files -fileset sim_1 [file normalize $OUTPUT_HEX]

# 6. Configure Simulation Settings
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set plusargs so the simulation classes can find the generated hex files
set ABS_INPUT_HEX_X [file normalize $INPUT_HEX_X]
set ABS_INPUT_HEX_Y [file normalize $INPUT_HEX_Y]
set ABS_OUTPUT_HEX  [file normalize $OUTPUT_HEX]

set_property -name {xsim.simulate.xsim.more_options} \
             -value "-testplusarg IN_FILE_NAME_X=$ABS_INPUT_HEX_X -testplusarg IN_FILE_NAME_Y=$ABS_INPUT_HEX_Y -testplusarg OUT_FILE_NAME=$ABS_OUTPUT_HEX" \
             -objects [get_filesets sim_1]

puts "--- \[TCL\] Step 3: Launching Simulation ---"

# Launch behavioral simulation
launch_simulation

# Run until the $finish command in the testbench is executed
run all