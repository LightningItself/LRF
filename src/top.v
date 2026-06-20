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

// Frames are coming alternatively as new -> old -> new -> old ......
// States change based on tlast

// State switching logic 

localparam IDLE = 2'b00;
localparam NEW  = 2'b01;
localparam OLD  = 2'b10;

reg [1:0] state;

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        state <= IDLE;
    end
    else begin
        case(state)
            IDLE: begin
                if(s_axis_tvalid & s_axis_tready) begin
                    state <= NEW;
                end
            end
            NEW: begin
                if(s_axis_tlast & s_axis_tvalid & s_axis_tready) begin
                    state <= OLD;
                end
            end
            OLD: begin
                if(sub_last & sub_valid & avg_lsu_ready) begin
                    state <= NEW;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// LOGIC FOR OLD STATE,  where the oldest frame comes into system,  here we only try to update the average and Fusion have no role in this state
// In the OLD state, fetch -> sub -> send it back (as a loop). So we need to axis_sub, LSU (common for 2 states). 
// Fetch have 1, sub have 1 and send it back have 1 cycle latency. LSU initialization wont be in this state. 

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_buff_in, avg_buff_out;
wire avg_buff_in_valid, avg_buff_in_last, avg_buff_out_valid, avg_buff_out_last;
wire avg_lsu_ready;

reg [DATA_WIDTH-1:0] data_buff;
reg valid_buff, last_buff;

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] int_sub;
wire [PIXELS_PER_BEAT-1:0] int_sub_valid, int_sub_last, sub_ready_a, sub_ready_b;
wire sub_ready = (&sub_ready_a) & (&sub_ready_b);
wire sub_valid = &int_sub_valid;
wire sub_last = &int_sub_last;
assign avg_buff_in = int_sub;
assign avg_buff_in_valid = sub_valid;
assign avg_buff_in_last = sub_last;

reg gate;

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(9+N_FUSE_COUNT)) average(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid),
    .s_axis_tready(avg_lsu_ready),
    .s_axis_tlast(avg_buff_in_last),
    .m_axis_tdata(avg_buff_out),
    .m_axis_tvalid(avg_buff_out_valid),
    .m_axis_tready(sub_ready & ~old_input_done),
    .m_axis_tlast(avg_buff_out_last) 
);

// avg_buff_out will have one cycle latency, so either we need to prefetch the data or delay the beat into sub by one cycle
// assuming when the state changes to OLD, the read pointer of LSU moved to 0 on same cycle
// Lets delay the beat by one cycle

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff <= 0;
        valid_buff <= 0;
        last_buff <= 0;
    end
    else begin
        if(sub_ready || (!avg_buff_out_valid & gate)) begin
            data_buff <= s_axis_tdata;
            valid_buff <= s_axis_tvalid;
            last_buff <= s_axis_tlast;
        end
    end
end

genvar i;
generate 
    for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin
        AXIS_UNSIGN_SUB #( .DATA_WIDTH(9+N_FUSE_COUNT)) sub(
            .aclk(s_axis_aclk),
            .aresetn(s_axis_aresetn),
            .s_axis_a_tdata(avg_buff_out[i*(9+N_FUSE_COUNT)+:(9+N_FUSE_COUNT)]),
            .s_axis_a_tvalid(avg_buff_out_valid & gate),
            .s_axis_a_tready(sub_ready_a[i]),
            .s_axis_a_tlast(avg_buff_out_last),
            .s_axis_b_tdata({ {(N_FUSE_COUNT+1){1'b0}}, data_buff[i*PIXEL_SIZE+:PIXEL_SIZE] }),
            .s_axis_b_tvalid(valid_buff & gate),
            .s_axis_b_tready(sub_ready_b[i]),
            .s_axis_b_tlast(last_buff),
            .m_axis_tdata(int_sub[i*(9+N_FUSE_COUNT)+:(9+N_FUSE_COUNT)]),
            .m_axis_tvalid(int_sub_valid[i]),
            .m_axis_tready(avg_lsu_ready),
            .m_axis_tlast(int_sub_last[i])
        );
    end
endgenerate

// lets say the system got last beat of the oldest frame, it will be read after 1 cycle, sub on 2nd cycle, written back on 3rd cycle
// do i need wait to in this state, for 3 cycles? or safely move to NEW state, as NEW state will be just reading the LSU but not writing anything
// but for this to happen, i should keep the sub active until the last updated beat is obtained from sub. 
// so i will be in OLD state until my sub_last came out and also LSU is ready to take it, so that on the next cycle when my LSU gets updated and at the 
// same time, my state is moved to NEW

// old state perspective : start -> gate should be 1, stop -> gate should be 0 
// sub master ready shouldnt be gated by gate, because if depends, once gate is 0, it wont advance so the data will be stuck
// Thinking only in old state and not bothering about NEW state now
// gate should go low in next egde if in this edge i got last_buff and sub is ready and accepted it and i should be in old state
// gate should be high in edge edge if in this edge i got s_axis_tlast and i should be in new state (something other logic will be there)

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        gate <= 0;
    end
    else begin
        if((state == OLD) & last_buff & sub_ready) begin
            gate <= 0;
        end
        else if (state == OLD) begin
            gate <= 1;
        end
    end
end

// once the tlast of input stream comes, i will fetch the last beat from LSU on next cycle and then stop fetching from LSU in old state
// since i made the 
// and once if i am OLD state and got tlast, i should not be ready until i change my state to NEW

reg old_input_done;

always @(posedge s_axis_aclk) begin
    if (!s_axis_aresetn) begin
        old_input_done <= 1'b0;
    end else begin
        if ((state == OLD) && s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
            old_input_done <= 1'b1;
        end 
        else if (state == NEW) begin
            old_input_done <= 1'b0;
        end
    end
end

assign s_axis_tready = (state == IDLE) ? 1'b1 : (state == NEW)  ? m_axis_tready : (state == OLD)  ? (sub_ready && !old_input_done) : 1'b0;

endmodule