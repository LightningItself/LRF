`timescale 1ns / 1ps

module LRF #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  IMAGE_DIM = 64,
    parameter  PIXEL_SIZE = 8,
    parameter  N_FUSE_COUNT = 4,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
) (
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

localparam FUSE_COUNT = 1<<N_FUSE_COUNT;
localparam BEATS_PER_IMAGE = IMAGE_DIM*IMAGE_DIM/PIXELS_PER_BEAT;
localparam BEAT_COUNTER_BITS = $clog2(BEATS_PER_IMAGE);
localparam FRAME_COUNTER_BITS = $clog2(2*FUSE_COUNT-1);

reg [FRAME_COUNTER_BITS-1:0] frame_counter;

wire advance = (m_axis_tready || ~m_axis_tvalid);

// Counter logic (BEAT COUNTER not req as it was used to sync the latencies of modules and counters)
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
    end
    else if(s_axis_tready & s_axis_tvalid & s_axis_tlast) begin
        frame_counter <= frame_counter+1;
    end
end

// Average buffer logic
reg avg_first, avg_add;

reg avg_first_buff, avg_add_buff;

reg [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_buff_in, avg_frame_buff_out;
reg [PIXELS_PER_BEAT-1:0] avg_buff_in_valid, avg_buff_in_last;
wire avg_buff_in_valid_wire = &avg_buff_in_valid;
wire avg_buff_in_last_wire = &avg_buff_in_last;

reg [DATA_WIDTH-1:0] avg_frame;
reg [PIXELS_PER_BEAT-1:0] avg_frame_valid, avg_frame_last;
reg [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] iframex17, iframe;
reg [PIXELS_PER_BEAT-1:0] iframex17_valid, iframex17_last, iframe_valid, iframe_last;
wire avg_frame_valid_wire = &avg_frame_valid;
wire avg_frame_last_wire = &avg_frame_last;
wire iframex17_valid_wire = &iframex17_valid;
wire iframex17_last_wire = &iframex17_last;
wire iframe_valid_wire = &iframe_valid;
wire iframe_last_wire = &iframe_last;

wire ready = (advance || !avg_buff_in_valid_wire);

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        avg_first <= 1;
        avg_add <= 0;
    end
    else if (s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
        avg_add <= ~avg_add;
        avg_first <= 0;
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        avg_first_buff <= 0;
        avg_add_buff <= 0;
    end
    else if(s_axis_tvalid & s_axis_tready) begin
        avg_first_buff <= avg_first;
        avg_add_buff <= avg_add;
    end
end

genvar i;
generate 
    for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin : stage1_pipeline
        always @(posedge s_axis_aclk) begin
            if(~s_axis_aresetn) begin
                iframex17[(9+N_FUSE_COUNT)*i+:(9+N_FUSE_COUNT)] <= 0;
                iframex17_valid[i] <= 0;
                iframex17_last[i] <= 0;
                iframe[(9+N_FUSE_COUNT)*i+:8] <= 0; 
                iframe[((9+N_FUSE_COUNT)*i+8)+:(N_FUSE_COUNT+1)] <= 0;
                iframe_valid[i] <= 0;
                iframe_last[i] <= 0;
                avg_frame[(8*i)+:8] <= 0;
                avg_frame_valid[i] <= 0;
                avg_frame_last[i] <= 0;
            end
            else begin
                if(s_axis_tvalid & s_axis_tready) begin
                    iframex17[(9+N_FUSE_COUNT)*i+:(9+N_FUSE_COUNT)] <= (s_axis_tdata[8*i+:8]<<N_FUSE_COUNT) + s_axis_tdata[8*i+:8];
                    iframex17_valid[i] <= 1;
                    iframex17_last[i] <= s_axis_tlast;
                    iframe[(9+N_FUSE_COUNT)*i+:8] <= s_axis_tdata[8*i+:8]; 
                    iframe[((9+N_FUSE_COUNT)*i+8)+:(N_FUSE_COUNT+1)] <= 0; 
                    iframe_valid[i] <= 1;
                    iframe_last[i] <= s_axis_tlast;
                    avg_frame[(8*i)+:8] <= (avg_first) ? s_axis_tdata[(8*i)+:8] : avg_frame_buff_out[((9+N_FUSE_COUNT)*i+N_FUSE_COUNT)+:8];
                    avg_frame_valid[i] <= 1;
                    avg_frame_last[i] <= s_axis_tlast;
                end
                else if(ready & iframex17_valid_wire & iframe_valid_wire) begin
                    iframex17_valid[i] <= 0;
                    iframex17_last[i] <= 0;
                    iframe_valid[i] <= 0;
                    iframe_last[i] <= 0;
                    avg_frame_valid[i] <= 0;
                    avg_frame_last[i] <= 0;
                end
            end
        end
    end    
endgenerate

integer j;
always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        avg_buff_in <= 0;
        avg_buff_in_valid <= 0;
        avg_buff_in_last <= 0;
    end
    else begin
        if(ready & iframex17_valid_wire & iframe_valid_wire) begin
            for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
                if(avg_first_buff) begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= iframex17[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframex17_last[j]; 
                end
                else if(avg_add_buff) begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= avg_frame_buff_out[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] - iframe[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframe_last[j]; 
                end
                else begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= avg_frame_buff_out[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] + iframe[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframe_last[j]; 
                end
            end
        end
        else if(some_ready_from_lsu & avg_buff_in_valid_wire) begin
            avg_buff_in_valid <= 0;
            avg_buff_in_last <= 0; 
        end
    end
end

endmodule