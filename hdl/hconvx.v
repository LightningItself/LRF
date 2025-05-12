`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:24:35 AM
// Design Name: 
// Module Name: hconvx
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


module hconvx #(parameter HIM_LEN=16'd520, hker = 3 ) (
    input clk,
    input hres,
    input [7:0] hin,
    input hclrbuffer,
    input [hker-2:0] hrowend,
    output [7:0] hout
    );
    integer i;
   
  
   
    reg signed [10:0] hbuff [0:(HIM_LEN+1)*(hker-1)-1]; // 11bits =1 sign bit + 10 bits for output, since max output can be 4*256                        //**MARKS** THE POSITIVE EDGE CORRESPONDING TO LAST PIXEL , TO INDICATE LAST PIXEL OF THE ROW ARRIVED
    reg signed [10:0] temp_out;
    wire signed [10:0] temp_hin_mulby2;
    wire [10:0] hout_beforebitselect; // takes absolute value from temp
  
    
    always@(posedge clk)
    begin
   
        if(hres|hclrbuffer)   // reset block
        begin
           
            for(i=0;i<(HIM_LEN+1)*(hker-1);i=i+1)
            begin
                hbuff[i]<='d0;
            end
            temp_out<='d0;
           
        end
       
        else
        begin
             
                for(i=3;i<HIM_LEN*(hker-1);i=i+1)  // KEEP ON PASSING VALUE WITHOUT ANY OPERATION
                begin
                    hbuff[i]<=hbuff[i-1];        
                end

            // OPERATION BLOCK-------------------------------------------
   
                hbuff[0]<=(hrowend[0]&hrowend[1])?(-hin):'d0;
                hbuff[1]<=(hrowend[0])?(hbuff[0]-(temp_hin_mulby2)):hbuff[0];
                hbuff[2]<=(hbuff[1]-hin);

                hbuff[(HIM_LEN+1)*(hker-1)-2]<=((hrowend[0]&hrowend[1]))?(hbuff[(HIM_LEN+1)*(hker-1)-3]+hin):hbuff[(HIM_LEN+1)*(hker-1)-3];
                hbuff[(HIM_LEN+1)*(hker-1)-1]<=(hrowend[0])?(hbuff[(HIM_LEN+1)*(hker-1)-2]+temp_hin_mulby2):hbuff[(HIM_LEN+1)*(hker-1)-2];
                temp_out<=(hbuff[(HIM_LEN+1)*(hker-1)-1]+hin);
             
           
             //-------------------------------------------------------------

       end
           
    end
             // ASYNCHRONOUS PART OF OPERATION BLOCK-------------------------
             
             assign temp_hin_mulby2=hin<<1;  
             
             // ASSIGNING OUTPUT VALUE BY TAKING ABSOLUTE VALUE----------
   
             assign hout_beforebitselect=(temp_out[10] == 1'b1)?(-temp_out[10:0]):(temp_out[10:0]); // ***CHANGED HERE, Takes absolute value from temp
             assign hout=hout_beforebitselect[9:2];  // ***CHANGED HERE Takes most significant 8 bits, EXCLUDING the sign bit
            
endmodule