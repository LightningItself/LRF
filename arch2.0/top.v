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
localparam SOBEL_DELAY = 10;
localparam FUSION_DELAY = 11;

localparam FUSE_COUNT = 1<<N_FUSE_COUNT;
localparam N_IMAGE_DIM  = $clog2(IMAGE_DIM);
localparam BEATS_PER_IMAGE = IMAGE_DIM*IMAGE_DIM/PIXELS_PER_BEAT;
localparam N_BEATS_PER_IMAGE = $clog2(BEATS_PER_IMAGE);
localparam N_PIPELINE_DELAY = $clog2(PIPELINE_DELAY);

wire [DATA_WIDTH-1:0] s1_new_frame_emap;
reg step; //check if the  pipeline can move forward


//FUSION CONTROL STATES
reg load_avg;
reg [N_FUSE_COUNT-1:0] frame_counter;
wire new_frame = ~frame_counter[0];
wire old_frame = frame_counter[0];

//FRAME_BUFFER STATES
localparam BUF_COUNTER_WIDTH = $clog2(IMAGE_DIM/PIXELS_PER_BEAT);
reg avg_read_en, avg_write_en;
reg fused_read_en, fused_write_en;
reg [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] avg_buff_in;
wire [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] avg_frame_emap;

reg [DATA_WIDTH-1:0] fused_buff_in, fused_frame;
wire [DATA_WIDTH-1:0] fused_buff_out;

//DATAPATH STATES
wire [DATA_WIDTH-1:0] curr_frame_emap;
reg [DATA_WIDTH-1:0] fused_frame_emap;
wire [DATA_WIDTH-1:0] out_frame;

//FUSION STATE LOGIC
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        load_avg <= 1;
        frame_counter <= 0;
    end
    else if(step) begin
        if(s_axis_tlast) begin
            load_avg <= 0;
            if(frame_counter == 2*FUSE_COUNT-1) 
                frame_counter <= 0;
            else 
                frame_counter <= frame_counter+1;
        end
    end
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

genvar i;

//AVERAGE FRAME LOGIC
LSU #(PIXELS_PER_BEAT,IMAGE_DIM,8+N_FUSE_COUNT,SOBEL_DELAY) avg_frame_buff (s_axis_aclk,s_axis_aresetn,avg_read_en&step,avg_frame_emap,avg_write_en,avg_buff_in);
wire [DATA_WIDTH+N_FUSE_COUNT*PIXELS_PER_BEAT-1:0] iframex16, iframe;
generate 
    for(i=0;i<PIXELS_PER_BEAT;i=i+1) begin
        assign iframex16[(8+N_FUSE_COUNT)*i+:(8+N_FUSE_COUNT)] = curr_frame_emap[8*i+:8]<<N_FUSE_COUNT; 
        assign iframe[(8+N_FUSE_COUNT)*i+:8] = curr_frame_emap[8*i+:8]; 
        assign iframe[((8+N_FUSE_COUNT)*i+8)+:N_FUSE_COUNT] = 0; 
    end    
endgenerate
always @(*) begin
    avg_write_en = step & s_axis_aresetn;
    avg_read_en = step & s_axis_aresetn;
    if(load_avg) begin
        avg_buff_in = iframex16;
    end
    else if(old_frame) begin
        avg_buff_in = avg_frame_emap - iframe;
    end
    else begin //new_frame
        avg_buff_in = avg_frame_emap + iframe;
    end
end

//FUSED FRAME LOGIC
LSU #(PIXELS_PER_BEAT,IMAGE_DIM,8+N_FUSE_COUNT,SOBEL_DELAY) fused_frame_buff (s_axis_aclk,s_axis_aresetn,avg_read_en&step,avg_frame_emap,avg_write_en,avg_buff_in);


always @(*) begin
    s_axis_tready = m_axis_tready;
    step = (s_axis_tvalid & s_axis_tready);
end

//PIPELINED DATAPATH
CONV_SOBEL #(PIXELS_PER_BEAT,IMAGE_DIM) sobel_curr_frame (s_axis_aclk,s_axis_aresetn,~step,s_axis_tdata,curr_frame_emap);
FUSION #(PIXELS_PER_BEAT,IMAGE_DIM) m_fusion (s_axis_aclk,s_axis_aresetn,~step,fused_frame,s_axis_tdata,fused_frame_emap,curr_frame_emap,avg_frame_emap,out_frame);

always @(*) begin
    fused_frame_emap = (frame_counter == 0) ? curr_frame_emap : 0; //TODO: incomplete
end


endmodule
