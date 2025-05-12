`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:25:27 AM
// Design Name: 
// Module Name: hconvy
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


module hconvy #(parameter HIM_LEN=16'd520, hker = 8'd3 ) (
    input clk,
    input hres,
    input [7:0] hin,
    input hclrbuffer,
    input  [hker-2:0] hrowend,
    output [7:0] hout
    );
    integer i,p;
   
    //parameter hbuffend=(HIM_LEN+1)*(hker-1);
   
        reg signed [10:0] hbuff [0:(HIM_LEN+1)*(hker-1)-1]; // 11bits =1 sign bit + 10 bits for output, since max output can be 4*256
        reg signed [10:0] temp_out;
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

             for(p=0;p<hker-1;p=p+1) // Keep on passing values
             begin
             for(i=3;i<HIM_LEN;i=i+1)
             begin
                hbuff[p*HIM_LEN+i]<=hbuff[p*HIM_LEN+i-1];        
             end
             end

             
    // OPERATION BLOCK-------------------------------------------

             
             hbuff[1]<=hbuff[0];
             hbuff[2]<=(hbuff[1]+hin);
             
             hbuff[HIM_LEN+1]<=hbuff[HIM_LEN];
             hbuff[HIM_LEN+2]<=(hbuff[HIM_LEN+1]+(hin<<1));
             
             hbuff[(HIM_LEN+1)*(hker-1)-1]<=hbuff[(HIM_LEN+1)*(hker-1)-2];
//             temp_out<=(hbuff[(HIM_LEN+1)*(hker-1)-1]+hin);  // These 7 are common operations
         
             if(hrowend[0]&hrowend[1])                              //****** MAKEs product additions differently when row changes
                begin
                hbuff[0]<=(-hin);
               
                hbuff[HIM_LEN]<=(hbuff[HIM_LEN-1]-(hin<<1));

                hbuff[(HIM_LEN+1)*(hker-1)-2]<=(hbuff[(HIM_LEN+1)*(hker-1)-3]-hin);
               
                end
               
             else
                begin
                hbuff[0]<=8'd0;
               
                hbuff[HIM_LEN]<=hbuff[HIM_LEN-1];
               
                hbuff[(HIM_LEN+1)*(hker-1)-2]<=hbuff[(HIM_LEN+1)*(hker-1)-3];
               
                end
             
             temp_out<=(hbuff[(HIM_LEN+1)*(hker-1)-1]+hin);  // These 7 are common operations  
               //------------------------------------------------------------------
       end
       end

             // ASSIGNING OUTPUT VALUE BY TAKING ABSOLUTE VALUE----------

             assign hout_beforebitselect=(temp_out[10] == 1'b1)?(-temp_out[10:0]):(temp_out[10:0]); // ***CHANGED HERE Takes absolute value from temp
             assign hout=hout_beforebitselect[9:2];                                     // ***CHANGED HERE Takes most significant 8 bits, EXCLUDING the sign bit
           
             //----------------------------------------------------------

       
       
       endmodule