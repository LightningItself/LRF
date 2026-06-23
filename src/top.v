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

localparam IDLE = 2'b00;
localparam NEW  = 2'b01;
localparam OLD  = 2'b10;

reg [1:0] state;

reg [FRAME_COUNTER_BITS-1:0] frame_counter;

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
assign avg_buff_in = (state == OLD) ? int_sub : ((state == NEW) & (first == 0)) ? int_sum : iframex17;
assign avg_buff_in_valid = (state == OLD) ? sub_valid : (state == NEW) & (first == 0) ? sum_valid : valid_buff_new;
assign avg_buff_in_last = (state == OLD) ? sub_last : (state == NEW) & (first == 0) ? sum_last : last_buff_new;
wire old_state_ready = sub_ready_y & gate;
wire new_state_ready = (first == 1'b0) ? (add_ready_x & fusion_top_ready_y & new_gate) : 1'b0;
wire LSU_slave_ready = (state == OLD) ? old_state_ready : (state == NEW) ? new_state_ready : 1'b0;

reg gate;

reg first;

wire [DATA_WIDTH-1:0] fused_frame = (frame_counter == 0) ? data_buff_new : fetched_frame;
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
reg new_gate;
wire advance = m_axis_tready || ~m_axis_tvalid;
wire [DATA_WIDTH-1:0] fusion_avg_input;
wire fusion_avg_input_valid = (first == 1) ? valid_buff_new : avg_buff_out_valid;
wire fusion_avg_input_last = (first == 1) ? last_buff_new : avg_buff_out_last;

reg [DATA_WIDTH-1:0] data_buff_new;
reg valid_buff_new, last_buff_new;

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
                if(new_gate == 0) begin
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

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
    end
    else if(s_axis_tlast & s_axis_tready & s_axis_tvalid) begin 
            frame_counter <= frame_counter+1;
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        gate <= 0;
    end
    else begin
        if((state == OLD) && s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
            gate <= 0;
        end
        else if ((state == NEW) & s_axis_tlast & s_axis_tvalid & s_axis_tready) begin
            gate <= 1;
        end
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        new_gate <= 0;
    end
    else begin
        if((state == NEW) & s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
            new_gate <= 0;
        end
        else if ((state == IDLE) & s_axis_tvalid & s_axis_tready) begin
            new_gate <= 1;
        end
        else if((state == OLD) && (gate == 0)) begin
            new_gate <= 1;
        end
    end
end

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(9+N_FUSE_COUNT)) average(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid),
    .s_axis_tready(avg_lsu_ready),
    .s_axis_tlast(avg_buff_in_last),
    .m_axis_tdata(avg_buff_out),
    .m_axis_tvalid(avg_buff_out_valid),
    .m_axis_tready(LSU_slave_ready),
    .m_axis_tlast(avg_buff_out_last) 
);

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

genvar k;
generate 
    for(k=0; k<PIXELS_PER_BEAT; k=k+1) begin
         assign iframex17[(9+N_FUSE_COUNT)*k+:(9+N_FUSE_COUNT)] = (data_buff_new[8*k+:8]<<N_FUSE_COUNT) + data_buff_new[8*k+:8];
         assign fusion_avg_input[(8*k)+:8] = (first) ? data_buff_new[(8*k)+:8] : avg_buff_out[((9+N_FUSE_COUNT)*k+N_FUSE_COUNT)+:8];
    end
endgenerate

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        first <= 1;
    end
    else if(s_axis_tready & s_axis_tvalid & s_axis_tlast) begin
        first <= 0;
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff_new <= 0;
        valid_buff_new <= 0;
        last_buff_new <= 0;
    end
    else begin
        if(new_gate & (fusion_top_ready_z || !avg_buff_out_valid)) begin
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
    .m_axis_tready((frame_counter == 0) ? m_axis_tready : fusion_top_ready_x),
    .m_axis_tlast(fetched_frame_last) 
);

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
            .s_axis_tvalid_y(valid_buff_new & (state == NEW) & (first == 1'b0)),
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

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if((frame_counter ==0) & (state == NEW) & fetched_frame_valid & advance) begin
            m_axis_tdata <= fetched_frame;
            m_axis_tvalid <= 1;
            m_axis_tlast <= fetched_frame_last;
        end
        else if(m_axis_tready & m_axis_tvalid) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end

assign s_axis_tready = (state == IDLE) ? 1'b1 : 
                       (state == NEW)  ? new_gate & (fusion_top_ready_z || !avg_buff_out_valid) & ((frame_counter == 0) ? m_axis_tready : 1'b1) : 
                       (state == OLD)  ? (sub_ready_y || !avg_buff_out_valid) & gate : 1'b0;

endmodule