module HSSIM #(
    parameter PIXELS_PER_BEAT = 16,
    parameter INPUT_WIDTH = 8,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = INPUT_WIDTH*PIXELS_PER_BEAT,

    parameter NUMR_BIT_WIDTH = 36,
    parameter DENR_BIT_WIDTH = 36,
    parameter NUMR_WIDTH = NUMR_BIT_WIDTH*PIXELS_PER_BEAT,
    parameter DENR_WIDTH = DENR_BIT_WIDTH*PIXELS_PER_BEAT
){
    input clk,
    input aresetn,
    input stall,
    input [DATA_WIDTH-1:0] inp_frame,
    input [DATA_WIDTH-1:0] ref_frame,

    output reg signed [NUMR_WIDTH-1:0] numr_out,
    output reg signed [DENR_WIDTH-1:0] denr_out
};


// edge map calculation
CONV_SOBEL #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) inp_edge (clk, aresetn, stall, inp_frame, inp_edge);
CONV_SOBEL #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) ref_edge (clk, aresetn, stall, ref_frame, ref_edge);

/*
Mean and Variance Calculation
Input Edge Map (inp_edge) -> X
Refernce Edge Map (ref_edge) -> Y

mean calc -> 1 cycle dly => delay the result by 2 cycles
variance(signed)  -> 3 cycle dly
*/

localparam c1 = 6;
localparam c2 = 58;

localparam DLY_VAL_MEAN = 2;

localparam DLY_VAL_MEAN = 2;


reg [CONV_GAUSS_OUTPUT_WIDTH-1:0] out_mu_x_dly [0:DLY_VAL_MEAN-1];
integer i;

always @(posedge clk or negedge aresetn) begin
    if (!aresetn) begin
        for (i = 0; i < DLY_VAL_MEAN; i = i + 1) begin
            out_mu_x_dly[i] <= 0;
        end
    end else if (!stall) begin
        out_mu_x_dly[0] <= out_mu_x;
        for (i = 1; i < DLY_VAL_MEAN; i = i + 1) begin
            out_mu_x_dly[i] <= out_mu_x_dly[i-1];
        end
    end
end

// Delayed output
wire [CONV_GAUSS_OUTPUT_WIDTH-1:0] out_mu_x_delayed;
assign out_mu_x_delayed = out_mu_x_dly[DLY_VAL_MEAN-1];

CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) mu_x (clk, aresetn, stall, inp_edge, out_mu_x);
CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) mu_y (clk, aresetn, stall, ref_edge, out_mu_y);

SIG_XY #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) sig_sq_x (clk, aresetn, stall, inp_edge, inp_edge, out_sig_sq_x);
SIG_XY #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) siq_sq_y (clk, aresetn, stall, ref_edge, ref_edge, out_siq_sq_y);

SIG_XY #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) siq_xy (clk, aresetn, stall, inp_edge, ref_edge, out_sig_xy);



endmodule