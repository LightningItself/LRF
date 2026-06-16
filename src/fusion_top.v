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
wire hssim_ready = sob_hssim_ready_x & sob_hssim_ready_y & sob_hssim_ready_z;

wire [DATA_WIDTH-1:0] old_fifo_out, new_fifo_out;
wire old_fifo_ready, old_fifo_out_valid, old_fifo_out_last, new_fifo_ready, new_fifo_out_valid, new_fifo_out_last;
wire fifos_ready = old_fifo_ready & new_fifo_ready;

wire [DATA_WIDTH-1:0] gauss_del;
wire gauss_ready, gauss_del_valid, gauss_del_last;

reg [DATA_WIDTH-1:0] old_gauss_buff, new_gauss_buff;
reg old_gauss_buff_valid, old_gauss_buff_last, new_gauss_buff_valid, new_gauss_buff_last;

// DataPath

// sobel_hssim_top part

SOBEL_HSSIM_TOP #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) sob_hssim(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_map(s_axis_old_fused_tdata),
    .old_map_valid(inputs_valid & fifos_ready),
    .old_map_ready(sob_hssim_ready_x),
    .old_map_last(s_axis_old_fused_tlast),
    .avg_map(s_axis_avg_tdata),
    .avg_map_valid(inputs_valid & fifos_ready),
    .avg_map_ready(sob_hssim_ready_y),
    .avg_map_last(s_axis_avg_tlast),
    .new_map(s_axis_new_tdata),
    .new_map_valid(inputs_valid & fifos_ready),
    .new_map_ready(sob_hssim_ready_z),
    .new_map_last(s_axis_new_tlast),
    .del(del),
    .del_valid(del_valid),
    .del_ready(gauss_ready),
    .del_last(del_last)
);

axis_data_fifo_0 old_fifo (
    .s_axis_aclk(aclk), 
    .s_axis_aresetn(aresetn),
    .s_axis_tdata(s_axis_old_fused_tdata),        
    .s_axis_tvalid(inputs_valid & hssim_ready),    
    .s_axis_tready(old_fifo_ready),      
    .s_axis_tlast(s_axis_old_fused_tlast),
    .m_axis_tdata(old_fifo_out),
    .m_axis_tvalid(old_fifo_out_valid),
    .m_axis_tready(gauss_ready & del_valid),
    .m_axis_tlast(old_fifo_out_last)
);

axis_data_fifo_0 new_fifo (
    .s_axis_aclk(aclk), 
    .s_axis_aresetn(aresetn),
    .s_axis_tdata(s_axis_new_tdata),        
    .s_axis_tvalid(inputs_valid & hssim_ready),    
    .s_axis_tready(new_fifo_ready),      
    .s_axis_tlast(s_axis_new_tlast),
    .m_axis_tdata(new_fifo_out),
    .m_axis_tvalid(new_fifo_out_valid),
    .m_axis_tready(gauss_ready & del_valid),
    .m_axis_tlast(new_fifo_out_last)
);

// gauss part

CONV_GAUSS #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(del),
    .s_axis_tvalid(del_valid),
    .s_axis_tready(gauss_ready),
    .s_axis_tlast(del_last),
    .m_axis_tdata(gauss_del),
    .m_axis_tvalid(gauss_del_valid),
    .m_axis_tready(fusion_ready_x & buff_ready_x),
    .m_axis_tlast(gauss_del_last)
);

always @(posedge aclk) begin
    if(!aresetn) begin
        old_gauss_buff <= 0;
        new_gauss_buff <= 0;
        old_gauss_buff_valid <= 0;
        old_gauss_buff_last <= 0;
        new_gauss_buff_valid <= 0;
        new_gauss_buff_last <= 0;
    end
    else begin
        if(gauss_ready & del_valid & old_fifo_out_valid & new_fifo_out_valid) begin
            old_gauss_buff <= old_fifo_out;
            new_gauss_buff <= new_fifo_out;
            old_gauss_buff_valid <= 1;
            old_gauss_buff_last <= old_fifo_out_last;
            new_gauss_buff_valid <= 1;
            new_gauss_buff_last <= new_fifo_out_last;
        end
        else if(fusion_ready_x & buff_ready_x & gauss_del_valid) begin
            old_gauss_buff_valid <= 0;
            old_gauss_buff_last <= 0;
            new_gauss_buff_valid <= 0;
            new_gauss_buff_last <= 0;
        end
    end
end

// fusion part

wire [DATA_WIDTH-1:0] fusion_out;
wire fusion_ready_x, fusion_ready_y, fusion_ready_z, fusion_out_valid, fusion_out_last;

FUSION #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .PIXEL_SIZE(PIXEL_SIZE)) fusion(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_frame(old_gauss_buff),
    .old_frame_tvalid(old_gauss_buff_valid),
    .old_frame_tready(fusion_ready_x),
    .old_frame_tlast(old_gauss_buff_last),
    .new_frame(new_gauss_buff),
    .new_frame_tvalid(new_gauss_buff_valid),
    .new_frame_tready(fusion_ready_y),
    .new_frame_tlast(new_gauss_buff_last),
    .del_gauss(gauss_del),
    .del_gauss_tvalid(gauss_del_valid),
    .del_gauss_tready(fusion_ready_z),
    .del_gauss_tlast(gauss_del_last),
    .fused_frame(fusion_out),
    .fused_frame_tvalid(fusion_out_valid),
    .fused_frame_tready(advance),
    .fused_frame_tlast(fusion_out_last)
);

wire [DATA_WIDTH-1:0] old_fusion_buff;
wire old_fusion_buff_valid, old_fusion_buff_last, buff_ready_x, buff_ready_y, buff_ready_z;

FUSION #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .IMAGE_DIM(IMAGE_DIM), .PIXEL_SIZE(PIXEL_SIZE)) buff(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_frame(old_gauss_buff),
    .old_frame_tvalid(old_gauss_buff_valid),
    .old_frame_tready(buff_ready_x),
    .old_frame_tlast(old_gauss_buff_last),
    .new_frame(0),
    .new_frame_tvalid(1),
    .new_frame_tready(buff_ready_y),
    .new_frame_tlast(1),
    .del_gauss(0),
    .del_gauss_tvalid(1),
    .del_gauss_tready(buff_ready_z),
    .del_gauss_tlast(1),
    .fused_frame(old_fusion_buff),
    .fused_frame_tvalid(old_fusion_buff_valid),
    .fused_frame_tready(advance),
    .fused_frame_tlast(old_fusion_buff_last)
);

always @(posedge aclk) begin
    if(!aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(advance & fusion_out_valid & old_fusion_buff_valid) begin
            m_axis_tdata <= fusion_out;
            m_axis_tvalid <= 1;
            m_axis_tlast <= (fusion_out_last & old_fusion_buff_last);
        end
        else if(m_axis_tvalid & m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end 
    end
end

assign s_axis_old_fused_tready = fifos_ready & hssim_ready & s_axis_avg_tvalid & s_axis_new_tvalid;
assign s_axis_avg_tready = fifos_ready & hssim_ready & s_axis_old_fused_tvalid & s_axis_new_tvalid; 
assign s_axis_new_tready = fifos_ready & hssim_ready & s_axis_old_fused_tvalid & s_axis_avg_tvalid; 

endmodule