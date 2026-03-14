`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:30:07 AM
// Design Name: 
// Module Name: hcommon_hssim
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


module hcommon_hssim #(parameter HIM_LEN=16'd520,HKER_SIZE=8'd3)(  // GENERATES COMMON HSSIM SIGNALS TO SAVE RESOURCES
     
 input clk,
 input rst,
 input [7:0] href_orig,
 input hclearbuffer_sig,
 
 output hclearbuffer_sig_delayedby_more1,
 output hclearbuffer_sig_delayedby_more10,
 
 output [HKER_SIZE-2:0] hrowend,
 output [HKER_SIZE-2:0] hrowend_delayedby_more1,
 output [HKER_SIZE-2:0] hrowend_delayedby_more10,
 
 output [7:0] href_edgemap,
 output [7:0] hmu_ref,
 output [15:0] hmu_refref,
 output signed [16:0] hsig_ref_sqrd );
           
           wire [7:0] hrefedgex,hrefedgey;
           wire [15:0] hrefedgex_squared,hrefedgey_squared;
           wire [15:0] href_edgemap_sqrd,href_edgemap_sqrd_g,href_edgemap_sqrd_g_delayedby9;
           
           
           // COMMON  SIGNALS FOR DIFFERENT HSSIM MODULES---------------------------------
           
           h_rowend_sig_genr #(HIM_LEN,HKER_SIZE)h5(clk,rst,hclearbuffer_sig,hrowend);
           
           hmultipledelay #(1'b1,8'd10,1'b1) hmd_clrbuffer_bymore10 (clk,rst,hclearbuffer_sig,hclearbuffer_sig_delayedby_more10);
           hmultipledelay #(1'b1,8'd1,1'b1) hmd_clrbuffer_bymore1 (clk,rst,hclearbuffer_sig,hclearbuffer_sig_delayedby_more1);  
           
           hmultipledelay #(HKER_SIZE-1,8'd10,1'b1) hmd_rowend_bymore9 (~clk,rst,hrowend,hrowend_delayedby_more10);
           hmultipledelay #(HKER_SIZE-1,8'd1,1'b1) hmd_rowend_bymore1 (~clk,rst,hrowend,hrowend_delayedby_more1);
           
           hmultipledelay #(8'd16,8'd9) hmd_href_edgemap_sqrd_g_bymore9 (clk,rst,href_edgemap_sqrd_g,  href_edgemap_sqrd_g_delayedby9  );
           
           hconvx #(HIM_LEN,HKER_SIZE) hconvx2(clk,rst,href_orig,hclearbuffer_sig,hrowend,hrefedgex);
           hconvy #(HIM_LEN,HKER_SIZE) hconvy2(clk,rst,href_orig,hclearbuffer_sig,hrowend,hrefedgey);
           
           assign hrefedgex_squared=hrefedgex*hrefedgex;                      //--------- Creating a COMBINED REFERENCE IMAGE EDGE MAP from HORIZONTAL AND VERTICAL EDGE MAPs
           assign hrefedgey_squared=hrefedgey*hrefedgey;
           assign href_edgemap_sqrd=(hrefedgex_squared+hrefedgey_squared);
           hsqrt hsqrt_ref(clk,href_edgemap_sqrd,href_edgemap);               //--------- Creating a COMBINED REFERENCE IMAGE EDGE MAP from HORIZONTAL AND VERTICAL EDGE MAPs
           
           (* use_dsp = "yes" *)hconvg8 #(HIM_LEN,HKER_SIZE) hconvg82(clk,rst,  href_edgemap,  hclearbuffer_sig_delayedby_more10,  hrowend_delayedby_more10,hmu_ref);  // Mean calculation on reference image edge map
           
           (* use_dsp = "yes" *)hconvg16 #(HIM_LEN,HKER_SIZE) hconvg162(clk,rst,  href_edgemap_sqrd,  hclearbuffer_sig_delayedby_more1,  hrowend_delayedby_more1,  href_edgemap_sqrd_g  ); // Mean calculation on squared reference image edge map
           
           assign hmu_refref= hmu_ref*hmu_ref;          
           
           assign hsig_ref_sqrd= href_edgemap_sqrd_g_delayedby9 - hmu_refref;
           
           //-------------------------------------------------------------------------------
         
endmodule