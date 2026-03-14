`timescale 1ns/10ps

module HSSIM #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
)(
    input clk,
    input aresetn,
    input stall,
    input [DATA_WIDTH-1:0] old_map,
    input [DATA_WIDTH-1:0] avg_map,
    input [DATA_WIDTH-1:0] new_map,

    output reg [8*PIXELS_PER_BEAT-1:0] del
);

/*
Mean and Variance Calculation
Old Edge Map (inp_edge) -> X
Average Edge Map (avg_edge) -> Y
New Edge Map -> Z


variance(signed)  -> 4 cycle dly
mean calc -> 1 cycle dly => delay the result by 3 cycles to sync with co-var output
    (2*muX*muY + c1), (muX^2 + muY^2 + c1) calculation <- divided into 3 stages
*/
localparam CONV_GAUSS_INPUT_WIDTH = 8;  // mean calc
localparam CONV_GAUSS_OUTPUT_WIDTH = 8; // mean calc
localparam MEAN_DATA_WIDTH = 8*PIXELS_PER_BEAT;
localparam c1 = 17'd6;
localparam c2 = 17'd58;
localparam DLY_VAL_MEAN = 2;

// mean and variance calculation
wire [8*PIXELS_PER_BEAT-1:0] out_mu_x;
wire [8*PIXELS_PER_BEAT-1:0] out_mu_y;
wire [8*PIXELS_PER_BEAT-1:0] out_mu_z;

wire [16*PIXELS_PER_BEAT-1:0] out_sig_sq_x;
wire [16*PIXELS_PER_BEAT-1:0] out_sig_sq_y;
wire [16*PIXELS_PER_BEAT-1:0] out_sig_sq_z;
wire [16*PIXELS_PER_BEAT-1:0] out_sig_xy;
wire [16*PIXELS_PER_BEAT-1:0] out_sig_zy;


CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) mu_x (clk, aresetn, stall, old_map, out_mu_x);
CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) mu_y (clk, aresetn, stall, avg_map, out_mu_y);
CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) mu_z (clk, aresetn, stall, new_map, out_mu_z);


SIG_XY #(PIXELS_PER_BEAT, IMAGE_DIM) sig_sq_x (clk, aresetn, stall, old_map, old_map, out_sig_sq_x);    // each co-variance unit is 4 stage pipelned
SIG_XY #(PIXELS_PER_BEAT, IMAGE_DIM) siq_sq_y (clk, aresetn, stall, avg_map, avg_map, out_sig_sq_y);
SIG_XY #(PIXELS_PER_BEAT, IMAGE_DIM) siq_sq_z (clk, aresetn, stall, new_map, new_map, out_sig_sq_z);

SIG_XY #(PIXELS_PER_BEAT, IMAGE_DIM) siq_xy (clk, aresetn, stall, old_map, avg_map, out_sig_xy);
SIG_XY #(PIXELS_PER_BEAT, IMAGE_DIM) siq_zy (clk, aresetn, stall, new_map, avg_map, out_sig_zy);


// stage - 1: muX^2, muY^2, muZ^2, 2*muX*muY, 2*muX*muZ calculation
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muX_muY_times2;
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muZ_muY_times2;
reg [((2*8)*PIXELS_PER_BEAT)-1:0] muX_sq;
reg [((2*8)*PIXELS_PER_BEAT)-1:0] muY_sq;
reg [((2*8)*PIXELS_PER_BEAT)-1:0] muZ_sq;

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            muX_muY_times2[j*17+:17] <= (out_mu_x[j*8+:8] * out_mu_y[j*8+:8])<<1;
            muZ_muY_times2[j*17+:17] <= (out_mu_z[j*8+:8] * out_mu_y[j*8+:8])<<1;

            muX_sq[j*16+:16] <= out_mu_x[j*8+:8] * out_mu_x[j*8+:8];
            muY_sq[j*16+:16] <= out_mu_y[j*8+:8] * out_mu_y[j*8+:8];
            muZ_sq[j*16+:16] <= out_mu_z[j*8+:8] * out_mu_z[j*8+:8];
        end
    end
end
endgenerate


// stage - 2: muX^2 + muY^2, 2*muX*muY, 2*muZ*muY, muZ^2 + muY^2
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muX_muY_times2_dly1;
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muZ_muY_times2_dly1;
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq;
reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] muZ_sq_plus_muY_sq;

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            muX_muY_times2_dly1 <= muX_muY_times2;
            muZ_muY_times2_dly1 <= muZ_muY_times2;

            muX_sq_plus_muY_sq[j*17+:17] <= muX_sq[j*16+:16] + muY_sq[j*16+:16];
            muZ_sq_plus_muY_sq[j*17+:17] <= muZ_sq[j*16+:16] + muY_sq[j*16+:16];
        end
    end
end
endgenerate


// stage - 3, 4: add constant c1 to all the above stage values and delay by 2 cycles till part values are claculted. part 3 calc takes 1 cycle
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] muX_muY_times2_dly1_plus_c1, numr_part_1_x_temp, numr_part_1_x;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] muZ_muY_times2_dly1_plus_c1, numr_part_1_z_temp, numr_part_1_z;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq_plus_c1, denr_part_1_x_temp, denr_part_1_x;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] muZ_sq_plus_muY_sq_plus_c1, denr_part_1_z_temp, denr_part_1_z;

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            muX_muY_times2_dly1_plus_c1[j*18+:18] <= muX_muY_times2_dly1[j*17+:17] + c1;
            numr_part_1_x <= muX_muY_times2_dly1_plus_c1;
            // numr_part_1_x <= numr_part_1_x_temp;

            muZ_muY_times2_dly1_plus_c1[j*18+:18] <= muZ_muY_times2_dly1[j*17+:17] + c1;
            numr_part_1_z <= muZ_muY_times2_dly1_plus_c1;
            // numr_part_1_z <= numr_part_1_z_temp;

            muX_sq_plus_muY_sq_plus_c1[j*18+:18] <= muX_sq_plus_muY_sq[j*17+:17] + c1;
            denr_part_1_x <= muX_sq_plus_muY_sq_plus_c1;
            // denr_part_1_x <= denr_part_1_x_temp;

            muZ_sq_plus_muY_sq_plus_c1[j*18+:18] <= muZ_sq_plus_muY_sq[j*17+:17] + c1;
            denr_part_1_z <= muZ_sq_plus_muY_sq_plus_c1;
            // denr_part_1_z <= denr_part_1_z_temp;
        end
    end
end
endgenerate


// add the constant c2 with variance values and multiply the result with above partial parts calculated (2 cycles)
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] numr_part_2_x;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] numr_part_2_z;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] denr_part_2_x;
reg [((2*8+1+1)*PIXELS_PER_BEAT)-1:0] denr_part_2_z;

reg [(2*(2*8+1+1)*PIXELS_PER_BEAT)-1:0] numr_x;
reg [(2*(2*8+1+1)*PIXELS_PER_BEAT)-1:0] denr_x;
reg [(2*(2*8+1+1)*PIXELS_PER_BEAT)-1:0] numr_z;
reg [(2*(2*8+1+1)*PIXELS_PER_BEAT)-1:0] denr_z;


generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            numr_part_2_x[j*18+:18] <= (out_sig_xy[j*16+:16]<<1) + c2;
            numr_part_2_z[j*18+:18] <= (out_sig_zy[j*16+:16]<<1) + c2;

            denr_part_2_x[j*18+:18] <= (out_sig_sq_x[j*16+:16] + out_sig_sq_y[j*16+:16]) + c2;
            denr_part_2_z[j*18+:18] <= (out_sig_sq_z[j*16+:16] + out_sig_sq_y[j*16+:16]) + c2;

            numr_x[j*36+:36] <= numr_part_1_x[j*18+:18] * numr_part_2_x[j*18+:18];
            numr_z[j*36+:36] <= numr_part_1_z[j*18+:18] * numr_part_2_z[j*18+:18];

            denr_x[j*36+:36] <= denr_part_1_x[j*18+:18] * denr_part_2_x[j*18+:18];
            denr_z[j*36+:36] <= denr_part_1_z[j*18+:18] * denr_part_2_z[j*18+:18];
        end
    end
end
endgenerate


/* 
get products, P1=Nx*Dz and P2=Nz*Dx
    numerator, denominator width -> 36
HSSIM1 (old) = Nx/Dx
HSSIM2 (new) = Nz/Dz
*/
reg [(72*PIXELS_PER_BEAT)-1:0] p1;
reg [(72*PIXELS_PER_BEAT)-1:0] p2;

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            p1[j*72+:72] <= numr_x[j*36+:36] * denr_z[j*36+:36];
            p2[j*72+:72] <= numr_z[j*36+:36] * denr_x[j*36+:36];
        end
    end
end
endgenerate


/* 
compare p1 and p2 to get the selected value (0 or 255)
    del = 255 when p2 > p1 (given both denr have same sign) else 0
*/
reg [PIXELS_PER_BEAT-1:0] comp_val;

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(*) begin
        comp_val[j] = p2[j*72+:72] > p1[j*72+:72];
    end

    always@(posedge clk) begin
        if(~stall) begin
            del[j*8+:8] <= comp_val[j] ? 8'd255 : 8'd0;
        end
    end
end
endgenerate

endmodule