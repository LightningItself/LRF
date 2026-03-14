`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:18:48 AM
// Design Name: 
// Module Name: hstatecontroller
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


module hstatecontroller #(parameter HIM_LEN=16'd520, HIM_WID=16'd520, LOG2_NO_OF_IMAGES = 4 )  (   // The state signal genrator which controls the WHOLE pipeline
       input hclk,
       input hres,
       output reg [18:0] hfsm_avg, 
       output reg [LOG2_NO_OF_IMAGES-1:0] hstate);  // No. of bits in hstate = log2(No of images being combined together).
       
           always@( posedge hres or posedge hclk)
           begin

               if(hres) 
               begin
               hstate<={LOG2_NO_OF_IMAGES{1'b0}};
               hfsm_avg<= 0;
               end
               else
               begin
               
                   if(hfsm_avg+1 == (HIM_LEN*HIM_WID))
                   begin
                       hstate<=(hstate+1);  // Increment when one image processing is complete
                       hfsm_avg<= 0;
                   end
                   
                   else
                   begin
                       hstate<=hstate; //keep refreshing
                       hfsm_avg<= hfsm_avg+1;
                   end    
               end
       
           end   
endmodule 