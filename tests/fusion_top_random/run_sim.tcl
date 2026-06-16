set TEST_NAME "fusion_top_random"
set SRC_DIR "../src"
set WORKSPACE_DIR [file normalize "./${TEST_NAME}"]
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"
set IP_DIR "${SRC_DIR}/ips/cordic/cordic_0"
set FIFO_IP_DIR "${SRC_DIR}/ips/fifo/axis_data_fifo_0"

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

set FIFO_IP_FILE "${FIFO_IP_DIR}/axis_data_fifo_0.xci"

if {[file exists $FIFO_IP_FILE]} {
    import_ip -files $FIFO_IP_FILE -name axis_data_fifo_0

    set FIFO_IP [get_ips axis_data_fifo_0]

    report_ip_status
    if {[catch {upgrade_ip $FIFO_IP} upgrade_result]} {
        puts "WARNING: upgrade_ip reported: $upgrade_result"
    } else {
        puts $upgrade_result
    }

    reset_target all $FIFO_IP
    generate_target all $FIFO_IP
    export_ip_user_files -of_objects $FIFO_IP -no_script -sync -force -quiet
} else {
    puts "ERROR: FIFO IP not found at $FIFO_IP_FILE"
    return -code error
}

add_files -fileset sources_1 ${SRC_DIR}/multiplier.v
add_files -fileset sources_1 ${SRC_DIR}/axis_adder.v
add_files -fileset sources_1 ${SRC_DIR}/axis_sub.v
add_files -fileset sources_1 ${SRC_DIR}/axis_buff.v
add_files -fileset sources_1 ${SRC_DIR}/axis_buff_depth.v
add_files -fileset sources_1 ${SRC_DIR}/axis_comparator.v
add_files -fileset sources_1 ${SRC_DIR}/sig_xy.v
add_files -fileset sources_1 ${SRC_DIR}/hssim.v
add_files -fileset sources_1 ${SRC_DIR}/hssim_top.v
add_files -fileset sources_1 ${SRC_DIR}/conv_gauss.v
add_files -fileset sources_1 ${SRC_DIR}/conv_sobel.v
add_files -fileset sources_1 ${SRC_DIR}/sobel_hssim_top.v
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

# =====================================================================
# ADDED: Waveform Configuration Setup (.wcfg)
# =====================================================================
set ABS_WCFG_PATH [file normalize "../fusion_top.wcfg"]

if {[file exists $ABS_WCFG_PATH]} {
    puts "Found waveform configuration file: $ABS_WCFG_PATH"
    # Associate the existing .wcfg file with the simulation fileset
    add_files -fileset sim_1 [list $ABS_WCFG_PATH]
    # Configure XSim to automatically open this view layout on start
    set_property xsim.simulate.view $ABS_WCFG_PATH [get_filesets sim_1]
} else {
    puts "WARNING: Waveform layout not found at $ABS_WCFG_PATH."
    puts "XSim will launch with a default layout. Save it to that path to use next time!"
}
# =====================================================================

puts "Running simulation..."
launch_simulation
run all