`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:23:43 AM
// Design Name: 
// Module Name: honedelay
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


module honedelay #(parameter DATA_WIDTH = 8'd8,hinitial=1'b0)  (     // To create **ONE CLK CYCLE delayed version of input  using cascaded effect of half edge delayby negedge and then posedge
input hclk,
input hres,
input [DATA_WIDTH-1:0] hin,
output reg [DATA_WIDTH-1:0] hout);
    always@(posedge hclk)
    begin
        if(hres)
        hout<={DATA_WIDTH{hinitial}};

        else
        hout<=hin;
    end

endmodule