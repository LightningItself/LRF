`timescale 1ns/10ps

module FUSION #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
)(
    input clk,
    input stall,
    input [DATA_WIDTH-1:0] old_frame,
    input [DATA_WIDTH-1:0] new_frame,
    input [DATA_WIDTH-1:0] del_gauss,
    output reg [DATA_WIDTH-1:0] fused_frame
);
wire [8*PIXELS_PER_BEAT-1:0] dbar;
reg [16*PIXELS_PER_BEAT-1:0] x_dbar, y_d;

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    // assign dbar[j*9+:9] = {1'b0, ~del_gauss[j*8+:8]}+9'b1;
    assign dbar[j*8+:8] = ~del_gauss[j*8+:8];

    always@(posedge clk) begin
        if(~stall) begin
            x_dbar[j*16+:16] <= old_frame[j*8+:8] * dbar[j*8+:8];
            y_d[j*16+:16] <= new_frame[j*8+:8] * del_gauss[j*8+:8];
        end
    end
end
endgenerate

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            fused_frame[j*8+:8] <= (x_dbar[j*16+:16] + y_d[j*16+:16])>>8;
        end
    end
end
endgenerate
endmodule