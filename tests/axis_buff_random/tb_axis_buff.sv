`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;
    logic clk = 0;
    logic rst_n = 0;
    
    always #5 clk = ~clk;

    // Interfaces
    axis_if #(`S_AXIS_DATA_WIDTH) s_if(clk, rst_n);
    axis_if #(`M_AXIS_DATA_WIDTH) m_if(clk, rst_n);

    // DUT
    axis_buff #(
        .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
        .M_AXIS_DATA_WIDTH(`M_AXIS_DATA_WIDTH)
    ) dut (
        .aclk(clk), .aresetn(rst_n),
        .s_axis_tdata(s_if.tdata), .s_axis_tvalid(s_if.tvalid), .s_axis_tready(s_if.tready), .s_axis_tlast(s_if.tlast),
        .m_axis_tdata(m_if.tdata), .m_axis_tvalid(m_if.tvalid), .m_axis_tready(m_if.tready), .m_axis_tlast(m_if.tlast)
    );

    // Driver → s_if → DUT → m_if → Monitor

    // AXI-Stream simulation pipeline
    axis_sim #(`S_AXIS_DATA_WIDTH, `M_AXIS_DATA_WIDTH, `S_AXIS_TOTAL_BEATS, `M_AXIS_TOTAL_BEATS) sim; // Simulation class

    initial begin
        sim = new(s_if, m_if); // constructor of axis_sim class, passing interfaces to connect to hardware signals
        // object → uses interface → interface connects to hardware, classes/Objects don’t become hardware — they just control hardware via interfaces
        // When you pass an interface, you are giving the class access to real hardware signals, It is NOT creating hardware connection
        // Interface is a bridge: software uses it like an object, hardware uses it like wires
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        sim.run();     
        $finish;
    end
endmodule