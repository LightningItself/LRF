`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:20:25 AM
// Design Name: 
// Module Name: hhssim
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


module hhssim #(parameter HIM_LEN=16'd520,HKER_SIZE=8'd3) (                      // CALCULATES HSSIM VALUE OF INPUT BASED ON EDGE MAP OF INPUT AND REF. IMAGE
                                     input clk,
                                     input rst,
                                     input [7:0] hin_orig,
                                     input hclearbuffer_sig,
                                     
                                     output signed [34:0] hout_numr,
                                     output signed [30:0] hout_deno,
                                     input hclearbuffer_sig_delayedby_more1,
                                     input hclearbuffer_sig_delayedby_more10,
                                     
                                     input [HKER_SIZE-2:0] hrowend,
                                     input [HKER_SIZE-2:0] hrowend_delayedby_more1,
                                     input [HKER_SIZE-2:0] hrowend_delayedby_more10,
                                     
                                     input [7:0] href_edgemap,
                                     input [7:0] hmu_ref,
                                     input [15:0] hmu_refref,
                                     input signed [16:0] hsig_ref_sqrd
                                    
                                     );

                                
                                     parameter signed c1=18'd8;
                                     parameter signed c2=18'd50;
                                     
                                 
                                     wire [7:0] hmu_in; // mean
                                     wire [15:0] hin_edgemap_sqrd,hinref_edgemap,hmu_inin,hmu_inref,hin_edgemap_sqrd_g,hinref_edgemap_g;
                                   
                                     wire signed [16:0] hsig_in_sqrd,hsig_inref; // variance and covariance
                                 
                                     wire signed [17:0] temp1,temp2; // Temp variables 16 bits, 1sign bit
                                     reg signed [17:0] hnumr_1,hnumr_2;   // Numerator requires 17 bits, 1sign bit
                                     reg signed [19:0] hdeno_1_temp,hdeno_2_temp;   // Denominator requires 18bits, 1sign bit
                                     wire signed [17:0] hdeno_1,hdeno_2;   // Denominator requires 18bits, 1sign bit
                                     wire signed [30:0] hdeno;       // Numr and Denor requires 34 bits, 1sign bit
                                     reg signed [34:0] hnumr;       // Numr and Denor requires 34 bits, 1sign bit
                                     reg signed [30:0] hdeno_temp;       // Numr and Denor requires 34 bits, 1sign bit
                                   
                                     wire [7:0] hinedgex,hinedgey;
                                     wire [7:0] hin_edgemap;
                                     wire [15:0] hinedgex_squared,hinedgey_squared;
                                    
                                     wire [15:0] hin_edgemap_sqrd_g_delayedby9;

                                   
                                     hmultipledelay #(8'd16, 8'd9,1'b0) hmd_hin_edgemap_sqrd_g_bymore9 (clk,rst,hin_edgemap_sqrd_g,  hin_edgemap_sqrd_g_delayedby9  );
     
                                     hconvx #(HIM_LEN,HKER_SIZE) hconvx1(clk,rst,hin_orig,hclearbuffer_sig,hrowend,hinedgex);     // Generating the HORIZONTAL AND VERTICAL EDGE MAPs
                                     hconvy #(HIM_LEN,HKER_SIZE) hconvy1(clk,rst,hin_orig,hclearbuffer_sig,hrowend,hinedgey);
                                     
                                     
                                     assign hinedgex_squared=hinedgex*hinedgex;                         //--------- Creating a COMBINED INPUT IMAGE EDGE MAP from HORIZONTAL AND VERTICAL EDGE MAPs
                                     assign hinedgey_squared=hinedgey*hinedgey;
                                     assign hin_edgemap_sqrd=(hinedgex_squared+hinedgey_squared);
                                     hsqrt hsqrt_in(clk,hin_edgemap_sqrd,hin_edgemap);                  //--------- Creating a COMBINED INPUT IMAGE EDGE MAP from HORIZONTAL AND VERTICAL EDGE MAPs
                                     
                                    
                                     assign hinref_edgemap=href_edgemap*hin_edgemap; // Multiplying INPUT and REFERENCE edge maps
                   
                   
                                     (* use_dsp = "yes" *)hconvg8 #(HIM_LEN,HKER_SIZE) hconvg81(clk,rst,  hin_edgemap,  hclearbuffer_sig_delayedby_more10, hrowend_delayedby_more10,hmu_in);    // Mean calculation on input image edge map  //****CHECK FOR DELAY
                                    
                                     (* use_dsp = "yes" *)hconvg16 #(HIM_LEN,HKER_SIZE) hconvg161(clk,rst,  hin_edgemap_sqrd,  hclearbuffer_sig_delayedby_more1,  hrowend_delayedby_more1,  hin_edgemap_sqrd_g  );   // Mean calculation on squared input image edge map//****CHECK FOR DELAY
                                    
                                     (* use_dsp = "yes" *)hconvg16 #(HIM_LEN,HKER_SIZE) hconvg163(clk,rst,  hinref_edgemap,  hclearbuffer_sig_delayedby_more10,  hrowend_delayedby_more10,  hinref_edgemap_g  );       // Mean calculation on product of reference and input image edge map
                                 
                                     
                                     
                                     assign hmu_inin= hmu_in*hmu_in;                       // Generating reqd mean(MU) values  //****CHECK FOR DELAY
                                     assign hmu_inref= hmu_in*hmu_ref;
                                 
                                     assign hsig_in_sqrd= hin_edgemap_sqrd_g_delayedby9 - hmu_inin;   // Generating reqd co-variance(SIGMA) values //****CHECK FOR DELAY
                                     assign hsig_inref= hinref_edgemap_g - hmu_inref;
                                 
                                 
                                 
                                 
                                     assign temp1=(hmu_inref <<<1);   // Multiplication by 2 as per SSIM calculation //****CHECK FOR DELAY
                                     assign temp2=(hsig_inref <<<1);  // Multiplication by 2 as per SSIM calculation
                                     assign hdeno_1=hdeno_1_temp>>>2;
                                     assign hdeno_2=hdeno_2_temp>>>2;  
                                     assign hdeno=(hdeno_temp>>>4);                                 
//                                     
                                     always@(posedge clk)
                                     begin
                                     hnumr_1<=(c1+temp1);                             // Numerator terms ,17 bits each
                                     hnumr_2<=(c2+temp2);
                                     hdeno_1_temp<=(c1+(hmu_inin)+(hmu_refref)); // Denominator terms, 18bits each
                                     hdeno_2_temp<=(c2+hsig_in_sqrd+hsig_ref_sqrd);
                                     
                                     hnumr<=(hnumr_1)*(hnumr_2);              //****CHECK FOR DELAY
                                     hdeno_temp<=(hdeno_1)*(hdeno_2);
                                     
                                          end
                                
                                    assign hout_numr=hnumr;
                                    assign hout_deno=hdeno;
                                  
                                     
                                 endmodule