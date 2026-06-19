`timescale 1ns / 1ps

module avg_logic #(
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
localparam FRAME_COUNTER_BITS = $clog2(2*FUSE_COUNT-1);

wire advance = m_axis_tready || ~m_axis_tvalid;

reg [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_buff_in;
wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_frame_buff_out_a, avg_frame_buff_out_b;

// Frame Counter Logic
reg [FRAME_COUNTER_BITS-1:0] frame_counter;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
    end
    else if(s_axis_tready & s_axis_tvalid & s_axis_tlast) begin
        frame_counter <= frame_counter+1;
    end
end

// LSU CONTROL LOGIC
// Control logic to indicate which lsu is used for reading and writing and which lsu is being inactive for those 32 frames(old+new)
// Assume 32 frames(old+new) as a set, for first 2 frames (first new + first old) both lsus are active, from the very next frame, one becomes inactive
// For the first set, lsu a is active for entire set and avg_frame_buff_out is also from lsu a
// For the second set, from the first 2 frames (new+old), both are active and form the very next frame, lsu b is only active amd lsu a is inactive and 
// avg_frame_buff_out is from lsu b

reg avg_out_state, avg_next_state;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        avg_out_state  <= 1;
        avg_next_state <= 1;
    end
    else if(s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
        if(frame_counter == 31) begin
            avg_out_state  <= ~avg_out_state;
            avg_next_state <= 1;
        end
        else if(frame_counter == 1) begin
            avg_next_state <= 0;
        end
    end
end

wire lsu_a_ready, lsu_b_ready, avg_frame_buff_out_a_valid, avg_frame_buff_out_a_last, avg_frame_buff_out_b_valid, avg_frame_buff_out_b_last;
wire lsu_ready = avg_out_state ? lsu_a_ready : lsu_b_ready;

wire avg_curr_en = s_axis_tvalid & s_axis_tready;
wire avg_next_en = avg_next_state & s_axis_tvalid & s_axis_tready;
wire avg_en_a = (avg_out_state) ? avg_curr_en : avg_next_en;
wire avg_en_b = (~avg_out_state) ? avg_curr_en : avg_next_en;
wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_frame_buff_out = avg_out_state ? avg_frame_buff_out_a : avg_frame_buff_out_b;
wire avg_frame_buff_out_valid = avg_out_state ? avg_frame_buff_out_a_valid : avg_frame_buff_out_b_valid;
wire avg_frame_buff_out_last = avg_out_state ? avg_frame_buff_out_a_last : avg_frame_buff_out_b_last;

wire lsu_a_ready, lsu_b_ready, avg_frame_buff_out_a_valid, avg_frame_buff_out_a_last, avg_frame_buff_out_b_valid, avg_frame_buff_out_b_last;
wire lsu_ready = avg_out_state ? lsu_a_ready : lsu_b_ready;

reg avg_first, avg_add;

reg avg_first_buff, avg_add_buff;

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

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(9+N_FUSE_COUNT)) avg_frame_buff_a (
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid_wire & avg_en_a),
    .s_axis_tready(lsu_a_ready),
    .s_axis_tlast(avg_buff_in_last_wire),
    .m_axis_tdata(avg_frame_buff_out_a),
    .m_axis_tvalid(avg_frame_buff_out_a_valid),
    .m_axis_tready(advance & avg_en_a),
    .m_axis_tlast(avg_frame_buff_out_a_last)
);

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(9+N_FUSE_COUNT)) avg_frame_buff_b (
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid_wire & avg_en_b), 
    .s_axis_tready(lsu_b_ready),
    .s_axis_tlast(avg_buff_in_last_wire),
    .m_axis_tdata(avg_frame_buff_out_b),
    .m_axis_tvalid(avg_frame_buff_out_b_valid),
    .m_axis_tready(advance & avg_en_b),
    .m_axis_tlast(avg_frame_buff_out_b_last)  
);

// until now we wrote lsu switching logic, which will have 1 cycle latency in giving avg_frame_buff_out, now we will see the updating arithmetic
// so at the converging point i need to make sure, th iframe or iframex17 have one cycle latency.

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
    for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin
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
                else if(advance & iframex17_valid_wire & iframe_valid_wire) begin
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

// converging point
// both takes 1 cycle latency before reaching this stage

integer j;
always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        avg_buff_in <= 0;
        avg_buff_in_valid <= 0;
        avg_buff_in_last <= 0;
    end
    else begin
        if(advance) begin
            for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
                if(avg_first_buff & iframex17_valid_wire) begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= iframex17[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframex17_last_wire; 
                end
                else if(avg_add_buff & iframe_valid_wire) begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= avg_frame_buff_out[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] - iframe[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframe_last_wire & iframe_last_wire;
                end
                else if (iframe_valid_wire) begin
                    avg_buff_in[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] <= avg_frame_buff_out[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)] + iframe[(9+N_FUSE_COUNT)*j+:(9+N_FUSE_COUNT)];
                    avg_buff_in_valid[j] <= 1'b1;
                    avg_buff_in_last[j] <= iframe_last_wire & iframe_last_wire; 
                end
            end
        end
        else if(lsu_ready & avg_buff_in_valid_wire) begin
            avg_buff_in_valid <= 0;
            avg_buff_in_last <= 0; 
        end
    end
end

// so avg_buff_in is having latency of 2 cycles and then written into LSU, avg_frame will have latency of 1 cycle so before the writing the new value
// the old average is stored in avg_frame, now passing this as output will add once more cycle which matches the avg_buff_in

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(avg_frame_valid_wire & advance) begin
            m_axis_tdata <= avg_frame;
            m_axis_tvalid <= 1;
            m_axis_tlast <= avg_frame_last_wire;
        end
        else if(m_axis_tvalid & m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end

assign s_axis_tready = advance;

endmodule