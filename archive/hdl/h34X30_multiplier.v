`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:32:29 AM
// Design Name: 
// Module Name: h34X30_multiplier
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


module h34X30_multiplier (  // CREATES ALL THE NEW FUSED IMAGES BASED ON INPUT and OLD FUSED IMAGES
     
           input clk,
           input rst,
           input signed [34:0] a,
           input signed [30:0] b,              
           output reg signed [64:0] hprod    // new fused image combining previous fused and new incoming image
           );
           
           wire [16:0] a_lower,a_upper;
           wire [14:0] b_lower,b_upper;
           reg [31:0] alow_X_bup,alow_X_blow,aup_X_blow,aup_X_bup;
           reg [47:0] sum1,sum2;
           reg signed [64:0] sum_absolute;
           wire assign_sign;
           reg assign_sign_delayedby_1,assign_sign_delayedby_2,assign_sign_delayedby_3,assign_sign_delayedby_4;
           wire [33:0] a_mag;
           wire [29:0] b_mag;
           wire signed [64:0] hprod_calc;
           

                    assign a_mag=(a[34])?-a:a;
                    assign b_mag=(b[30])?-b:b;
                    assign assign_sign=a[34]^b[30];
                   
                    assign a_lower={a_mag[16:0]};
                    assign a_upper={a_mag[33:17]};
                    assign b_lower={b_mag[14:0]};
                    assign b_upper={b_mag[29:15]};
                   
                    assign hprod_calc=(assign_sign_delayedby_3)?(-sum_absolute):sum_absolute;
                   
                   
                   
           
           
           always@(posedge clk)  // NO CLEAR BUFFER SIGNAL NEEDED SINCE NO EXTRA OUTPUTS CREATED LIKE IN CASE OF CONVOLUTION MODULES WHICH CREATES A LARGER OUTPUT
           begin
           
                if(rst)
                begin
                alow_X_bup<='d0;
                alow_X_blow<='d0;
                aup_X_blow<='d0;
                aup_X_bup<='d0;
                assign_sign_delayedby_1<='d0;
                   
                sum1<='d0;
                sum2<='d0;
                assign_sign_delayedby_2<='d0;
               
                sum_absolute<='d0;
                assign_sign_delayedby_3<='d0;
               
                hprod<='d0;
                end
               
                else
                begin
               
                    alow_X_bup<=a_lower*b_upper;
                    alow_X_blow<=a_lower*b_lower;
                    aup_X_blow<=a_upper*b_lower;
                    aup_X_bup<=a_upper*b_upper;
                    assign_sign_delayedby_1<=assign_sign;
                   
                    sum1<=alow_X_blow+{alow_X_bup,15'd0};
                    sum2<=aup_X_blow+{aup_X_bup,15'd0};
                    assign_sign_delayedby_2<=assign_sign_delayedby_1;
                   
                    sum_absolute<=sum1+{sum2,17'd0};
                    assign_sign_delayedby_3<=assign_sign_delayedby_2;
                   
                    hprod<=hprod_calc;
                end
                   
           end    
        
    endmodule