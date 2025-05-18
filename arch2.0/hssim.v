module HSSIM #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
){
    input clk,
    input aresetn,
    input stall,
    input [DATA_WIDTH-1:0] inp_frame,

    output
};

endmodule