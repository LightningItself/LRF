`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    logic clk = 0;
    logic aresetn = 0;

    string input_files [3];
    string output_files [1];
    int input_total_beats [3];
    int output_total_beats [1];
    
    always #5 clk = ~clk;

    axis_if #(`S_AXIS_DATA_WIDTH) s_if [3] (clk, aresetn);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [1] (clk, aresetn);

    fusionTop #(
        .PIXELS_PER_BEAT(`PIXELS_PER_BEAT),
        .PIXEL_SIZE(`BIT_WIDTH),
        .IMAGE_DIM(`IMAGE_WIDTH)
    ) dut (
        .aclk(clk), 
        .aresetn(aresetn),

        .s_axis_old_fused_tdata(s_if[0].tdata), 
        .s_axis_old_fused_tvalid(s_if[0].tvalid), 
        .s_axis_old_fused_tready(s_if[0].tready), 
        .s_axis_old_fused_tlast(s_if[0].tlast),

        .s_axis_avg_tdata(s_if[1].tdata), 
        .s_axis_avg_tvalid(s_if[1].tvalid), 
        .s_axis_avg_tready(s_if[1].tready), 
        .s_axis_avg_tlast(s_if[1].tlast),

        .s_axis_new_tdata(s_if[2].tdata), 
        .s_axis_new_tvalid(s_if[2].tvalid), 
        .s_axis_new_tready(s_if[2].tready), 
        .s_axis_new_tlast(s_if[2].tlast),

        .m_axis_tdata(m_if[0].tdata), 
        .m_axis_tvalid(m_if[0].tvalid), 
        .m_axis_tready(m_if[0].tready), 
        .m_axis_tlast(m_if[0].tlast)
    );

    axis_sim_env #(
        .NUM_S_AXIS(3),
        .NUM_M_AXIS(1),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;

    initial begin
        input_files[0] = "inputs_old.hex";
        input_files[1] = "inputs_avg.hex";
        input_files[2] = "inputs_new.hex";
        output_files[0] = "outputs_top.hex";

        input_total_beats[0] = `S_AXIS_TOTAL_BEATS;
        input_total_beats[1] = `S_AXIS_TOTAL_BEATS;
        input_total_beats[2] = `S_AXIS_TOTAL_BEATS;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS;

        void'($value$plusargs("IN_FILE_NAME_OLD=%s",  input_files[0]));
        void'($value$plusargs("IN_FILE_NAME_AVG=%s",  input_files[1]));
        void'($value$plusargs("IN_FILE_NAME_NEW=%s",  input_files[2]));
        void'($value$plusargs("OUT_FILE_NAME_TOP=%s", output_files[0]));

        sim = new(s_if, m_if);

        aresetn = 0;
        repeat(20) @(posedge clk);
        aresetn = 1;

        sim.run(input_files, input_total_beats, output_files, output_total_beats);

        $display("Simulation complete. Scoreboard checks validated successfully.");
        $finish;
    end
endmodule