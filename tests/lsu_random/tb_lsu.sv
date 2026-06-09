`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    logic clk = 0;
    logic rst_n = 0;

    string input_files [1];
    string output_files [1];
    int input_total_beats [1];
    int output_total_beats [1];
    
    always #5 clk = ~clk;

    // Physical Interfaces
    axis_if #(`S_AXIS_DATA_WIDTH) s_if [1] (clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if [1] (clk, rst_n);

    LSU #(
        .PIXELS_PER_BEAT(`S_AXIS_DATA_WIDTH / `BIT_WIDTH),
        .IMAGE_DIM(`IMAGE_WIDTH),
        .BIT_WIDTH(`BIT_WIDTH),
        .WRITE_DELAY(`WRITE_DELAY),
        .RW_SHIFT(`RW_SHIFT)
    ) dut (
        .aclk(clk), 
        .aresetn(rst_n),
        .s_axis_tdata(s_if[0].tdata), 
        .s_axis_tvalid(s_if[0].tvalid), 
        .s_axis_tready(s_if[0].tready), 
        .s_axis_tlast(s_if[0].tlast),
        .m_axis_tdata(m_if[0].tdata), 
        .m_axis_tvalid(m_if[0].tvalid), 
        .m_axis_tready(m_if[0].tready), 
        .m_axis_tlast(m_if[0].tlast)
    );

    axis_sim_env #(
        .NUM_S_AXIS(1),
        .NUM_M_AXIS(1),
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) sim;

    initial begin
        input_files[0] = "inputs.hex";
        output_files[0] = "outputs.hex";
        input_total_beats[0] = `S_AXIS_TOTAL_BEATS;
        output_total_beats[0] = `M_AXIS_TOTAL_BEATS;

        void'($value$plusargs("IN_FILE_NAME=%s", input_files[0]));
        void'($value$plusargs("OUT_FILE_NAME=%s", output_files[0]));

        sim = new(s_if, m_if);
        
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        sim.run(input_files, input_total_beats, output_files, output_total_beats);
        $finish;
    end
endmodule