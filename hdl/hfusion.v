`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:17:57 AM
// Design Name: 
// Module Name: hfusion
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


module hfusion #(parameter FUSEDIMAGE_DATA_WIDTH=8'd8,HIM_LEN=16'd520, HIM_WID=16'd520,HKER_SIZE=8'd3, LOG2_NO_OF_IMAGES = 4)(  // CREATES ALL THE NEW FUSED IMAGES BASED ON INPUT and OLD FUSED IMAGES
     
           input clk,
           input rst,
           input [FUSEDIMAGE_DATA_WIDTH-1:0] hfuse,                // previous fused image
           input [7:0] hnew,        // new incoming image
           input [7:0] href,        // reference image
           output reg [FUSEDIMAGE_DATA_WIDTH-1:0] hout_newfused_bus,
           //----------------
           output reg done_processing
           //----------------
           );    // new fused image combining previous fused and new incoming image
           
           
        
           reg [7:0] hout_newfused;
           
           
           
           wire signed [34:0] hhssim_out_fuse_numr;
           wire signed [30:0] hhssim_out_fuse_deno;
           wire signed [34:0] hhssim_out_new_numr;
           wire signed [30:0] hhssim_out_new_deno;
             
           
           wire [FUSEDIMAGE_DATA_WIDTH-1:0] hfuse_delayed_more18 ;
           wire [FUSEDIMAGE_DATA_WIDTH-1:0] hnew_delayed_more18;
           wire hstop_sig_more18 ;
           
           reg  [FUSEDIMAGE_DATA_WIDTH-1:0] hdel;
           wire [FUSEDIMAGE_DATA_WIDTH-1:0] hdel_out_fuse;
           reg  [FUSEDIMAGE_DATA_WIDTH-1:0] hdel_out_new;
           
           
           reg [7:0] hcombo1;
           reg [15:0] hinterprod_fuse1;
           reg [15:0] hinterprod_new1;
           reg [16:0] hintersum1;
      
           
           wire signed [64:0] fuse_numr_X_new_deno;
           wire signed [64:0] fuse_deno_X_new_numr;
           
           wire hclearbuffer_sig_delayedby_more1;
           wire hclearbuffer_sig_delayedby_more10,hclearbuffer_sig_delayedby_more11;
           
           wire [HKER_SIZE-2:0] hrowend;
           wire [HKER_SIZE-2:0] hrowend_delayedby_more1;
           wire [HKER_SIZE-2:0] hrowend_delayedby_more10,hrowend_delayedby_more11;
           
           wire [7:0] href_edgemap;
           wire [7:0] hmu_ref;
           wire [15:0] hmu_refref;
           wire signed [16:0] hsig_ref_sqrd;
           reg hgrtorsml[0:3];
           
           wire [18:0] img_addr;
           wire hstop_sig,hclearbuffer_sig;
          
         
         // Clear Buffer Signal
            assign hclearbuffer_sig = (img_addr == (HIM_LEN*HIM_WID-1)) ? 1'b1 : 1'b0; 

            hstatecontroller #(HIM_LEN,HIM_WID,LOG2_NO_OF_IMAGES)state_controller ( clk,rst,img_addr,hstate);
          //  hstop #(LOG2_NO_OF_IMAGES) hstop_1 (clk,rst,hstate,hstop_sig);
            
            
         // HSSIM CALCULATION------------------------------------------------------------

              (* use_dsp = "yes" *) hhssim #(HIM_LEN,HKER_SIZE) hssim_new(clk, rst, hnew, hclearbuffer_sig, hhssim_out_new_numr, hhssim_out_new_deno, hclearbuffer_sig_delayedby_more1, hclearbuffer_sig_delayedby_more10, hrowend, hrowend_delayedby_more1, hrowend_delayedby_more10, href_edgemap, hmu_ref, hmu_refref, hsig_ref_sqrd);
              (* use_dsp = "yes" *) hcommon_hssim #(HIM_LEN,HKER_SIZE) hcommon_hssim_ref(clk, rst, href, hclearbuffer_sig, hclearbuffer_sig_delayedby_more1, hclearbuffer_sig_delayedby_more10, hrowend, hrowend_delayedby_more1, hrowend_delayedby_more10, href_edgemap, hmu_ref, hmu_refref, hsig_ref_sqrd);
               
                  
              (* use_dsp = "yes" *)hhssim #(HIM_LEN,HKER_SIZE) hssim_fuse_inst(clk, rst, hfuse, hclearbuffer_sig, hhssim_out_fuse_numr, hhssim_out_fuse_deno, hclearbuffer_sig_delayedby_more1, hclearbuffer_sig_delayedby_more10, hrowend, hrowend_delayedby_more1, hrowend_delayedby_more10,href_edgemap, hmu_ref, hmu_refref, hsig_ref_sqrd);
                  
        //-------------------------------------------------------------------------------
           


        // DELAY BLOCKS------------------------------------------------------------------
           
             hmultipledelay #(HKER_SIZE-1,8'd18,1'b1) hmd_rowend_bymore11 (clk,rst,hrowend,hrowend_delayedby_more11); // ***THIS CAN BE OPTIMISED

             hmultipledelay #(1'b1,8'd18) hmd_clrbuffer_bymore10 (clk,rst,hclearbuffer_sig,hclearbuffer_sig_delayedby_more11);
             
                  
                       
                           hmultipledelay #(FUSEDIMAGE_DATA_WIDTH,8'd19) hod_fuse1 (clk,rst,hfuse,hfuse_delayed_more18);    // DELAYED FOR GIVING TIME TO HSSIM CALCULATION
       
                         //  hmultipledelay #(1'b1,8'd18) hod_stop (clk,rst,hstop_sig,hstop_sig_more18);            
       
                   

                           hmultipledelay #(FUSEDIMAGE_DATA_WIDTH,8'd19) hod_new1 (clk,rst,hnew,hnew_delayed_more18);
             
      
            // OPERATION BLOCKS------------------------------------------------------------------


                           (* use_dsp = "yes" *) hconvg8 #(HIM_LEN,HKER_SIZE) hconvg8_del(clk, rst, hdel, hclearbuffer_sig_delayedby_more11, hrowend_delayedby_more11, hdel_out_fuse); // BLURRING the hdel signal ,for spreading to nearby pixels
                           (* use_dsp = "yes" *) h34X30_multiplier h34X30_multiplier_inst_1(clk,rst,hhssim_out_new_numr,hhssim_out_fuse_deno,fuse_deno_X_new_numr) ;
                           (* use_dsp = "yes" *) h34X30_multiplier h34X30_multiplier_inst_2(clk,rst,hhssim_out_fuse_numr,hhssim_out_new_deno,fuse_numr_X_new_deno) ;
                      

              always@(*)
              begin
             
                  
                 
                       hdel_out_new=~(hdel_out_fuse);                                  // hdel value for new image will be complement of fused image signal
                       hinterprod_new1=(hdel_out_new*hnew_delayed_more18);             // Generating the reqd partial products
                       hinterprod_fuse1=(hdel_out_fuse*hfuse_delayed_more18);
                       hintersum1=(hinterprod_new1+hinterprod_fuse1);               // Generating the reqd sum
                       hcombo1=(hintersum1=='d0)?hfuse_delayed_more18:(hintersum1>>8);
                 
                 
                   
              end
             
             
              always@(posedge clk or posedge rst)
              begin
             
                if(rst)
                begin
               
                 
                     hdel<='d0;
                     hgrtorsml[0]<='d0;
                     hgrtorsml[1]<='d0;
                     hgrtorsml[2]<='d0;
                     hgrtorsml[3]<='d0;
                     hout_newfused<='d0;
                     done_processing <= 1'b0;
                 end
                else
                begin
               
                   
                   
                     (* use_dsp = "yes" *)hdel<=(fuse_numr_X_new_deno>fuse_deno_X_new_numr)?((hgrtorsml[3])?{FUSEDIMAGE_DATA_WIDTH{1'b0}}:{FUSEDIMAGE_DATA_WIDTH{1'b1}}):((hgrtorsml[3])?{FUSEDIMAGE_DATA_WIDTH{1'b1}}:{FUSEDIMAGE_DATA_WIDTH{1'b0}});
                     hgrtorsml[0]<=hhssim_out_fuse_deno[30]^hhssim_out_new_deno[30];
                     hgrtorsml[1]<=hgrtorsml[0];
                     hgrtorsml[2]<=hgrtorsml[1];
                     hgrtorsml[3]<=hgrtorsml[2];
                    
                    // hout_newfused<=(hstop_sig_more18==1'b0)?(hcombo1):{FUSEDIMAGE_DATA_WIDTH{1'b0}};
                    hout_newfused<=hcombo1;
                    
                    //------------ test changes
                    done_processing <= 1'b1;
                    // -------------
                  end
               
              end
          
            //-----------------------------------------------------------------------------------
           
           
           
            // FLATENING THE OUTPUT,  -------------------------------------------------------------
           
            always@(*)
         // INPUTs are delayed by ONE CLK cycle, because AVERAGE calculation takes ONE CLK cycle
            hout_newfused_bus=hout_newfused;    
           
            //-----------------------------------------------------------------------------------
       
           endmodule