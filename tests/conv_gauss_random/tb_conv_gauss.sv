`include "tb_config.svh"

module tb_top;
    parameter PIXELS_PER_BEAT = 16;
    parameter PIXEL_SIZE      = 8;
    parameter IMAGE_WIDTH     = 512;
    
    logic clk = 0;
    logic rst_n = 0;
    
    always #5 clk = ~clk;

    // Interfaces
    axis_if #(`S_AXIS_DATA_WIDTH) s_if(clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if(clk, rst_n);

    // DUT
    CONV_GAUSS #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) dut (
        .aclk(clk), .aresetn(rst_n),
        .s_axis_tdata(s_if.tdata), .s_axis_tvalid(s_if.tvalid), .s_axis_tready(s_if.tready), .s_axis_tlast(s_if.tlast),
        .m_axis_tdata(m_if.tdata), .m_axis_tvalid(m_if.tvalid), .m_axis_tready(m_if.tready), .m_axis_tlast(m_if.tlast)
    );

    // AXI-Stream simulation pipeline
    axis_sim #(`S_AXIS_DATA_WIDTH, `M_AXIS_DATA_WIDTH, `S_AXIS_TOTAL_BEATS, `M_AXIS_TOTAL_BEATS) sim;

    initial begin
        sim = new(s_if, m_if);
        
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        sim.run();     
        $finish;
    end
endmodule