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

// DataPath

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
    .del_ready(advance),
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
    .m_axis_tready(advance & del_valid),
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
    .m_axis_tready(advance & del_valid),
    .m_axis_tlast(new_fifo_out_last)
);

always @(posedge aclk) begin
    if(!aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(advance & del_valid & old_fifo_out_valid & new_fifo_out_valid) begin
            m_axis_tdata <= del;
            m_axis_tvalid <= 1;
            m_axis_tlast <= (del_last & old_fifo_out_last & new_fifo_out_last);
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