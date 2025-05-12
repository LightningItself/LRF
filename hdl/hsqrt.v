`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:26:21 AM
// Design Name: 
// Module Name: hsqrt
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hsqrt(input clk,                                          // CALCULATES SQUARE ROOT BASED ON CORDIC IP
                    input [15:0] hin,
                    output [7:0] hout
           );
           
           wire [15:0] hinter;
           wire houtvalid,houtvalid_delby3;
           
           cordic_0 hsqrtop (
             .aclk(clk),                                        // input wire aclk
             .s_axis_cartesian_tvalid(1'b1),  // input wire s_axis_cartesian_tvalid
             .s_axis_cartesian_tdata(hin),    // input wire [15 : 0] s_axis_cartesian_tdata
             .m_axis_dout_tvalid(houtvalid),            // output wire m_axis_dout_tvalid
             .m_axis_dout_tdata(hinter)              // output wire [15 : 0] m_axis_dout_tdata
           );
           
           hmultipledelay #(8'd1,8'd3) hmd_tvalide_bymore3 (clk,1'b0,houtvalid,houtvalid_delby3);  
       
           assign hout=(houtvalid_delby3)?hinter[7:0]:8'd0;
           
       endmodule