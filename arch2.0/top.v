`timescale 1ns/10ps

module LRF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter N_FUSE_COUNT = 4,
    parameter PIPELINE_DELAY = 3,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
) (
    input wire s_axis_aclk,
    input wire s_axis_aresetn,

    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output reg s_axis_tready,
    input wire s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast
);
localparam MAX_DELAY = 30;
localparam FUSION_DELAY = 21;
localparam TOTAL_DELAY = 23;
localparam SOBEL_DELAY = 10;

localparam FUSE_COUNT = 1<<N_FUSE_COUNT;
localparam N_IMAGE_DIM  = $clog2(IMAGE_DIM);
localparam BEATS_PER_IMAGE = IMAGE_DIM*IMAGE_DIM/PIXELS_PER_BEAT;
localparam N_BEATS_PER_IMAGE = $clog2(BEATS_PER_IMAGE);
localparam N_PIPELINE_DELAY = $clog2(PIPELINE_DELAY);

wire [DATA_WIDTH-1:0] s1_new_frame_emap;
reg step; //check if the  pipeline can move forward

reg [DATA_WIDTH-1:0] fused_frame_d [TOTAL_DELAY-1:0], curr_frame_d [TOTAL_DELAY-1:0];


//FUSION CONTROL STATES
reg [N_FUSE_COUNT-1:0] frame_counter;
reg [N_BEATS_PER_IMAGE-1:0] beat_counter; 

//FRAME_BUFFER STATES
localparam BUF_COUNTER_WIDTH = $clog2(IMAGE_DIM/PIXELS_PER_BEAT);
reg avg_read_en, avg_write_en;
reg fused_read_en, fused_write_en;
reg [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] avg_buff_in;
wire [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] avg_frame_buff_out;
reg [DATA_WIDTH-1:0] fused_frame_buff_in, fused_frame;
wire [DATA_WIDTH-1:0] fused_frame_buff_out;
 
//DATAPATH STATES
wire [DATA_WIDTH-1:0] curr_frame_emap, fused_frame_emap, avg_frame_emap;
wire [DATA_WIDTH-1:0] out_hssim, out_dmap, out_fused_frame;

//FUSION STATE LOGIC
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
        beat_counter <= 0;
    end
    else if(step) begin
        beat_counter <= beat_counter+1;
        if(s_axis_tlast) begin
            frame_counter <= frame_counter+1;
        end
    end
end


//RESET CHAIN
reg [MAX_DELAY-1:0] aresetn_d;
genvar r;
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn)
        aresetn_d[0] <= 0;
    else if(step) 
        aresetn_d[0] <= s_axis_aresetn;
end
generate
    for(r=1; r<MAX_DELAY; r=r+1) begin
        always @(posedge s_axis_aclk) begin
            if(~s_axis_aresetn)
                aresetn_d[r] <= 0;
            else if(step)
                aresetn_d[r] <= aresetn_d[r-1];
        end
    end
endgenerate


//---------------------AVG BUFFER------------------------------
reg avg_first, avg_add;
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        avg_first <= 1;
        avg_add <= 0;
    end
    else if (step) begin
        if(beat_counter == SOBEL_DELAY-1) begin
            avg_add <= ~avg_add;
            if(frame_counter!=0) avg_first <= 0;
        end
    end
end
genvar i;

wire [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] iframex16, iframe;
LSU #(PIXELS_PER_BEAT,IMAGE_DIM,8+N_FUSE_COUNT,SOBEL_DELAY) avg_frame_buff (s_axis_aclk,s_axis_aresetn,avg_read_en&step,avg_frame_buff_out,avg_write_en,avg_buff_in);
generate 
    for(i=0;i<PIXELS_PER_BEAT;i=i+1) begin
        assign iframex16[(8+N_FUSE_COUNT)*i+:(8+N_FUSE_COUNT)] = curr_frame_emap[8*i+:8]<<N_FUSE_COUNT; 
        assign iframe[(8+N_FUSE_COUNT)*i+:8] = curr_frame_emap[8*i+:8]; 
        assign iframe[((8+N_FUSE_COUNT)*i+8)+:N_FUSE_COUNT] = 0; 

        assign avg_frame_emap[(8*i)+:8] = (avg_first) ? curr_frame_emap[(8*i)+:8] : avg_frame_buff_out[((8+N_FUSE_COUNT)*i+N_FUSE_COUNT)+:8];
    end    
endgenerate
always @(*) begin
    avg_write_en = step & s_axis_aresetn;
    avg_read_en = step & s_axis_aresetn;
    if(avg_first) begin
        avg_buff_in = iframex16;
    end
    else if(~avg_add) begin
        avg_buff_in = avg_frame_buff_out - iframe;
    end
    else begin //new_frame
        avg_buff_in = avg_frame_buff_out + iframe;
    end
end
//------------------------------------------------------------
localparam FUSED_DELAY = 23;
//FUSED FRAME BUFFER

reg store_inp;
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        store_inp <= 0;
    end 
    else if (step) begin
        if(frame_counter < 2 & beat_counter == FUSED_DELAY-1) begin
            store_inp <= ~store_inp;
        end
    end
end

LSU #(PIXELS_PER_BEAT,IMAGE_DIM,8,0,24) fused_frame_buff (s_axis_aclk,s_axis_aresetn,fused_read_en&step,fused_frame_buff_out,fused_write_en&step,fused_frame_buff_in);
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        fused_write_en <= 0;
        fused_read_en <= 0;
    end
    else if(step) begin
        if(beat_counter == FUSED_DELAY-1) begin
            fused_write_en <= ~fused_write_en;
            fused_read_en <= 1;
        end
    end
end
always @(*) begin
    fused_frame = (frame_counter==0) ? s_axis_tdata : fused_frame_buff_out;
    fused_frame_buff_in = (store_inp) ? curr_frame_d[TOTAL_DELAY-1] : out_fused_frame;
end

//------------------------------------HSSIM-FUSION DATAPATH--------------------------------------------

//GET EMAP of CURR_FRAME and FUSED_FRAME
CONV_SOBEL #(PIXELS_PER_BEAT,IMAGE_DIM) sobel_curr_frame (s_axis_aclk,s_axis_aresetn,~step,s_axis_tdata,curr_frame_emap);
CONV_SOBEL #(PIXELS_PER_BEAT,IMAGE_DIM) sobel_fused_frame (s_axis_aclk,s_axis_aresetn,~step,fused_frame,fused_frame_emap);

//CALCULATE HSSIM MAP
localparam HSSIM_DELAY = 10;
HSSIM #(PIXELS_PER_BEAT,IMAGE_DIM) m_hssim (s_axis_aclk,aresetn_d[HSSIM_DELAY-1],~step,fused_frame_emap,avg_frame_emap,curr_frame_emap, out_hssim);

//CALCULATE DMAP
localparam DOUT_GAUSS_DELAY = 19;
CONV_GAUSS #(PIXELS_PER_BEAT,8,IMAGE_DIM) m_gauss (s_axis_aclk,aresetn_d[DOUT_GAUSS_DELAY-1],~step,out_hssim,out_dmap);

//CREATE NEW FUSED IMAGE
always @(posedge s_axis_aclk) begin
    if(step) begin
        fused_frame_d[0] <= fused_frame;
        curr_frame_d[0] <= s_axis_tdata;
    end
end
generate
for(i=0; i<TOTAL_DELAY-1; i=i+1) begin
    always @(posedge s_axis_aclk) begin
        if(step) begin
            fused_frame_d[i+1] <= fused_frame_d[i];
            curr_frame_d[i+1] <= curr_frame_d[i];
        end
    end
end
endgenerate
FUSION #(PIXELS_PER_BEAT,IMAGE_DIM) m_fusion (s_axis_aclk,~step,fused_frame_d[FUSION_DELAY-1],curr_frame_d[FUSION_DELAY-1],out_dmap,out_fused_frame);

//-------------------------------------------------------------------------------------------


always @(*) begin
    s_axis_tready = m_axis_tready;
    step = (s_axis_tvalid & s_axis_tready);
end



//AXI IO INTERFACE LOGIC
// reg [N_PIPELINE_DELAY-1:0] last_counter;
// reg [N_PIPELINE_DELAY-1:0] valid_counter;
// //m_axis_tlast logic
// always @(posedge s_axis_aclk) begin
//     if(~s_axis_aresetn) begin
//         last_counter <= 0;
//     end
//     else if(step) begin
//         if(last_counter!=0) begin
//             if(last_counter == PIPELINE_DELAY) 
//                 last_counter <= 0;
//             else 
//                 last_counter <= last_counter+1; 
//         end
//         else if(s_axis_tlast)
//             last_counter <= 1;
//     end
// end
// //m_axis_tvalid logic
// always @(posedge s_axis_aclk) begin
//     if(~s_axis_aresetn) begin
//         valid_counter <= 0;
//     end
//     else if(step) begin
//         if(valid_counter==0)
//             valid_counter <= 1;
//         else if(valid_counter < PIPELINE_DELAY)
//             valid_counter <= valid_counter+1; 
//     end
// end
// always @(*) begin
//     m_axis_tvalid = s_axis_tvalid & (valid_counter==PIPELINE_DELAY);
//     m_axis_tdata  = s1_new_frame_emap;
//     m_axis_tlast  = (last_counter==PIPELINE_DELAY); 
//     s_axis_tready = m_axis_tready;
//     step = (s_axis_tvalid & s_axis_tready);
// end
endmodule
