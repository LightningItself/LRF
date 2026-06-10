`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    logic clk = 0;
    logic rst_n = 0;

    string input_files [3];
    string output_files [1];
    int input_total_beats [3];
    int output_total_beats [1];
    
    always #5 clk = ~clk;

    axis_if #(`S_AXIS_DATA_WIDTH) s_if [3] (clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [1] (clk, rst_n);

    FUSION #(
        .PIXELS_PER_BEAT(`S_AXIS_DATA_WIDTH / `BIT_WIDTH),
        .IMAGE_DIM(`IMAGE_WIDTH),
        .PIXEL_SIZE(`BIT_WIDTH)
    ) dut (
        .aclk(clk), 
        .aresetn(rst_n),
        
        .old_frame(s_if[0].tdata), 
        .old_frame_tvalid(s_if[0].tvalid), 
        .old_frame_tready(s_if[0].tready), 
        .old_frame_tlast(s_if[0].tlast),
        
        .new_frame(s_if[1].tdata), 
        .new_frame_tvalid(s_if[1].tvalid), 
        .new_frame_tready(s_if[1].tready), 
        .new_frame_tlast(s_if[1].tlast),
        
        .del_gauss(s_if[2].tdata), 
        .del_gauss_tvalid(s_if[2].tvalid), 
        .del_gauss_tready(s_if[2].tready), 
        .del_gauss_tlast(s_if[2].tlast),
        
        .fused_frame(m_if[0].tdata), 
        .fused_frame_tvalid(m_if[0].tvalid), 
        .fused_frame_tready(m_if[0].tready), 
        .fused_frame_tlast(m_if[0].tlast)
    );

    axis_sim_env #(
        .NUM_S_AXIS(3),
        .NUM_M_AXIS(1),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;

    initial begin
        input_files[0] = "inputs_old.hex";
        input_files[1] = "inputs_new.hex";
        input_files[2] = "inputs_gauss.hex";
        output_files[0] = "outputs_fused.hex";

        input_total_beats[0] = `S_AXIS_TOTAL_BEATS;
        input_total_beats[1] = `S_AXIS_TOTAL_BEATS;
        input_total_beats[2] = `S_AXIS_TOTAL_BEATS;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS;

        void'($value$plusargs("IN_FILE_NAME_OLD=%s",   input_files[0]));
        void'($value$plusargs("IN_FILE_NAME_NEW=%s",   input_files[1]));
        void'($value$plusargs("IN_FILE_NAME_GAUSS=%s", input_files[2]));
        void'($value$plusargs("OUT_FILE_NAME_FUSED=%s", output_files[0]));

        sim = new(s_if, m_if);
        
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        sim.run(input_files, input_total_beats, output_files, output_total_beats);
        
        $finish;
    end
endmodule