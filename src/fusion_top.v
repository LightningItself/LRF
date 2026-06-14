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

wire inputs_valid = s_axis_old_fused_tvalid & s_axis_avg_tvalid & s_axis_new_tvalid; 

wire [DATA_WIDTH-1:0] del;
wire del_valid, del_last, sob_hssim_ready_x, sob_hssim_ready_y, sob_hssim_ready_z;
wire old_hssim_ready = sob_hssim_ready_x & sob_hssim_ready_y & sob_hssim_ready_z;

wire [DATA_WIDTH-1:0] old_buff_1, new_buff_1;
wire old_buff_1_valid, old_buff_1_last, old_buff_1_ready, new_buff_1_valid, new_buff_1_last, new_buff_1_ready;
wire buffs_1_ready = old_buff_1_ready & new_buff_1_ready;

// DataPath

SOBEL_HSSIM_TOP #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) sob_hssim(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_map(s_axis_old_fused_tdata),
    .old_map_valid(s_axis_old_fused_tvalid),
    .old_map_ready(sob_hssim_ready_x),
    .old_map_last(s_axis_old_fused_tlast),
    .avg_map(s_axis_avg_tdata),
    .avg_map_valid(s_axis_avg_tvalid),
    .avg_map_ready(sob_hssim_ready_y),
    .avg_map_last(s_axis_avg_tlast),
    .new_map(s_axis_new_tdata),
    .new_map_valid(s_axis_new_tvalid),
    .new_map_ready(sob_hssim_ready_z),
    .new_map_last(s_axis_new_tlast),
    .del(del),
    .del_valid(del_valid),
    .del_ready(advance),
    .del_last(del_last)
);

axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(26)) old_axisbuff_1(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_old_fused_tdata),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(old_buff_1_ready),
    .s_axis_tlast(s_axis_old_fused_tlast),
    .m_axis_tdata(old_buff_1),
    .m_axis_tvalid(old_buff_1_valid),
    .m_axis_tready(advance),
    .m_axis_tlast(old_buff_1_last)
);

axis_buff_depth #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH), .DEPTH(26)) new_axis_buff_2(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_new_tdata),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(new_buff_1_ready),
    .s_axis_tlast(s_axis_new_tlast),
    .m_axis_tdata(new_buff_1),
    .m_axis_tvalid(new_buff_1_valid),
    .m_axis_tready(advance),
    .m_axis_tlast(new_buff_1_last)
);

always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(del_valid & old_buff_1_valid & new_buff_1_valid & advance) begin
            m_axis_tdata <= (del & old_buff_1 & new_buff_1);
            m_axis_tvalid <= 1;
            m_axis_tlast <= (del_last & old_buff_1_last & new_buff_1_last);
        end
        else if(m_axis_tready & m_axis_tvalid) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end
    end
end

assign s_axis_old_fused_tready = old_hssim_ready & buffs_1_ready & s_axis_avg_tvalid & s_axis_new_tvalid;
assign s_axis_avg_tready = old_hssim_ready & buffs_1_ready & s_axis_old_fused_tvalid & s_axis_new_tvalid;
assign s_axis_new_tready = old_hssim_ready & buffs_1_ready & s_axis_old_fused_tvalid & s_axis_avg_tvalid;

endmodule