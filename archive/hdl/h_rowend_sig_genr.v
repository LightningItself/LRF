`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:33:47 AM
// Design Name: 
// Module Name: h_rowend_sig_genr
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

module h_rowend_sig_genr #(parameter HIM_LEN=16'd520, HKER_SIZE = 3 ) (
    input clk,
    input hres,
    input hclrbuffer,
    output reg [HKER_SIZE-2:0] hout
    );
   
    reg [10:0] hctr;
    integer i;
   
    always@( posedge clk)
    begin
        if(hres|hclrbuffer)   // reset block
        begin    
            hctr<=(11'd0);      
        end
       
        else
        begin
   
                if(hctr+1==HIM_LEN) // Generate the h_last_pixel signal
                begin
                    hctr<='d0;  
                end

                else
                begin
                    hctr<=hctr+1;
                end
       
        end
   
   end 
      
   always@(*)
   begin
     for( i=0; i<HKER_SIZE-1;i=i+1)
       begin
         hout[i]=(hctr==(HIM_LEN-1-i))?1'b0:1'b1;
       end                                                                                                                                                                                                                                                                                     
   end
    endmodule
