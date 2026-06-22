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
                    new_gate <= 1
                end
            end
            NEW: begin
                if(s_axis_tlast & s_axis_tvalid & s_axis_tready) begin
                    state <= OLD;
                end
            end
            OLD: begin
                if(gate == 0) begin
                    state <= NEW;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Logic for frame counter
reg [FRAME_COUNTER_BITS-1:0] frame_counter;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
    end
    else if(s_axis_tlast & s_axis_tready & s_axis_tvalid) begin // So that the pointer is ready when the state changes
            frame_counter <= frame_counter+1;
    end
end

// LOGIC FOR OLD STATE

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] avg_buff_in, avg_buff_out;
wire avg_buff_in_valid, avg_buff_in_last, avg_buff_out_valid, avg_buff_out_last;
wire avg_lsu_ready;

reg [DATA_WIDTH-1:0] data_buff_old;
reg valid_buff_old, last_buff_old;

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] int_sub;
wire [PIXELS_PER_BEAT-1:0] int_sub_valid, int_sub_last, sub_ready_a, sub_ready_b;
wire sub_ready_x = &sub_ready_a;
wire sub_ready_y = &sub_ready_b;
wire sub_valid = &int_sub_valid;
wire sub_last = &int_sub_last;
assign avg_buff_in = (state == OLD) ? int_sub : ((state == NEW) & (first != 0)) ? int_sum : iframex17;
assign avg_buff_in_valid = (state == OLD) ? sub_valid : (state == NEW) ? sum_valid;
assign avg_buff_in_last = (state == OLD) ? sub_last : (state == NEW) ? sum_last;
wire old_state_ready = sub_ready_y & gate;
wire new_state_ready = ;
wire LSU_slave_ready = (state == OLD) ? old_state_ready : (state == NEW) ? new_state_ready;

reg gate;

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(9+N_FUSE_COUNT)) average(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid),
    .s_axis_tready(avg_lsu_ready),
    .s_axis_tlast(avg_buff_in_last),
    .m_axis_tdata(avg_buff_out),
    .m_axis_tvalid(avg_buff_out_valid), // Actually this should be high after NEW state, check this for the first beat of oldest frame.
    .m_axis_tready(LSU_slave_ready), // be careful with this in NEW state after OLD state
    .m_axis_tlast(avg_buff_out_last) 
);

