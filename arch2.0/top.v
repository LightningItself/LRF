module LRF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
) (
    input wire s_axis_aclk,
    input wire s_axis_aresetn,

    input wire [DATA_WIDTH-1:0] s_axis
)