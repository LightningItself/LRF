`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    parameter PIXELS_PER_BEAT = 16;
    parameter PIXEL_SIZE       = 8;
    parameter IMAGE_DIM        = 512;

    // Define environment structure arrays locally matching your architecture setup
    localparam NUM_S_AXIS = 3;
    localparam NUM_M_AXIS = 1;

    logic clk = 0;
    logic rst_n = 0;

    // String tracking lists for file I/O operations
    string input_files [NUM_S_AXIS];
    string output_files [NUM_M_AXIS];
    int input_total_beats [NUM_S_AXIS];
    int output_total_beats [NUM_M_AXIS];

    // Clock Generator (100 MHz clock)
    always #5 clk = ~clk;

    // Interface Instantiations matching bus widths
    axis_if #(`S_AXIS_DATA_WIDTH) s_if [NUM_S_AXIS] (clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [NUM_M_AXIS] (clk, rst_n);

    // ── Design Under Test (DUT) Instantiation ────────────────────────────────
    SOBEL_HSSIM_TOP #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) dut (
        .aclk(clk),
        .aresetn(rst_n),
        
        // Stream 0: Old Map Raw Video Input
        .old_map(s_if[0].tdata),
        .old_map_valid(s_if[0].tvalid),
        .old_map_ready(s_if[0].tready),
        .old_map_last(s_if[0].tlast),
        
        // Stream 1: Average Map Raw Video Input
        .avg_map(s_if[1].tdata),
        .avg_map_valid(s_if[1].tvalid),
        .avg_map_ready(s_if[1].tready),
        .avg_map_last(s_if[1].tlast),
        
        // Stream 2: New Map Raw Video Input
        .new_map(s_if[2].tdata),
        .new_map_valid(s_if[2].tvalid),
        .new_map_ready(s_if[2].tready),
        .new_map_last(s_if[2].tlast),
        
        // Output Stream 0: Delta Configuration Mask (del)
        .del(m_if[0].tdata),
        .del_valid(m_if[0].tvalid),
        .del_ready(m_if[0].tready),
        .del_last(m_if[0].tlast)
    );

    // Simulation Utility Infrastructure Driver Object
    axis_sim_env #(
        .NUM_S_AXIS(NUM_S_AXIS),
        .NUM_M_AXIS(NUM_M_AXIS),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;

    // ── Test Sequencer Initialization ────────────────────────────────────────
    initial begin
        // 1. Setup fallback reference names for local operations
        input_files[0]  = "inputs_old.hex";
        input_files[1]  = "inputs_avg.hex";
        input_files[2]  = "inputs_new.hex";
        output_files[0] = "outputs_top.hex";

        // 2. Map the unified Python macros to all target stream dimensions
        input_total_beats[0]  = `S_AXIS_TOTAL_BEATS;
        input_total_beats[1]  = `S_AXIS_TOTAL_BEATS;
        input_total_beats[2]  = `S_AXIS_TOTAL_BEATS;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS;

        // 3. Catch runtime plusarg configurations passed down by your Tcl workflow
        void'($value$plusargs("IN_FILE_NAME_OLD=%s",  input_files[0]));
        void'($value$plusargs("IN_FILE_NAME_AVG=%s",  input_files[1]));
        void'($value$plusargs("IN_FILE_NAME_NEW=%s",  input_files[2]));
        void'($value$plusargs("OUT_FILE_NAME_TOP=%s", output_files[0]));

        // 4. Bind the interface array handlers to the utility engine object
        sim = new(s_if, m_if);

        // 5. Execute synchronous active-low power-on reset timeline
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;

        // 6. Launch file streaming loops and evaluate golden scoreboard
        sim.run(input_files, input_total_beats, output_files, output_total_beats);

        $finish;
    end
endmodule