// avg_buff_out will have one cycle latency, so either we need to prefetch the data or delay the beat into sub by one cycle
// assuming when the state changes to OLD, the read pointer of LSU moved to 0 on same cycle
// Lets delay the beat by one cycle

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff_old <= 0;
        valid_buff_old <= 0;
        last_buff_old <= 0;
    end
    else begin
        if((sub_ready_y || !avg_buff_out_valid) & gate) begin
            data_buff_old <= s_axis_tdata;
            valid_buff_old <= s_axis_tvalid;
            last_buff_old <= s_axis_tlast;
        end
        else if (!gate) begin
            valid_buff_old <= 1'b0;
            last_buff_old  <= 1'b0;
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
            .s_axis_a_tvalid(avg_buff_out_valid & (state == OLD)),
            .s_axis_a_tready(sub_ready_a[i]),
            .s_axis_a_tlast(avg_buff_out_last),
            .s_axis_b_tdata({ {(N_FUSE_COUNT+1){1'b0}}, data_buff_old[i*PIXEL_SIZE+:PIXEL_SIZE] }),
            .s_axis_b_tvalid(valid_buff_old & (state == OLD)),
            .s_axis_b_tready(sub_ready_b[i]),
            .s_axis_b_tlast(last_buff_old),
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
// sub master ready shouldnt be gated by gate, because if depends, once gate is 0, it wont advance so the data will be stuck 
// so i will be in OLD state until my sub_last came out and also LSU is ready to take it, so that on the next cycle when my LSU gets updated, at the 
// same cycle, my state is moved to NEW, the LSU read and write pointers are now 0!

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        gate <= 0;
    end
    else begin
        if((state == OLD) && s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
            gate <= 0; // the moment the accepted the last beat of oldest frame, i then on next cycle, make the gate 0.
        end
        else if ((state == NEW) & s_axis_tlast & s_axis_tvalid & s_axis_tready) begin
            gate <= 1; // when i got the first beat of oldest frame, i will have my gate = 1 on same cycle
        end
    end
end

// once if i am in OLD state and got tlast, i should not be ready until i change my state to NEW

// Moving to the NEW state
// Here in this state, we need to read the old average, send it to fusion, and send to adder at the same time and should write the updated
// average into LSU. Any how the read is first, so no error should come. 
// We have another LSU for storing the Fusion outputs
// By the time, the NEW state arrives from OLD state, read and write pointers of LSU are 0

// Logic for NEW state
// output of FusionTop is moved to LSU which store the fused frames
// for the first new frame, the fused frame is the new frame itself, they pass through FusionTop and then output is stored in LSu
// from the next new frames, the recently stored fusion frame is in LSU, so we fetch that and send it to FusionTop and then the updated fused frame is again sent to LSU
// like this, the fused frame gets updated and when the 16 new frames are consumed, the stored fusion frame goes as output of module also again moves to FusionTop.
// so for the 16 new frames, we will be getting one fused output.
// parallely we need to update the avgerage too. avg updation have very less latency compared to FusionTop, so there might be a risk of multiple sampling of same beat
// so whenever the FusionTop is ready, average should be ready.

// lets start with FusionTop and LSU locic

// in thesis, its mentioned, Once 16 images have been fused, it will be sent out from the DDR3; the 17th image replaces the existing fused image in DDR3,
//serving as the new reference for the next 16-image fusion cycle. so took help of frame_counter

reg first;

wire [DATA_WIDTH-1:0] fused_frame = (frame_counter == 0) ? data_buff_new : fetched_frame; // because fetched_frame have latency, to make logic simple, we even delayed the inputs
wire fused_frame_valid = (frame_counter == 0) ? valid_buff_new : fetched_frame_valid;
wire fused_frame_last = (frame_counter == 0) ? last_buff_new : fetched_frame_last;

wire [DATA_WIDTH-1:0] out_fused_frame;
wire out_fused_frame_valid, out_fused_frame_last;
wire fusion_top_ready_x, fusion_top_ready_y, fusion_top_ready_z;

wire fuse_ready;
wire [DATA_WIDTH-1:0] fetched_frame;
wire fetched_frame_valid, fetched_frame_last;

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] int_sum;
wire [PIXELS_PER_BEAT-1:0] add_ready_a, add_ready_b, add_ready_c, int_sum_valid, int_sum_last;
wire sum_valid = &int_sum_valid;
wire sum_last = &int_sum_last;
wire add_ready_x = &add_ready_a;
wire add_ready_y = &add_ready_b;
wire add_ready_z = &add_ready_c;

wire [DATA_WIDTH+(N_FUSE_COUNT+1)*PIXELS_PER_BEAT-1:0] iframex17;
genvar k;
generate 
    for(k=0; k<PIXELS_PER_BEAT; k=k+1) begin
         assign iframex17[(9+N_FUSE_COUNT)*k+:(9+N_FUSE_COUNT)] = (data_buff_new[8*k+:8]<<N_FUSE_COUNT) + data_buff_new[8*k+:8];
         assign fusion_avg_input[(8*k)+:8] = (first) ? iframex17[(8*k)+:8] : avg_buff_out[((9+N_FUSE_COUNT)*k+N_FUSE_COUNT)+:8];
    end
endgenerate
wire fusion_avg_input_valid = (first == 1) ? valid_buff_new : avg_buff_out_valid;
wire fusion_avg_input_last = (first == 1) ? last_buff_new : avg_buff_out_last;

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        first <= 1;
    end
    else if(s_axis_tready & s_axis_tvalid & s_axis_tlast) begin
        first <= 0; // permanently 0 after first frame
    end
end

reg [DATA_WIDTH-1:0] data_buff_new;
reg valid_buff_new, last_buff_new;

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff_new <= 0;
        valid_buff_new <= 0;
        last_buff_new <= 0;
    end
    else begin
        if() begin
            data_buff_new <= s_axis_tdata;
            valid_buff_new <= s_axis_tvalid;
            last_buff_new <= s_axis_tlast;
        end
        else if (!new_gate) begin
            valid_buff_new <= 1'b0;
            last_buff_new <= 1'b0;
        end
    end
end

// fused and avg are delayed, so new should also be delayed

fusionTop #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) fusion_top(  
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_old_fused_tdata(fused_frame), 
    .s_axis_old_fused_tvalid(fused_frame_valid & (state == NEW)),
    .s_axis_old_fused_tready(fusion_top_ready_x),
    .s_axis_old_fused_tlast(fused_frame_last),
    .s_axis_avg_tdata(fusion_avg_input), 
    .s_axis_avg_tvalid(fusion_avg_input_valid & (state == NEW)),
    .s_axis_avg_tready(fusion_top_ready_y),
    .s_axis_avg_tlast(fusion_avg_input_last),
    .s_axis_new_tdata(data_buff_new), 
    .s_axis_new_tvalid(valid_buff_new & (state == NEW)),
    .s_axis_new_tready(fusion_top_ready_z),
    .s_axis_new_tlast(last_buff_new),
    .m_axis_tdata(out_fused_frame),
    .m_axis_tvalid(out_fused_frame_valid),
    .m_axis_tready(fuse_ready),
    .m_axis_tlast(out_fused_frame_last)
);


LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(PIXEL_SIZE)) fuse(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(out_fused_frame),
    .s_axis_tvalid(out_fused_frame_valid),
    .s_axis_tready(fuse_ready),
    .s_axis_tlast(out_fused_frame_last),
    .m_axis_tdata(fetched_frame),
    .m_axis_tvalid(fetched_frame_valid),
    .m_axis_tready((frame_counter == 0) ? 1'b0 : fusion_top_ready_x),
    .m_axis_tlast(fetched_frame_last) 
);

// fetching fused frame takes 1 cycle delay 

genvar j;
generate 
    for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
        axis_adder #( .DATA_WIDTH(9+N_FUSE_COUNT), .mode(0)) add(
            .aclk(s_axis_aclk),
            .aresetn(s_axis_aresetn),
            .s_axis_tdata_x(avg_buff_out[j*(9+N_FUSE_COUNT)+:(9+N_FUSE_COUNT)]),
            .s_axis_tvalid_x(avg_buff_out_valid & (state == NEW) & (first == 1'b0)),
            .s_axis_tready_x(add_ready_a[j]),
            .s_axis_tlast_x(avg_buff_out_last),
            .s_axis_tdata_y({ {(N_FUSE_COUNT+1){1'b0}}, data_buff_new[j*PIXEL_SIZE+:PIXEL_SIZE] }),
            .s_axis_tvalid_y(valid_buff_new & & (state == NEW) & (first == 1'b0)),
            .s_axis_tready_y(add_ready_b[j]),
            .s_axis_tlast_y(last_buff_new),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1),
            .s_axis_tready_z(add_ready_c[j]),
            .s_axis_tlast_z(1),
            .m_axis_tdata(int_sum[j*(9+N_FUSE_COUNT)+:(9+N_FUSE_COUNT)]),
            .m_axis_tvalid(int_sum_valid[j]),
            .m_axis_tready(avg_lsu_ready),
            .m_axis_tlast(int_sum_last[j])
        );
    end
endgenerate

// i should be in this state, until the final fused frame gets updated. 

reg new_gate;
always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        new_gate <= 0;
    end
    else begin
        if((state == NEW) & s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
            new_gate <= 0;
        end
        else if(gate == 0) begin
            new_gate <= 1;
        end
    end
end

assign s_axis_tready = (state == IDLE) ? 1'b1 : (state == NEW)  ? m_axis_tready : (state == OLD)  ? (sub_ready_y || !avg_buff_out_valid) & gate : 1'b0;

endmodule