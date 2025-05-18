module SIG_XY #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
){
    input clk,
    input aresetn,
    input stall,
    input [DATA_WIDTH-1:0] in_x,
    input [DATA_WIDTH-1:0] in_y,
    output reg [2*DATA_WIDTH-1:0] out
};

reg [2*DATA_WIDTH-1:0] mult_xy;

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            (* use_dsp = "yes" *) mult_xy[j*16 +:16] <= in_x[j*8 +:8] * in_y[j*8 +:8]
        end
    end      
end
endgenerate



endmodule