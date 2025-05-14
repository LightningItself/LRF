`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:27:01 AM
// Design Name: 
// Module Name: hconvg8
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


module hconvg8 #(parameter HIM_LEN=16'd520, hker = 8'd3 ) (
    input clk,
    input hres,
    input [7:0] hin,
    input hclrbuffer,
    input [hker-2:0] hrowend,
    output [7:0] hout,
    input step
    );
    integer i,p;

    // parameter hbuffend=(HIM_LEN+1)*(hker-1);

    reg [14:0] hbuff [0:(HIM_LEN+1)*(hker-1)-1];
    reg [14:0] temp_out;

    wire [8:0] temp_times2;
    wire [11:0] temp_times16;
    wire [9:0] temp_times3;
    wire [11:0] temp_times14;
    wire [13:0] temp_times60;

    wire hclrbuffer_delayedbyone;

    //honedelay #(1'b1) hod_hclrbffr (clk,hres,hclrbuffer,hclrbuffer_delayedbyone);

    always@(posedge clk) begin
        if(hres|hclrbuffer) begin
            for(i=0;i<(HIM_LEN+1)*(hker-1);i=i+1) begin
                hbuff[i]<='d0;
            end
            temp_out<='d0;
            
        end
       
        else begin
            for(p=0;p<hker-1;p=p+1) begin   // KEEP ON PASSING VALUES
                for(i=3;i<HIM_LEN;i=i+1) begin
                    hbuff[p*HIM_LEN+i] <= hbuff[p*HIM_LEN+i-1];
                end
            end
 
            // OPERATION BLOCK-------------------------------------------------------------
            hbuff[2]<=(hbuff[1]+temp_times3);
            hbuff[HIM_LEN+2]<=(hbuff[HIM_LEN+1]+temp_times14);
            temp_out<=(hbuff[(HIM_LEN+1)*(hker-1)-1]+temp_times3);
                             
            hbuff[0]<=(hrowend[0]&hrowend[1])?temp_times3:15'd0;
            hbuff[1]<=(hrowend[0])?(hbuff[0]+temp_times14):hbuff[0];
                             
            hbuff[HIM_LEN]<=(hrowend[0]&hrowend[1])?(hbuff[HIM_LEN-1]+temp_times14):hbuff[HIM_LEN-1];
            hbuff[HIM_LEN+1]<=(hrowend[0])?(hbuff[HIM_LEN]+temp_times60):hbuff[HIM_LEN];
                             
            hbuff[(HIM_LEN+1)*(hker-1)-2]<=(hrowend[0]&hrowend[1])?(hbuff[(HIM_LEN+1)*(hker-1)-3]+temp_times3):hbuff[(HIM_LEN+1)*(hker-1)-3];
            hbuff[(HIM_LEN+1)*(hker-1)-1]<=(hrowend[0])?(hbuff[(HIM_LEN+1)*(hker-1)-2]+temp_times14):hbuff[(HIM_LEN+1)*(hker-1)-2];
       
        end
    end
             

    // ASYNCHRONOUS PART OF OPERATION BLOCK---------------------------------------------------
    assign temp_times2=(hin<<1); // times2
    //assign temp_times4=(hin<<2); // times4
    assign temp_times16=(hin<<4); // times16
        
    assign temp_times3=(temp_times2+hin);    // times 3
    assign temp_times14=(temp_times16-temp_times2);  // times 14
    assign temp_times60={(temp_times16-hin),2'b00}; // times 60                     
    assign hout=temp_out[14:7];
                    
endmodule