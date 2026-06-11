set TEST_NAME "fusion_top_random"
set SRC_DIR "../src"
set WORKSPACE_DIR [file normalize "./${TEST_NAME}"]
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"
set IP_DIR "${SRC_DIR}/ips/cordic/cordic_0"

if {[file exists $WORKSPACE_DIR]} { file delete -force $WORKSPACE_DIR }
file mkdir $WORKSPACE_DIR

set INPUT_HEX_OLD   "${WORKSPACE_DIR}/inputs_old.hex"
set INPUT_HEX_AVG   "${WORKSPACE_DIR}/inputs_avg.hex"
set INPUT_HEX_NEW   "${WORKSPACE_DIR}/inputs_new.hex"
set OUTPUT_HEX_TOP  "${WORKSPACE_DIR}/outputs_top.hex"

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
create_project -force sim_project ${WORKSPACE_DIR}/sim_project -part xc7z010clg225-1

set IP_FILE "${IP_DIR}/cordic_0.xci"

if {[file exists $IP_FILE]} {
    import_ip -files $IP_FILE -name cordic_0

    set CORDIC_IP [get_ips cordic_0]

    report_ip_status
    if {[catch {upgrade_ip $CORDIC_IP} upgrade_result]} {
        puts "WARNING: upgrade_ip reported: $upgrade_result"
    } else {
        puts $upgrade_result
    }

    reset_target all $CORDIC_IP
    generate_target all $CORDIC_IP
    export_ip_user_files -of_objects $CORDIC_IP -no_script -sync -force -quiet
} else {
    puts "ERROR: CORDIC IP not found at $IP_FILE"
    return -code error
}

add_files -fileset sources_1 ${SRC_DIR}/multiplier.v
add_files -fileset sources_1 ${SRC_DIR}/axis_adder.v
add_files -fileset sources_1 ${SRC_DIR}/axis_sub.v
add_files -fileset sources_1 ${SRC_DIR}/axis_buff.v
add_files -fileset sources_1 ${SRC_DIR}/axis_comparator.v
add_files -fileset sources_1 ${SRC_DIR}/sig_xy.v
add_files -fileset sources_1 ${SRC_DIR}/hssim.v
add_files -fileset sources_1 ${SRC_DIR}/hssim_top.v
add_files -fileset sources_1 ${SRC_DIR}/conv_gauss.v
add_files -fileset sources_1 ${SRC_DIR}/conv_sobel.v
add_files -fileset sources_1 ${SRC_DIR}/fusion.v
add_files -fileset sources_1 ${SRC_DIR}/fusion_top.v

add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]

add_files -fileset sim_1 ${TEST_DIR}/tb_fusion_top.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_fusion_top.sv]

# Include Path Setup: Looks for tb_config.svh generated in workspace
set_property include_dirs [list $WORKSPACE_DIR $TEST_DIR] [get_filesets sim_1]

add_files -fileset sim_1 [list $INPUT_HEX_OLD $INPUT_HEX_AVG $INPUT_HEX_NEW $OUTPUT_HEX_TOP]

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set ABS_INPUT_HEX_OLD  [file normalize $INPUT_HEX_OLD]
set ABS_INPUT_HEX_AVG  [file normalize $INPUT_HEX_AVG]
set ABS_INPUT_HEX_NEW  [file normalize $INPUT_HEX_NEW]
set ABS_OUTPUT_HEX_TOP [file normalize $OUTPUT_HEX_TOP]

set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg IN_FILE_NAME_OLD=$ABS_INPUT_HEX_OLD \
            -testplusarg IN_FILE_NAME_AVG=$ABS_INPUT_HEX_AVG \
            -testplusarg IN_FILE_NAME_NEW=$ABS_INPUT_HEX_NEW \
            -testplusarg OUT_FILE_NAME_TOP=$ABS_OUTPUT_HEX_TOP" \
    -objects [get_filesets sim_1]

puts "Running simulation..."
launch_simulation
run all