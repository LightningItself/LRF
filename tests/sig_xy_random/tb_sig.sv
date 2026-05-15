`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    parameter PIXELS_PER_BEAT = 16;
    parameter PIXEL_SIZE       = 8;
    parameter IMAGE_DIM        = 512;

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    // Use macros defined in tb_config.svh
    axis_if #(`S_AXIS_DATA_WIDTH) s_if_x(clk, rst_n);
    axis_if #(`S_AXIS_DATA_WIDTH) s_if_y(clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if(clk, rst_n);

    SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) dut (
        .aclk(clk), .aresetn(rst_n),
        .s_axis_tdata_x(s_if_x.tdata), .s_axis_tvalid_x(s_if_x.tvalid), .s_axis_tready_x(s_if_x.tready), .s_axis_tlast_x(s_if_x.tlast),
        .s_axis_tdata_y(s_if_y.tdata), .s_axis_tvalid_y(s_if_y.tvalid), .s_axis_tready_y(s_if_y.tready), .s_axis_tlast_y(s_if_y.tlast),
        .m_axis_tdata(m_if.tdata), .m_axis_tvalid(m_if.tvalid), .m_axis_tready(m_if.tready), .m_axis_tlast(m_if.tlast)
    );

    axis_sim_dual #(
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH),
        .S_AXIS_TOTAL_BEATS(`S_AXIS_TOTAL_BEATS),
        .M_AXIS_TOTAL_BEATS(`M_AXIS_TOTAL_BEATS)
    ) sim;

    initial begin
        sim = new(s_if_x, s_if_y, m_if);
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        sim.run();
        $finish;
    end
endmodule