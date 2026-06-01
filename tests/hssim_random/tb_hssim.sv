`timescale 1ns/10ps
`include "tb_config.svh"
module tb_top;
    parameter PIXELS_PER_BEAT = 16;
    parameter PIXEL_SIZE       = 8;
    parameter IMAGE_DIM        = 512;
    logic clk = 0;
    logic rst_n = 0;
    string input_files [`NUM_S_AXIS];
    string output_files [`NUM_M_AXIS];
    int input_total_beats [`NUM_S_AXIS];
    int output_total_beats [`NUM_M_AXIS];
    always #5 clk = ~clk;
    axis_if #(`S_AXIS_DATA_WIDTH) s_if [`NUM_S_AXIS] (clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [`NUM_M_AXIS] (clk, rst_n);
    HSSIM #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) dut (
        .aclk(clk),
        .aresetn(rst_n),
        .map_x(s_if[0].tdata),
        .map_x_valid(s_if[0].tvalid),
        .map_x_ready(s_if[0].tready),
        .map_x_last(s_if[0].tlast),
        .map_y(s_if[1].tdata),
        .map_y_valid(s_if[1].tvalid),
        .map_y_ready(s_if[1].tready),
        .map_y_last(s_if[1].tlast),
        .sign_numr_denr(m_if[0].tdata),
        .out_valid(m_if[0].tvalid),
        .out_ready(m_if[0].tready),
        .out_last(m_if[0].tlast)
    );
    axis_sim_env #(
        .NUM_S_AXIS(`NUM_S_AXIS),
        .NUM_M_AXIS(`NUM_M_AXIS),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;
    initial begin
        input_files[0]  = "inputs_x.hex";
        input_files[1]  = "inputs_y.hex";
        output_files[0] = "outputs_packed.hex";
        input_total_beats[0]  = `S_AXIS_TOTAL_BEATS_0;
        input_total_beats[1]  = `S_AXIS_TOTAL_BEATS_1;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS_0;
        void'($value$plusargs("IN_FILE_NAME_X=%s",      input_files[0]));
        void'($value$plusargs("IN_FILE_NAME_Y=%s",      input_files[1]));
        void'($value$plusargs("OUT_FILE_NAME_PACKED=%s", output_files[0]));
        sim = new(s_if, m_if);
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        sim.run(input_files, input_total_beats, output_files, output_total_beats);
        $finish;
    end
endmodule