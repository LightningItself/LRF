set TEST_NAME "top_video"
set SRC_DIR "../src"
set WORKSPACE_DIR [file normalize "./${TEST_NAME}"]
set TEST_DIR "../tests/${TEST_NAME}"
set UTILS_SV_DIR "../utils/sv"
set IP_DIR "${SRC_DIR}/ips/cordic/cordic_0"
set FIFO_IP_DIR "${SRC_DIR}/ips/fifo/axis_data_fifo_0"
set DATA_DIR "../data/"


if {[file exists $WORKSPACE_DIR]} { file delete -force $WORKSPACE_DIR }
file mkdir $WORKSPACE_DIR

set INPUT_VIDEO_DIR     [file normalize "${DATA_DIR}/hex_data"]
set OUTPUT_VIDEO_DIR    [file normalize "${WORKSPACE_DIR}/outputs"]
set INPUT_IMG_COUNT     300
file mkdir $OUTPUT_VIDEO_DIR


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
add_files -fileset sources_1 ${SRC_DIR}/axis_adder_2.v
add_files -fileset sources_1 ${SRC_DIR}/axis_sub.v
add_files -fileset sources_1 ${SRC_DIR}/axis_buff.v
add_files -fileset sources_1 ${SRC_DIR}/axis_comparator.v
add_files -fileset sources_1 ${SRC_DIR}/lsu.v
add_files -fileset sources_1 ${SRC_DIR}/lsu_valid.v
add_files -fileset sources_1 ${SRC_DIR}/sig_xy.v
add_files -fileset sources_1 ${SRC_DIR}/hssim.v
add_files -fileset sources_1 ${SRC_DIR}/hssim_top.v
add_files -fileset sources_1 ${SRC_DIR}/conv_gauss.v
add_files -fileset sources_1 ${SRC_DIR}/conv_sobel.v
add_files -fileset sources_1 ${SRC_DIR}/sobel_hssim_top.v
add_files -fileset sources_1 ${SRC_DIR}/fusion.v
add_files -fileset sources_1 ${SRC_DIR}/fusion_top.v
add_files -fileset sources_1 ${SRC_DIR}/axis_add_sub.v
add_files -fileset sources_1 ${SRC_DIR}/skid_buff.v
add_files -fileset sources_1 ${SRC_DIR}/top.v

add_files -fileset sim_1 ${UTILS_SV_DIR}/sim_axis.sv
set_property file_type SystemVerilog [get_files ${UTILS_SV_DIR}/sim_axis.sv]

add_files -fileset sim_1 ${TEST_DIR}/tb_top_video.sv
set_property file_type SystemVerilog [get_files ${TEST_DIR}/tb_top_video.sv]

# Include Path Setup: Looks for tb_config.svh generated in workspace
set_property include_dirs [list $WORKSPACE_DIR $TEST_DIR] [get_filesets sim_1]

set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg INPUT_FOLDER=$INPUT_VIDEO_DIR \
            -testplusarg OUTPUT_FOLDER=$OUTPUT_VIDEO_DIR \
            -testplusarg FILE_PREFIX=hex_img_ \
            -testplusarg TOTAL_FRAMES=$INPUT_IMG_COUNT" \
    -objects [get_filesets sim_1]

puts "Running Simulation..."
launch_simulation
run all
