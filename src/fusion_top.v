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

wire advance = (m_axis_tready || ~m_axis_tvalid);
wire inputs_valid = s_axis_old_fused_tvalid & s_axis_avg_tvalid & s_axis_new_tvalid;

wire [DATA_WIDTH-1:0] old_fused_buff_1, new_buff_1;
wire old_fused_buff_1_valid, old_fused_buff_1_last, new_buff_1_valid, new_buff_1_last;
wire sob_buff_1_ready, sob_buff_2_ready;

wire [DATA_WIDTH-1:0] edge_old_fused, edge_avg, edge_new;
wire edge_old_fused_valid, edge_old_fused_last, edge_avg_valid, edge_avg_last, edge_new_valid, edge_new_last;
wire sob_old_fused_ready, sob_avg_ready, sob_new_ready;
wire sobels_valid = edge_old_fused_valid & edge_avg_valid & edge_new_valid;

wire [DATA_WIDTH-1:0] del;
wire del_valid, del_last;
wire hssim_ready_x, hssim_ready_y, hssim_ready_z;
wire hssim_ready = hssim_ready_x & hssim_ready_y & hssim_ready_z;

wire [DATA_WIDTH-1:0] old_fused_buff_2, new_buff_2;
wire old_fused_buff_2_valid, old_fused_buff_2_last, new_buff_2_valid, new_buff_2_last;
wire hssim_buff_old_ready, hssim_buff_new_ready;
wire hssim_buffs_ready = hssim_buff_old_ready & hssim_buff_new_ready;

// DataPath

// Sobel_path
// axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(14)) sob_buff_1(
//     .aclk(aclk),
//     .aresetn(aresetn),
//     .s_axis_tdata(s_axis_old_fused_tdata),
//     .s_axis_tvalid(inputs_valid),
//     .s_axis_tready(sob_buff_1_ready),
//     .s_axis_tlast(s_axis_old_fused_tlast),
//     .m_axis_tdata(old_fused_buff_1),
//     .m_axis_tvalid(old_fused_buff_1_valid),
//     .m_axis_tready(hssim_buffs_ready),
//     .m_axis_tlast(old_fused_buff_1_last)
// );

// axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(14)) sob_buff_2(
//     .aclk(aclk),
//     .aresetn(aresetn),
//     .s_axis_tdata(s_axis_new_tdata),
//     .s_axis_tvalid(inputs_valid),
//     .s_axis_tready(sob_buff_2_ready),
//     .s_axis_tlast(s_axis_new_tlast),
//     .m_axis_tdata(new_buff_1),
//     .m_axis_tvalid(new_buff_1_valid),
//     .m_axis_tready(hssim_buffs_ready),
//     .m_axis_tlast(new_buff_1_last)
// );

// CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_old_fused(
//     .aclk(aclk),
//     .aresetn(aresetn),
//     .s_axis_tdata(s_axis_old_fused_tdata),
//     .s_axis_tvalid(inputs_valid),
//     .s_axis_tready(sob_old_fused_ready),
//     .s_axis_tlast(s_axis_old_fused_tlast),
//     .m_axis_tdata(edge_old_fused),
//     .m_axis_tvalid(edge_old_fused_valid),
//     .m_axis_tready(hssim_ready),
//     .m_axis_tlast(edge_old_fused_last)
// );

// CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_avg(
//     .aclk(aclk),
//     .aresetn(aresetn),
//     .s_axis_tdata(s_axis_avg_tdata),
//     .s_axis_tvalid(inputs_valid),
//     .s_axis_tready(sob_avg_ready),
//     .s_axis_tlast(s_axis_avg_tlast),
//     .m_axis_tdata(edge_avg),
//     .m_axis_tvalid(edge_avg_valid),
//     .m_axis_tready(hssim_ready),
//     .m_axis_tlast(edge_avg_last)
// );

// CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_new(
//     .aclk(aclk),
//     .aresetn(aresetn),
//     .s_axis_tdata(s_axis_new_tdata),
//     .s_axis_tvalid(inputs_valid),
//     .s_axis_tready(sob_new_ready),
//     .s_axis_tlast(s_axis_new_tlast),
//     .m_axis_tdata(edge_new),
//     .m_axis_tvalid(edge_new_valid),
//     .m_axis_tready(hssim_ready),
//     .m_axis_tlast(edge_new_last)
// );


// hssim_top path

HSSIM_TOP #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) hssim(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_map(s_axis_old_fused_tdata),
    .old_map_valid(inputs_valid),
    .old_map_ready(hssim_ready_x),
    .old_map_last(s_axis_old_fused_tlast),
    .avg_map(s_axis_avg_tdata),
    .avg_map_valid(inputs_valid),
    .avg_map_ready(hssim_ready_y),
    .avg_map_last(s_axis_avg_tlast),
    .new_map(s_axis_new_tdata),
    .new_map_valid(inputs_valid),
    .new_map_ready(hssim_ready_z),
    .new_map_last(s_axis_new_tlast),
    .del(del),
    .del_valid(del_valid),
    .del_ready(advance),
    .del_last(del_last)
);
axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(10)) hssim_buff_old(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_old_fused_tdata),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(hssim_buff_old_ready),
    .s_axis_tlast(s_axis_old_fused_tlast),
    .m_axis_tdata(old_fused_buff_2),
    .m_axis_tvalid(old_fused_buff_2_valid),
    .m_axis_tready(advance),
    .m_axis_tlast(old_fused_buff_2_last)
);

axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(10)) hssim_buff_new(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_new_tdata),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(hssim_buff_new_ready),
    .s_axis_tlast(s_axis_new_tlast),
    .m_axis_tdata(new_buff_2),
    .m_axis_tvalid(new_buff_2_valid),
    .m_axis_tready(advance),
    .m_axis_tlast(new_buff_2_last)
);

// output stage
always@(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(advance & del_valid & new_buff_2_valid & old_fused_buff_2_valid) begin
            m_axis_tdata <= (del);
            m_axis_tvalid <= (new_buff_2_valid);
            m_axis_tlast <= (new_buff_2_last & del_last);
        end
        else if (m_axis_tvalid & m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end

assign s_axis_old_fused_tready = hssim_buffs_ready & hssim_ready & s_axis_avg_tvalid & s_axis_new_tvalid;
assign s_axis_avg_tready = hssim_buffs_ready & hssim_ready & s_axis_new_tvalid & s_axis_old_fused_tvalid;
assign s_axis_new_tready = hssim_buffs_ready & hssim_ready & s_axis_old_fused_tvalid & s_axis_avg_tvalid;

endmodule