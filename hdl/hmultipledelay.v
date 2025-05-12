`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:21:17 AM
// Design Name: 
// Module Name: hmultipledelay
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


module hmultipledelay #(parameter DATA_WIDTH = 8'd8 , NUM_DELAY=5, hinitial=1'b0) (    // To delay input by MORE THAN ONE CLK CYCLE
       input hclk,
       input hres,
       input [DATA_WIDTH-1:0] hin,
       output [DATA_WIDTH-1:0] hout);
       
       wire [DATA_WIDTH-1:0] hintermediate[0:NUM_DELAY]; //stores intermediate output
       
       genvar hvar;
       
       generate
       
            for( hvar=0;hvar<NUM_DELAY;hvar=hvar+1)
            begin : hmul_delay
           
                honedelay #(DATA_WIDTH,hinitial) hod1(hclk,hres,hintermediate[hvar],hintermediate[hvar+1]);  // Generating multiple clk cycle delay using cascaded effect of many single cycle delay
           
            end
           
       endgenerate
       
       
       assign hintermediate[0]=hin;           // First element of hintermedite will the INPUT
       assign hout=hintermediate[NUM_DELAY];  // Last element of hintermedite will be the reqd DELAYED version of input
       
       endmodule