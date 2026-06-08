`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    parameter PIXELS_PER_BEAT = 16;
    parameter PIXEL_SIZE       = 8;
    parameter IMAGE_DIM        = 512;

    logic clk = 0;
    logic rst_n = 0;

    // HSSIM_TOP uses 3 slave interfaces and 1 master interface
    string input_files [`NUM_S_AXIS];
    string output_files [`NUM_M_AXIS];
    int input_total_beats [`NUM_S_AXIS];
    int output_total_beats [`NUM_M_AXIS];

    // Clock Generator (100 MHz clock)
    always #5 clk = ~clk;

    // Interface Instantiations
    axis_if #(`S_AXIS_DATA_WIDTH) s_if [`NUM_S_AXIS] (clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [`NUM_M_AXIS] (clk, rst_n);

    // Design Under Test (DUT)
    HSSIM_TOP #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) dut (
        .aclk(clk),
        .aresetn(rst_n),
        
        // Stream 0: Old Map
        .old_map(s_if[0].tdata),
        .old_map_valid(s_if[0].tvalid),
        .old_map_ready(s_if[0].tready),
        .old_map_last(s_if[0].tlast),
        
        // Stream 1: Average Map
        .avg_map(s_if[1].tdata),
        .avg_map_valid(s_if[1].tvalid),
        .avg_map_ready(s_if[1].tready),
        .avg_map_last(s_if[1].tlast),
        
        // Stream 2: New Map
        .new_map(s_if[2].tdata),
        .new_map_valid(s_if[2].tvalid),
        .new_map_ready(s_if[2].tready),
        .new_map_last(s_if[2].tlast),
        
        // Output Stream 0: Delta Mask (del)
        .del(m_if[0].tdata),
        .del_valid(m_if[0].tvalid),
        .del_ready(m_if[0].tready),
        .del_last(m_if[0].tlast)
    );

    // Simulation Driver Object
    axis_sim_env #(
        .NUM_S_AXIS(`NUM_S_AXIS),
        .NUM_M_AXIS(`NUM_M_AXIS),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;

    initial begin
        input_files[0]  = "inputs_old.hex";
        input_files[1]  = "inputs_avg.hex";
        input_files[2]  = "inputs_new.hex";
        output_files[0] = "outputs_packed.hex";

        input_total_beats[0]  = `S_AXIS_TOTAL_BEATS_0;
        input_total_beats[1]  = `S_AXIS_TOTAL_BEATS_1;
        input_total_beats[2]  = `S_AXIS_TOTAL_BEATS_2;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS_0;

        void'($value$plusargs("IN_FILE_NAME_OLD=%s",     input_files[0]));
        void'($value$plusargs("IN_FILE_NAME_AVG=%s",     input_files[1]));
        void'($value$plusargs("IN_FILE_NAME_NEW=%s",     input_files[2]));
        void'($value$plusargs("OUT_FILE_NAME_PACKED=%s", output_files[0]));

        sim = new(s_if, m_if);

        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;

        sim.run(input_files, input_total_beats, output_files, output_total_beats);

        $finish;
    end
endmodule