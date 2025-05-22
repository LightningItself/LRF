// 4 stage pipelined

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

reg [2*DATA_WIDTH-1:0] mult_xy, mult_xy_dly1, mult_xy_dly2;

// multiply x and y
genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            mult_xy[j*16 +:16] <= in_x[j*8 +:8] * in_y[j*8 +:8];
            mult_xy_dly1 <= mult_xy;
            mult_xy_dly2 <= mult_xy_dly1;   // multiplied value de;ayed by 2 cyc;es before comparision with gaussian output
        end
    end      
end
endgenerate

localparam CONV_GAUSS_INPUT_WIDTH = 16;  // XY bit width is 16

wire [CONV_GAUSS_INPUT_WIDTH*PIXELS_PER_BEAT-1:0] out_gauss_xy;
reg aresetn_d1;
always @(posedge clk) begin
    aresetn_d1 <= aresetn;
end
CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) gauss_xy (clk, aresetn_d1, stall, mult_xy, out_gauss_xy);

// difference
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            out[j*16 +:16] <= out_gauss_xy[j*8 +:8] - mult_xy_dly2[j*8 +:8];
        end
    end      
end
endgenerate

endmodule