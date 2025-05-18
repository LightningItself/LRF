`timescale 1ns/1ps

module CORDIC_tb;

reg aclk = 0;
reg s_axis_cartesian_tvalid = 0;
reg [15:0] s_axis_cartesian_tdata;

wire m_axis_dout_tvalid;
wire [15:0] m_axis_dout_tdata;

cordic_0 dut(aclk,s_axis_cartesian_tvalid,s_axis_cartesian_tdata,m_axis_dout_tvalid,m_axis_dout_tdata);

reg [15:0] data = 2;

//CLOCKING
always #1
    aclk <= ~aclk;

//INPUT CONTROLLER
initial begin
    #5
    s_axis_cartesian_tvalid = 1;
    s_axis_cartesian_tdata = 1024;
    #2
    s_axis_cartesian_tvalid = 0;
end

endmodule