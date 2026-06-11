`timescale 1ns / 1ps

module fusionTop #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE = 8,
    parameter IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
)(  
    input                           aclk,
    input                           aresetn,
    input [DATA_WIDTH-1:0]          s_axis_old_fused_tdata, 
    input                           s_axis_old_fused_tvalid,
    output                          s_axis_old_fused_tready,
    input                           s_axis_old_fused_tlast,
    input [DATA_WIDTH-1:0]          s_axis_avg_tdata, 
    input                           s_axis_avg_tvalid,
    output                          s_axis_avg_tready,
    input                           s_axis_avg_tlast,
    input [DATA_WIDTH-1:0]          s_axis_new_tdata, 
    input                           s_axis_new_tvalid,
    output                          s_axis_new_tready,
    input                           s_axis_new_tlast,
    output reg [DATA_WIDTH-1:0]     m_axis_tdata,
    output reg                      m_axis_tvalid,
    input                           m_axis_tready,
    output reg                      m_axis_tlast
);

// Wire Declarations

wire advance = (m_axis_tready || ~m_axis_tvalid);

wire [DATA_WIDTH-1:0] old_fused_edge, avg_edge, new_edge;
wire old_fused_edge_valid, old_fused_edge_last, avg_edge_valid, avg_edge_last, new_edge_valid, new_edge_last;
wire sob_old_fused_ready, sob_avg_ready, sob_new_ready;

wire [DATA_WIDTH-1:0] del; 
wire hssim_ready_x, hssim_ready_y, hssim_ready_z, del_valid, del_last;

wire [DATA_WIDTH-1:0] del_gauss;
wire gauss_ready, del_gauss_valid, del_gauss_last;

reg [DATA_WIDTH-1:0] old_fused_buff_1, new_buff_1;
reg old_fused_buff_1_valid, old_fused_buff_1_last, new_buff_1_valid, new_buff_1_last;

reg [DATA_WIDTH-1:0] old_fused_buff_2, new_buff_2;
reg old_fused_buff_2_valid, old_fused_buff_2_last, new_buff_2_valid, new_buff_2_last;

reg [DATA_WIDTH-1:0] old_fused_buff_3, new_buff_3;
reg old_fused_buff_3_valid, old_fused_buff_3_last, new_buff_3_valid, new_buff_3_last;

reg [DATA_WIDTH-1:0] del_buff_1;
reg del_buff_1_valid, del_buff_1_last;

wire [DATA_WIDTH-1:0] fused_frame;
wire fused_frame_valid, fused_frame_last, fusion_ready_x, fusion_ready_y, fusion_ready_z;

reg [DATA_WIDTH-1:0] old_fused_buff_4;
reg old_fused_buff_4_valid, old_fused_buff_4_last;

reg [DATA_WIDTH-1:0] del_buff_2;
reg del_buff_2_valid, del_buff_2_last;

// DataPath

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_old_fused (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_old_fused_tdata),
    .s_axis_tvalid(s_axis_old_fused_tvalid),
    .s_axis_tready(sob_old_fused_ready),
    .s_axis_tlast(s_axis_old_fused_tlast),
    .m_axis_tdata(old_fused_edge),
    .m_axis_tvalid(old_fused_edge_valid),
    .m_axis_tready(hssim_ready_x),
    .m_axis_tlast(old_fused_edge_last)
);

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_avg (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_avg_tdata),
    .s_axis_tvalid(s_axis_avg_tvalid),
    .s_axis_tready(sob_avg_ready),
    .s_axis_tlast(s_axis_avg_tlast),
    .m_axis_tdata(avg_edge),
    .m_axis_tvalid(avg_edge_valid),
    .m_axis_tready(hssim_ready_y),
    .m_axis_tlast(avg_edge_last)
);

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_new (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_new_tdata),
    .s_axis_tvalid(s_axis_new_tvalid),
    .s_axis_tready(sob_new_ready),
    .s_axis_tlast(s_axis_new_tlast),
    .m_axis_tdata(new_edge),
    .m_axis_tvalid(new_edge_valid),
    .m_axis_tready(hssim_ready_z),
    .m_axis_tlast(new_edge_last)
);

always @(posedge aclk) begin
    if(~aresetn) begin
        old_fused_buff_1 <= 0;
        new_buff_1 <= 0;
        old_fused_buff_1_valid <= 0;
        old_fused_buff_1_last <= 0;
        new_buff_1_valid <= 0;
        new_buff_1_last <= 0;
    end
    else begin
        if(s_axis_old_fused_tvalid & sob_old_fused_ready & s_axis_new_tvalid & sob_new_ready) begin
            old_fused_buff_1 <= s_axis_old_fused_tdata;
            new_buff_1 <= s_axis_new_tdata;
            old_fused_buff_1_valid <= s_axis_old_fused_tvalid;
            old_fused_buff_1_last <= s_axis_old_fused_tlast;
            new_buff_1_valid <= s_axis_new_tvalid;
            new_buff_1_last <= s_axis_new_tlast;
        end
        else if(old_fused_edge_valid & hssim_ready_x & new_edge_valid & hssim_ready_z) begin
            old_fused_buff_1_valid <= 0;
            old_fused_buff_1_last <= 0;
            new_buff_1_valid <= 0;
            new_buff_1_last <= 0;
        end
    end
end

HSSIM_TOP #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) hssim(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_map(old_fused_edge),
    .old_map_valid(old_fused_edge_valid),
    .old_map_ready(hssim_ready_x),
    .old_map_last(old_fused_edge_last),
    .avg_map(avg_edge),
    .avg_map_valid(avg_edge_valid),
    .avg_map_ready(hssim_ready_y),
    .avg_map_last(avg_edge_last),
    .new_map(new_edge),
    .new_map_valid(new_edge_valid),
    .new_map_ready(hssim_ready_z),
    .new_map_last(new_edge_last),
    .del(del),
    .del_valid(del_valid),
    .del_ready(gauss_ready),
    .del_last(del_last)
);

always @(posedge aclk) begin
    if(~aresetn) begin
        old_fused_buff_2 <= 0;
        new_buff_2 <= 0;
        old_fused_buff_2_valid <= 0;
        old_fused_buff_2_last <= 0;
        new_buff_2_valid <= 0;
        new_buff_2_last <= 0;
    end
    else begin
        if(old_fused_edge_valid & avg_edge_valid & avg_edge_valid & hssim_ready_x & hssim_ready_y & hssim_ready_z) begin
            old_fused_buff_2 <= old_fused_buff_1;
            new_buff_2 <= new_buff_1;
            old_fused_buff_2_valid <= old_fused_buff_1_valid;
            old_fused_buff_2_last <= old_fused_buff_1_last;
            new_buff_2_valid <= new_buff_1_valid;
            new_buff_2_last <= new_buff_1_last;
        end
        else if(del_valid & gauss_ready) begin
            old_fused_buff_2_valid <= 0;
            old_fused_buff_2_last <= 0;
            new_buff_2_valid <= 0;
            new_buff_2_last <= 0;
        end
    end
end

CONV_GAUSS #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(del),
    .s_axis_tvalid(del_valid),
    .s_axis_tready(gauss_ready),
    .s_axis_tlast(del_last),
    .m_axis_tdata(del_gauss),
    .m_axis_tvalid(del_gauss_valid),
    .m_axis_tready(fusion_ready_x & fusion_ready_y & fusion_ready_z),
    .m_axis_tlast(del_gauss_last)
);

always @(posedge aclk) begin
    if(~aresetn) begin
        old_fused_buff_3 <= 0;
        new_buff_3 <= 0;
        old_fused_buff_3_valid <= 0;
        old_fused_buff_3_last <= 0;
        new_buff_3_valid <= 0;
        new_buff_3_last <= 0;
    end
    else begin
        if(del_valid & gauss_ready) begin
            old_fused_buff_3 <= old_fused_buff_2;
            new_buff_3 <= new_buff_2;
            old_fused_buff_3_valid <= old_fused_buff_2_valid;
            old_fused_buff_3_last <= old_fused_buff_2_last;
            new_buff_3_valid <= new_buff_2_valid;
            new_buff_3_last <= new_buff_2_last;
        end
        else if(del_gauss_valid & fusion_ready_x & fusion_ready_y & fusion_ready_z) begin
            old_fused_buff_3_valid <= 0;
            old_fused_buff_3_last <= 0;
            new_buff_3_valid <= 0;
            new_buff_3_last <= 0;
        end
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        del_buff_1 <= 0;
        del_buff_1_valid <= 0;
        del_buff_1_last <= 0;
    end
    else begin
        if(del_valid & gauss_ready) begin
            del_buff_1 <= del;
            del_buff_1_valid <= del_valid;
            del_buff_1_last <= del_last;
        end
        else if(del_gauss_valid & fusion_ready_x & fusion_ready_y & fusion_ready_z) begin
            del_buff_1_valid <= 0;
            del_buff_1_last <= 0;
        end
    end
end

FUSION #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .PIXEL_SIZE(PIXEL_SIZE)) fusion(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_frame(old_fused_buff_3),
    .old_frame_tvalid(old_fused_buff_3_valid),
    .old_frame_tready(fusion_ready_x),
    .old_frame_tlast(old_fused_buff_3_last),
    .new_frame(new_buff_3),
    .new_frame_tvalid(new_buff_3_valid),
    .new_frame_tready(fusion_ready_y),
    .new_frame_tlast(new_buff_3_last),
    .del_gauss(del_gauss),
    .del_gauss_tvalid(del_gauss_valid),
    .del_gauss_tready(fusion_ready_z),
    .del_gauss_tlast(del_gauss_last),
    .fused_frame(fused_frame),
    .fused_frame_tvalid(fused_frame_valid),
    .fused_frame_tready(advance),
    .fused_frame_tlast(fused_frame_last)
);

always @(posedge aclk) begin
    if(~aresetn) begin
        old_fused_buff_4 <= 0;
        old_fused_buff_4_valid <= 0;
        old_fused_buff_4_last <= 0;
    end
    else begin
        if(old_fused_buff_3_valid & new_buff_3_valid & del_gauss_valid & fusion_ready_x & fusion_ready_y & fusion_ready_z) begin
            old_fused_buff_4 <= old_fused_buff_3;
            old_fused_buff_4_valid <= old_fused_buff_3_valid;
            old_fused_buff_4_last <= old_fused_buff_3_last;
        end
        else if(fused_frame_valid & advance) begin
            old_fused_buff_4_valid <= 0;
            old_fused_buff_4_last <= 0;
        end
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        del_buff_2 <= 0;
        del_buff_2_valid <= 0;
        del_buff_2_last <= 0;
    end
    else begin
        if(old_fused_buff_3_valid & new_buff_3_valid & del_gauss_valid & fusion_ready_x & fusion_ready_y & fusion_ready_z) begin
            del_buff_2 <= del_buff_1;
            del_buff_2_valid <= del_buff_1_valid;
            del_buff_2_last <= del_buff_1_last;
        end
        else if(fused_frame_valid & advance) begin
            del_buff_2_valid <= 0;
            del_buff_2_last <= 0;
        end
    end
end

integer i;
always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(advance & old_fused_buff_4_valid & del_buff_2_valid) begin
            for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin
                if(del_buff_2[i*PIXEL_SIZE +: PIXEL_SIZE] == 0) begin
                    m_axis_tdata[i*PIXEL_SIZE +: PIXEL_SIZE] <= old_fused_buff_4[i*PIXEL_SIZE +: PIXEL_SIZE];
                end
                else begin
                    m_axis_tdata[i*PIXEL_SIZE +: PIXEL_SIZE] <= fused_frame[i*PIXEL_SIZE +: PIXEL_SIZE];
                end
            end
            m_axis_tvalid <= 1;
            m_axis_tlast <= (old_fused_buff_4_last & del_buff_2_last);
        end
        else if(m_axis_tvalid & m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end

assign s_axis_old_fused_tready = sob_old_fused_ready & sob_avg_ready & sob_new_ready & s_axis_avg_tvalid & s_axis_new_tvalid; 
assign s_axis_avg_tready = sob_old_fused_ready & sob_avg_ready & sob_new_ready & s_axis_old_fused_tvalid & s_axis_new_tvalid;
assign s_axis_new_tready = sob_old_fused_ready & sob_avg_ready & sob_new_ready & s_axis_old_fused_tvalid & s_axis_avg_tvalid;

endmodule