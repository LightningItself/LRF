`timescale 1ns/10ps

module SOBEL_HSSIM_TOP #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE = 8,
    parameter IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    input [DATA_WIDTH-1:0] old_map,
    input                  old_map_valid,
    output                 old_map_ready,
    input                  old_map_last,
    input [DATA_WIDTH-1:0] avg_map,
    input                  avg_map_valid,
    output                 avg_map_ready,
    input                  avg_map_last,
    input [DATA_WIDTH-1:0] new_map,
    input                  new_map_valid,
    output                 new_map_ready,
    input                  new_map_last,
    output reg [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] del,
    output reg              del_valid,
    input                   del_ready,
    output reg              del_last
);

// Wire Declarations

wire advance = (del_ready || ~del_valid);
wire inputs_valid = old_map_valid & avg_map_valid & new_map_valid;

wire [DATA_WIDTH-1:0] old_edge, avg_edge, new_edge;
wire old_edge_valid, old_edge_last, avg_edge_valid, avg_edge_last, new_edge_valid, new_edge_last;
wire sob_old_ready, sob_avg_ready, sob_new_ready;
wire sobs_ready = sob_old_ready & sob_avg_ready & sob_new_ready;

wire [DATA_WIDTH-1:0] del_int;
wire del_int_valid, del_int_last;
wire hssim_ready_x, hssim_ready_y, hssim_ready_z;

// DataPath

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_old(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(old_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(sob_old_ready),
    .s_axis_tlast(old_map_last),
    .m_axis_tdata(old_edge),
    .m_axis_tvalid(old_edge_valid),
    .m_axis_tready(hssim_ready_x),
    .m_axis_tlast(old_edge_last)
);

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_avg(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(avg_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(sob_avg_ready),
    .s_axis_tlast(avg_map_last),
    .m_axis_tdata(avg_edge),
    .m_axis_tvalid(avg_edge_valid),
    .m_axis_tready(hssim_ready_y),
    .m_axis_tlast(avg_edge_last)
);

CONV_SOBEL #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM), .DATA_WIDTH(DATA_WIDTH)) sob_new(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(new_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(sob_new_ready),
    .s_axis_tlast(new_map_last),
    .m_axis_tdata(new_edge),
    .m_axis_tvalid(new_edge_valid),
    .m_axis_tready(hssim_ready_z),
    .m_axis_tlast(new_edge_last)
);

HSSIM_TOP #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) hssim(
    .aclk(aclk),
    .aresetn(aresetn),
    .old_map(old_edge),
    .old_map_valid(old_edge_valid),
    .old_map_ready(hssim_ready_x),
    .old_map_last(old_edge_last),
    .avg_map(avg_edge),
    .avg_map_valid(avg_edge_valid),
    .avg_map_ready(hssim_ready_y),
    .avg_map_last(avg_edge_last),
    .new_map(new_edge),
    .new_map_valid(new_edge_valid),
    .new_map_ready(hssim_ready_z),
    .new_map_last(new_edge_last),
    .del(del_int),
    .del_valid(del_int_valid),
    .del_ready(advance),
    .del_last(del_int_last)
);

always@(posedge aclk) begin
    if(~aresetn) begin
        del <= 0;
        del_valid <= 0;
        del_last <= 0;
    end
    else begin
        if(advance & del_int_valid) begin
            del <= del_int;
            del_valid <= 1;
            del_last <= del_int_last;
        end
        else if(del_valid & del_ready) begin
            del_valid <= 0;
            del_last <= 0;
        end
    end
end

assign old_map_ready = sobs_ready & avg_map_valid & new_map_valid;
assign avg_map_ready = sobs_ready & old_map_valid & new_map_valid;
assign new_map_ready = sobs_ready & old_map_valid & avg_map_valid;

endmodule