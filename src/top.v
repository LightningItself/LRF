`timescale 1ns / 1ps

module LRF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 64,
    parameter PIXEL_SIZE = 8,
    parameter N_FUSE_COUNT = 4,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
)(
    input                       s_axis_aclk,
    input                       s_axis_aresetn,

    input [DATA_WIDTH-1:0]      s_axis_tdata,
    input                       s_axis_tvalid,
    output                      s_axis_tready,
    input                       s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

// Delays not needed

localparam FUSE_COUNT = 1<<N_FUSE_COUNT; // 16 frames to fuse
localparam FRAME_COUNTER_BITS = $clog2(2*FUSE_COUNT-1); // clog2(31) = 5 frame counter bits for 32 frames
localparam BEATS_PER_IMAGE = IMAGE_DIM*IMAGE_DIM/PIXELS_PER_BEAT; // 256 beats per frame
localparam BEAT_COUNTER_BITS = $clog2(BEATS_PER_IMAGE); // 8 beat counter bits for 1 frame

wire step = (s_axis_tvalid & s_axis_tready) & (m_axis_tready || !m_axis_tvalid);

//FUSION CONTROL STATES
reg [FRAME_COUNTER_BITS-1:0] frame_counter;
reg [BEAT_COUNTER_BITS-1:0] beat_counter; 

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

// RESET CHAIN NOT NEEDED

//---------------------AVG BUFFER------------------------------

reg avg_first, avg_add;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        avg_first <= 1;
        avg_add <= 0;
    end
    else if (step) begin
        if(s_axis_tlast) begin
            avg_add <= ~avg_add;
            if(frame_counter!=0) avg_first <= 0;
        end
    end
end

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] iframex17, iframe;
wire [DATA_WIDTH-1:0] avg_frame;

generate 
    for(i=0;i<PIXELS_PER_BEAT;i=i+1) begin
        assign iframex17[(9+N_FUSE_COUNT)*i+:(9+N_FUSE_COUNT)] = (s_axis_tdata[8*i+:8]<<N_FUSE_COUNT) + s_axis_tdata[8*i+:8]; 
        assign iframe[(9+N_FUSE_COUNT)*i+:8] = s_axis_tdata[8*i+:8]; 
        assign iframe[((9+N_FUSE_COUNT)*i+8)+:(N_FUSE_COUNT+1)] = 0; 

        assign avg_frame[(8*i)+:8] = (avg_first) ? s_axis_tdata[(8*i)+:8] : avg_frame_buff_out[((9+N_FUSE_COUNT)*i+N_FUSE_COUNT)+:8];
    end    
endgenerate

reg [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_buff_in;

always @(*) begin
    if(avg_first) begin
        avg_buff_in = iframex17;
    end
    else if(~avg_add) begin
        avg_buff_in = avg_frame_buff_out - iframe;
    end
    else begin
        avg_buff_in = avg_frame_buff_out + iframe;
    end
end

//------------------------------------HSSIM-FUSION DATAPATH--------------------------------------------

fusionTop #( .PIXELS_PER_BEAT = 16, .PIXEL_SIZE = 8, .IMAGE_DIM = 512) fusion_top(  
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_old_fused_tdata(s_axis_tdata), 
    .s_axis_old_fused_tvalid(),
    .s_axis_old_fused_tready(),
    .s_axis_old_fused_tlast(),
    .s_axis_avg_tdata(), 
    .s_axis_avg_tvalid(),
    .s_axis_avg_tready(),
    .s_axis_avg_tlast(),
    .s_axis_new_tdata(), 
    .s_axis_new_tvalid(),
    .s_axis_new_tready(),
    .s_axis_new_tlast(),
    .m_axis_tdata(),
    .m_axis_tvalid(),
    .m_axis_tready(),
    .m_axis_tlast()
);

endmodule