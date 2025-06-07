`timescale 1ns/10ps

module SIG_XY #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
)(
    input clk,
    input aresetn,
    input stall,
    input [DATA_WIDTH-1:0] in_x,
    input [DATA_WIDTH-1:0] in_y,
    output reg signed [2*DATA_WIDTH-1:0] out
);


// mean-x and mean-y calculation
wire [DATA_WIDTH-1:0] mu_x, mu_y;

CONV_GAUSS #(PIXELS_PER_BEAT, 8, IMAGE_DIM) mean_x (clk, aresetn, stall, in_x, mu_x);
CONV_GAUSS #(PIXELS_PER_BEAT, 8, IMAGE_DIM) mean_y (clk, aresetn, stall, in_y, mu_y);


// multiply x and y
reg [2*DATA_WIDTH-1:0] mult_xy, mu_x_mu_y;

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            mult_xy[j*16 +:16] <= in_x[j*8 +:8] * in_y[j*8 +:8];
            mu_x_mu_y[j*16 +:16] <= mu_x[j*8 +:8] * mu_y[j*8 +:8];
        end
    end      
end
endgenerate

localparam CONV_GAUSS_INPUT_WIDTH = 16;  // XY bit width is 16

wire [CONV_GAUSS_INPUT_WIDTH*PIXELS_PER_BEAT-1:0] out_gauss_xy;
reg aresetn_d1;
always @(posedge clk) begin
    if(~stall)
        aresetn_d1 <= aresetn;
end
CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) gauss_xy (clk, aresetn_d1, stall, mult_xy, out_gauss_xy);

// difference
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            out[j*16 +:16] <= out_gauss_xy[j*16 +:16] - mu_x_mu_y[j*16 +:16];
        end
    end      
end
endgenerate

endmodule