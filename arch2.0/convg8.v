`timescale 1ns / 1ps

module convg8 #(parameter IM_LEN = 16'd520, ker = 8'd3 ) (
    input clk,
    input res,
    input [7:0] in,
    input clrbuffer,
    input [ker-2:0] rowend,
    output [7:0] out,
    input step
    );
    integer i,p;

    // parameter hbuffend=(IM_LEN+1)*(ker-1);

    reg [14:0] buff [0:(IM_LEN+1)*(ker-1)-1];
    reg [14:0] temp_out;

    wire [8:0] temp_times2;
    wire [11:0] temp_times16;
    wire [9:0] temp_times3;
    wire [11:0] temp_times14;
    wire [13:0] temp_times60;

    wire clrbuffer_delayedbyone;

    //honedelay #(1'b1) hod_hclrbffr (clk,res,clrbuffer,clrbuffer_delayedbyone);

    always@(posedge clk) begin
        if(res | clrbuffer) begin
            for(i = 0; i < (IM_LEN+1)*(ker-1); i = i+1) begin
                buff[i] <= 'd0;
            end
            temp_out <= 'd0;    
        end
       
        else begin
            for(p = 0; p < ker-1; p = p+1) begin   // KEEP ON PASSING VALUES
                for(i = 3; i < IM_LEN; i = i+1) begin
                    buff[p*IM_LEN+i] <= buff[p*IM_LEN+i-1];
                end
            end
 
            // OPERATION BLOCK-------------------------------------------------------------
            buff[2] <= (buff[1] + temp_times3);
            buff[IM_LEN+2] <= (buff[IM_LEN+1] + temp_times14);
            temp_out <= (buff[(IM_LEN+1)*(ker-1)-1]+temp_times3);
                             
            buff[0] <= (rowend[0] & rowend[1]) ? temp_times3 : 15'd0;
            buff[1] <= (rowend[0]) ? (buff[0] + temp_times14) : buff[0];
                             
            buff[IM_LEN] <= (rowend[0] & rowend[1]) ? (buff[IM_LEN-1] + temp_times14) : buff[IM_LEN-1];
            buff[IM_LEN+1] <= (rowend[0]) ? (buff[IM_LEN] + temp_times60) : buff[IM_LEN];
                             
            buff[(IM_LEN+1)*(ker-1)-2] <= (rowend[0] & rowend[1]) ? (buff[(IM_LEN+1)*(ker-1)-3] + temp_times3) : buff[(IM_LEN+1)*(ker-1)-3];
            buff[(IM_LEN+1)*(ker-1)-1] <= (rowend[0]) ? (buff[(IM_LEN+1)*(ker-1)-2] + temp_times14) : buff[(IM_LEN+1)*(ker-1)-2];
        end
    end         

    // ASYNCHRONOUS PART OF OPERATION BLOCK---------------------------------------------------
    assign temp_times2 = (in << 1); // times 2
    //assign temp_times4 = (in << 2); // times 4
    assign temp_times16 = (in << 4); // times 16
        
    assign temp_times3 = (temp_times2 + in);    // times 3
    assign temp_times14 = (temp_times16 - temp_times2);  // times 14
    assign temp_times60 = {(temp_times16 - in), 2'b00}; // times 60                     
    assign out = temp_out[14:7];
                    
endmodule