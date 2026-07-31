`timescale 1ns / 1ps

module LRF #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  IMAGE_DIM = 512,
    parameter  PIXEL_SIZE = 8,
    parameter  N_FUSE_COUNT = 4,
    parameter DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
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
localparam FRAME_COUNTER_BITS = $clog2(FUSE_COUNT-1);
localparam NEW = 0, OLD = 1, SEND = 2;

// WIRE DECLARATIONS
wire advance = m_axis_tready || ~m_axis_tvalid;

reg [FRAME_COUNTER_BITS:0] frame_counter;

reg [1:0] state;
reg first, new_stop, old_stop;
always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        first <= 1;
    end
    else if(out_fused_frame_last & fuse_ready) begin 
        first <= 0;
    end
end

genvar k;
wire [DATA_WIDTH+(N_FUSE_COUNT)*PIXELS_PER_BEAT-1:0] iframex16;
generate 
    for(k=0; k<PIXELS_PER_BEAT; k=k+1) begin :iframex16_block
         assign iframex16[(8+N_FUSE_COUNT)*k+:(8+N_FUSE_COUNT)] = (data_buff_new[8*k+:8]<<N_FUSE_COUNT);
    end
endgenerate

reg [DATA_WIDTH-1:0] data_buff_new;
reg valid_buff_new, last_buff_new;

// frame_lsu wires
wire [DATA_WIDTH-1:0] frame_lsu_out;
wire frame_lsu_ready, frame_lsu_out_valid, frame_lsu_out_last;

//add_sub wires
wire [DATA_WIDTH+(N_FUSE_COUNT)*PIXELS_PER_BEAT-1:0] add_sub_out;
wire [PIXELS_PER_BEAT-1:0] add_sub_ready_a, add_sub_ready_b, add_sub_ready_c, int_add_sub_out_valid, int_add_sub_out_last;
wire add_sub_ready_x = &add_sub_ready_a;
wire add_sub_ready_y = &add_sub_ready_b;
wire add_sub_ready_z = &add_sub_ready_c;
wire add_sub_valid = &int_add_sub_out_valid;
wire add_sub_last = &int_add_sub_out_last;

// avg lsu wires
wire [DATA_WIDTH+(N_FUSE_COUNT)*PIXELS_PER_BEAT-1:0] avg_buff_out;
wire avg_buff_out_valid, avg_buff_out_last, avg_lsu_ready;
wire [DATA_WIDTH+(N_FUSE_COUNT)*PIXELS_PER_BEAT-1:0] avg_buff_in = (first) ? iframex16 : ((frame_counter == 16) ? add_sub_out : 0);
wire avg_buff_in_valid = (first) ? valid_buff_new : ((frame_counter == 16) ? add_sub_valid : 0);
wire avg_buff_in_last = (first) ? last_buff_new : ((frame_counter == 16) ? add_sub_last : 0);

// fuse lsu wires
wire [DATA_WIDTH-1:0] fetched_frame;
wire fetched_frame_valid, fetched_frame_last, fuse_ready;

// fusionTop wires
wire [DATA_WIDTH-1:0] fused_frame = (frame_counter == 0) ? data_buff_new : fetched_frame;
wire fused_frame_valid = (frame_counter == 0) ? valid_buff_new : fetched_frame_valid;
wire fused_frame_last = (frame_counter == 0) ? last_buff_new : fetched_frame_last;
wire [DATA_WIDTH-1:0] fusion_avg_input;
generate 
    for(k=0; k<PIXELS_PER_BEAT; k=k+1) begin
         assign fusion_avg_input[(8*k)+:8] = (first) ? data_buff_new[(8*k)+:8] : avg_buff_out[((8+N_FUSE_COUNT)*k+N_FUSE_COUNT)+:8];
    end
endgenerate
wire fusion_avg_input_valid = (first) ? valid_buff_new : avg_buff_out_valid;
wire fusion_avg_input_last = (first) ? last_buff_new : avg_buff_out_last;
wire [DATA_WIDTH-1:0] out_fused_frame;
wire out_fused_frame_valid, out_fused_frame_last;
wire fusion_top_ready_x, fusion_top_ready_y, fusion_top_ready_z;

// old buffs
reg [DATA_WIDTH-1:0] data_buff_old;
reg valid_buff_old, last_buff_old;


// DATAPATH
always@(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        frame_counter <= 0;
    end
    else begin
        if((state == NEW) & out_fused_frame_last & fuse_ready) begin 
            frame_counter <= frame_counter + 1;
        end
        else if((state == OLD) & add_sub_last) begin
            frame_counter <= 0;
        end
    end
end

reg fuse_lsu_reset;
always@(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        fuse_lsu_reset <= 0;
    end
    else begin
        if(m_axis_tready & m_axis_tvalid & m_axis_tlast) begin
            fuse_lsu_reset <= 0;
        end
        else if((state == NEW)) begin
            fuse_lsu_reset <= 1;
        end
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        state <= NEW;
    end
    else begin
        case(state)
            NEW: begin
                if(out_fused_frame_last & fuse_ready & (frame_counter == 15)) begin
                    state <= OLD;
                end
            end
            OLD: begin
                if(add_sub_last & avg_lsu_ready) begin
                    state <= SEND;
                end
            end
            SEND: begin
                if(m_axis_tready & m_axis_tvalid & m_axis_tlast) begin
                    state <= NEW;
                end
            end
            default: begin
                state <= NEW;
            end
        endcase
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        new_stop <= 1;
    end
    else begin
        if((state == NEW) & s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
            new_stop <= 0;
        end
        else if((state == OLD) || ((state == NEW) & out_fused_frame_last & fuse_ready)) begin
            new_stop <= 1;
        end
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff_new  <= 0;
        valid_buff_new <= 0;
        last_buff_new  <= 0;
    end
    else begin
        if((state == NEW) & (first || fusion_top_ready_z || !valid_buff_new) & s_axis_tvalid & s_axis_tready) begin
            data_buff_new  <= s_axis_tdata;
            valid_buff_new <= s_axis_tvalid;
            last_buff_new  <= s_axis_tlast;
        end
        else if((state == OLD) || (valid_buff_new & (first || fusion_top_ready_z))) begin
            valid_buff_new <= 1'b0;
            last_buff_new  <= 1'b0;
        end
    end
end

LSU_valid #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(PIXEL_SIZE)) frame(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(data_buff_new),
    .s_axis_tvalid((frame_counter == 0) & valid_buff_new & fusion_top_ready_x),
    .s_axis_tready(frame_lsu_ready),
    .s_axis_tlast(last_buff_new),
    .m_axis_tdata(frame_lsu_out),
    .m_axis_tvalid(frame_lsu_out_valid),
    .m_axis_tready(add_sub_ready_x),
    .m_axis_tlast(frame_lsu_out_last) 
);

LSU #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(8+N_FUSE_COUNT)) average(
    .aclk(s_axis_aclk),
    .aresetn(s_axis_aresetn),
    .s_axis_tdata(avg_buff_in),
    .s_axis_tvalid(avg_buff_in_valid),
    .s_axis_tready(avg_lsu_ready),
    .s_axis_tlast(avg_buff_in_last),
    .m_axis_tdata(avg_buff_out),
    .m_axis_tvalid(avg_buff_out_valid),
    .m_axis_tready((state == NEW) ? fusion_top_ready_x : add_sub_ready_x),
    .m_axis_tlast(avg_buff_out_last) 
);

LSU_valid #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .BIT_WIDTH(PIXEL_SIZE)) fuse(
    .aclk(s_axis_aclk),
    .aresetn(fuse_lsu_reset),
    .s_axis_tdata(out_fused_frame),
    .s_axis_tvalid(out_fused_frame_valid),
    .s_axis_tready(fuse_ready),
    .s_axis_tlast(out_fused_frame_last),
    .m_axis_tdata(fetched_frame),
    .m_axis_tvalid(fetched_frame_valid),
    .m_axis_tready(((state == SEND)) ? ((~first) & advance) : ((state == NEW) & fusion_top_ready_z)),   
    .m_axis_tlast(fetched_frame_last) 
);

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

// when oldest frame arrives, need to update the average

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        data_buff_old <= 0;
        valid_buff_old <= 0;
        last_buff_old <= 0;
    end
    else begin
        if((state == OLD) & s_axis_tvalid & s_axis_tready) begin
            data_buff_old <= s_axis_tdata;
            valid_buff_old <= s_axis_tvalid;
            last_buff_old <= s_axis_tlast;
        end
        else if((frame_counter == 0) || (valid_buff_old & add_sub_ready_x)) begin
            valid_buff_old <= 0;
            last_buff_old <= 0;
        end
    end
end

genvar j;
generate 
    for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
        axis_add_sub #( .DATA_WIDTH(8+N_FUSE_COUNT), .mode(0)) add_sub(
            .aclk(s_axis_aclk),
            .aresetn(s_axis_aresetn),
            .s_axis_tdata_x(avg_buff_out[j*(8+N_FUSE_COUNT)+:(8+N_FUSE_COUNT)]),
            .s_axis_tvalid_x(avg_buff_out_valid & (state == OLD)),
            .s_axis_tready_x(add_sub_ready_a[j]),
            .s_axis_tlast_x(avg_buff_out_last),
            .s_axis_tdata_y({ {(N_FUSE_COUNT){1'b0}}, data_buff_old[j*PIXEL_SIZE+:PIXEL_SIZE] }),
            .s_axis_tvalid_y(valid_buff_old & (state == OLD)),
            .s_axis_tready_y(add_sub_ready_b[j]),
            .s_axis_tlast_y(last_buff_old),
            .s_axis_tdata_z({ {(N_FUSE_COUNT){1'b0}}, frame_lsu_out[j*PIXEL_SIZE+:PIXEL_SIZE] }),
            .s_axis_tvalid_z(frame_lsu_out_valid & (state == OLD)),
            .s_axis_tready_z(add_sub_ready_c[j]),
            .s_axis_tlast_z(frame_lsu_out_last),
            .m_axis_tdata(add_sub_out[j*(8+N_FUSE_COUNT)+:(8+N_FUSE_COUNT)]),
            .m_axis_tvalid(int_add_sub_out_valid[j]),
            .m_axis_tready(avg_lsu_ready),
            .m_axis_tlast(int_add_sub_out_last[j])
        );
    end
endgenerate

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        old_stop <= 0;
    end
    else begin
        if((state == OLD) & s_axis_tvalid & s_axis_tready & s_axis_tlast) begin
            old_stop <= 0; // so that stop wont allow the beat after the last beat into module
        end
        else if(state == NEW) begin
            old_stop <= 1;
        end
    end
end

always @(posedge s_axis_aclk) begin
    if(!s_axis_aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if((state == SEND)& (~first) & advance) begin
            m_axis_tdata <= fetched_frame;
            m_axis_tvalid <= (m_axis_tlast ? 0 : 1);
            m_axis_tlast <= fetched_frame_last;
        end
        else if(m_axis_tready & m_axis_tvalid) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end


assign s_axis_tready = (state == NEW) ? ((first == 1) ? (avg_lsu_ready & new_stop) : ((fusion_top_ready_x || !valid_buff_new) & new_stop)) : 
                       (state == OLD) ? (old_stop) : 1'b0; 

endmodule