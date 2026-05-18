`timescale 1ns/10ps

module HSSIM #(
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

/*
Mean and Variance Calculation
Old Edge Map (inp_edge) -> X
Average Edge Map (avg_edge) -> Y
New Edge Map -> Z


variance(signed)  -> 4 cycle dly
mean calc -> 1 cycle dly => delay the result by 3 cycles to sync with co-var output
so we just pipeline the mean calculations stage by stage
    (2*muX*muY + c1), (muX^2 + muY^2 + c1) calculation <- divided into 3 stages
*/

localparam c1 = 17'd6;
localparam c2 = 17'd58;

// WIRE DECLARATIONS

wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_old;
wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_avg;
wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_new;
wire out_mu_old_valid, gauss_old_map_ready, out_mu_old_last;
wire out_mu_avg_valid, gauss_avg_map_ready, out_mu_avg_last;
wire out_mu_new_valid, gauss_new_map_ready, out_mu_new_last;

wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_sq_x;
wire out_sig_sq_x_valid, out_sig_sq_x_ready_x, out_sig_sq_x_ready_y, out_sig_sq_x_last;
wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_sq_y;
wire out_sig_sq_y_valid, out_sig_sq_y_ready_x, out_sig_sq_y_ready_y, out_sig_sq_y_last;
wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_sq_z;
wire out_sig_sq_z_valid, out_sig_sq_z_ready_x, out_sig_sq_z_ready_y, out_sig_sq_z_last;
wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_xy;
wire out_sig_xy_valid, out_sig_xy_ready_x, out_sig_xy_ready_y, out_sig_xy_last;
wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_zy;
wire out_sig_zy_valid, out_sig_zy_ready_x, out_sig_zy_ready_y, out_sig_zy_last;

wire [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] muX_muY;
wire [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] muZ_muY;
wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muX_muY_times2 = (muX_muY << 1);
wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muZ_muY_times2 = (muZ_muY << 1);
wire [((2*PIXEL_SIZE)*PIXELS_PER_BEAT)-1:0] muX_sq;
wire [((2*PIXEL_SIZE)*PIXELS_PER_BEAT)-1:0] muY_sq;
wire [((2*PIXEL_SIZE)*PIXELS_PER_BEAT)-1:0] muZ_sq;
wire [PIXELS_PER_BEAT-1:0] mul_old_sq_ready_1, mul_old_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] mul_avg_sq_ready_1, mul_avg_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] mul_new_sq_ready_1, mul_new_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] mul_old_avg_sq_ready_1, mul_old_avg_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] mul_avg_new_sq_ready_1, mul_avg_new_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] muX_sq_val, muY_sq_val, muZ_sq_val, muX_muY_times2_val, muZ_muY_times2_val;
wire [PIXELS_PER_BEAT-1:0] muX_sq_la, muY_sq_la, muZ_sq_la, muX_muY_times2_la, muZ_muY_times2_la;
wire muX_sq_valid = &muX_sq_val;
wire muY_sq_valid = &muY_sq_val;
wire muZ_sq_valid = &muZ_sq_val;
wire muX_muY_times2_valid = &muX_muY_times2_val;
wire muZ_muY_times2_valid = &muZ_muY_times2_val;
wire muX_sq_last = &muX_sq_la;
wire muY_sq_last = &muY_sq_la;
wire muZ_sq_last = &muZ_sq_la;
wire muX_muY_times2_last = &muX_muY_times2_la;
wire muZ_muY_times2_last = &muZ_muY_times2_la;
wire mult_old_sq_ready_x = &mul_old_sq_ready_1;
wire mult_old_sq_ready_y = &mul_old_sq_ready_2;
wire mult_avg_sq_ready_x = &mul_avg_sq_ready_1;
wire mult_avg_sq_ready_y = &mul_avg_sq_ready_2;
wire mult_new_sq_ready_x = &mul_new_sq_ready_1;
wire mult_new_sq_ready_y = &mul_new_sq_ready_2;
wire mult_old_avg_sq_ready_x = &mul_old_avg_sq_ready_1;
wire mult_old_avg_sq_ready_y = &mul_old_avg_sq_ready_2;
wire mult_avg_new_sq_ready_x = &mul_avg_new_sq_ready_1;
wire mult_avg_new_sq_ready_y = &mul_avg_new_sq_ready_2;
wire all_mult_ready = mult_old_sq_ready_x & mult_old_sq_ready_y & mult_avg_sq_ready_x & mult_avg_sq_ready_y & mult_new_sq_ready_x & mult_new_sq_ready_y & mult_old_avg_sq_ready_x & mult_old_avg_sq_ready_y & mult_avg_new_sq_ready_x & mult_avg_new_sq_ready_y;

wire [((2*8+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq;
wire [((2*8+1)*PIXELS_PER_BEAT)-1:0] muZ_sq_plus_muY_sq;
wire muX_sq_plus_muY_sq_ready_1, muX_sq_plus_muY_sq_ready_2;
wire muZ_sq_plus_muY_sq_ready_1, muZ_sq_plus_muY_sq_ready_2;
wire muX_sq_plus_muY_sq_ready = muX_sq_plus_muY_sq_ready_1 & muX_sq_plus_muY_sq_ready_2;
wire muZ_sq_plus_muY_sq_ready = muZ_sq_plus_muY_sq_ready_1 & muZ_sq_plus_muY_sq_ready_2;
wire adders_ready_stage_2 = muX_sq_plus_muY_sq_ready & muZ_sq_plus_muY_sq_ready;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_val, muZ_sq_plus_muY_sq_val;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_la, muZ_sq_plus_muY_sq_la;
wire muX_sq_plus_muY_sq_valid = &muX_sq_plus_muY_sq_val;
wire muZ_sq_plus_muY_sq_valid = &muZ_sq_plus_muY_sq_val;
wire muX_sq_plus_muY_sq_last = &muX_sq_plus_muY_sq_la;
wire muZ_sq_plus_muY_sq_last = &muZ_sq_plus_muY_sq_la;

wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_z;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_1_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_1_z;
wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_val, numr_part_1_z_val, denr_part_1_x_val, denr_part_1_z_val;
wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_la, numr_part_1_z_la, denr_part_1_x_last, denr_part_1_z_last;
wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_x, muZ_muY_times2_plus_c1_ready_x, muX_sq_plus_muY_sq_plus_c1_ready_x, muZ_sq_plus_muY_sq_plus_c1_ready_x;
wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_y, muZ_muY_times2_plus_c1_ready_y, muX_sq_plus_muY_sq_plus_c1_ready_y, muZ_sq_plus_muY_sq_plus_c1_ready_y;
wire muX_muY_times2_plus_c1_ready = ((&muX_muY_times2_plus_c1_ready_x) & (&muX_muY_times2_plus_c1_ready_y));
wire muZ_muY_times2_plus_c1_ready = ((&muZ_muY_times2_plus_c1_ready_x) & (&muZ_muY_times2_plus_c1_ready_y));
wire muX_sq_plus_muY_sq_plus_c1_ready = ((&muX_sq_plus_muY_sq_plus_c1_ready_x) & (&muX_sq_plus_muY_sq_plus_c1_ready_y));
wire muZ_sq_plus_muY_sq_plus_c1_ready = ((&muZ_sq_plus_muY_sq_plus_c1_ready_x) & (&muZ_sq_plus_muY_sq_plus_c1_ready_y));
wire adders_ready_stage_3 = muX_muY_times2_plus_c1_ready & muZ_muY_times2_plus_c1_ready & muX_sq_plus_muY_sq_plus_c1_ready & muZ_sq_plus_muY_sq_plus_c1_ready;
wire numr_part_1_x_valid = &numr_part_1_x_val;
wire numr_part_1_z_valid = &numr_part_1_z_val;
wire denr_part_1_x_valid = &denr_part_1_x_val;
wire denr_part_1_z_valid = &denr_part_1_z_val;
wire numr_part_1_x_last = &numr_part_1_x_la;
wire numr_part_1_z_last = &numr_part_1_z_la;
wire denr_part_1_x_last = &denr_part_1_x_last;
wire denr_part_1_z_last = &denr_part_1_z_last;

// DATAPATH

CONV_GAUSS #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss_old_map(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(old_map),
    .s_axis_tvalid(old_map_valid),
    .s_axis_tready(gauss_old_map_ready),
    .s_axis_tlast(old_map_last),
    .m_axis_tdata(out_mu_old),
    .m_axis_tvalid(out_mu_old_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_old_last)
);

CONV_GAUSS #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss_avg_map(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(avg_map),
    .s_axis_tvalid(avg_map_valid),
    .s_axis_tready(gauss_avg_map_ready),
    .s_axis_tlast(avg_map_last),
    .m_axis_tdata(out_mu_avg),
    .m_axis_tvalid(out_mu_avg_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_avg_last)
);

CONV_GAUSS #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss_new_map(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(new_map),
    .s_axis_tvalid(new_map_valid),
    .s_axis_tready(gauss_new_map_ready),
    .s_axis_tlast(new_map_last),
    .m_axis_tdata(out_mu_new),
    .m_axis_tvalid(out_mu_new_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_new_last)
);

SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT),.PIXEL_SIZE(PIXEL_SIZE),.IMAGE_DIM(IMAGE_DIM)) sig_sq_x(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(old_map),
    .s_axis_tvalid_x(old_map_valid),
    .s_axis_tready_x(out_sig_sq_x_ready_x),
    .s_axis_tlast_x(old_map_last),
    .s_axis_tdata_y(old_map),
    .s_axis_tvalid_y(old_map_valid),
    .s_axis_tready_y(out_sig_sq_x_ready_y),
    .s_axis_tlast_y(old_map_last),
    .m_axis_tdata(out_sig_sq_x),
    .m_axis_tvalid(out_sig_sq_x_valid),
    .m_axis_tready(),
    .m_axis_tlast(out_sig_sq_x_last)
);

SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT),.PIXEL_SIZE(PIXEL_SIZE),.IMAGE_DIM(IMAGE_DIM)) sig_sq_y(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(avg_map),
    .s_axis_tvalid_x(avg_map_valid),
    .s_axis_tready_x(out_sig_sq_y_ready_x),
    .s_axis_tlast_x(avg_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(avg_map_valid),
    .s_axis_tready_y(out_sig_sq_y_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_sq_y),
    .m_axis_tvalid(out_sig_sq_y_valid),
    .m_axis_tready(),
    .m_axis_tlast(out_sig_sq_y_last)
);

SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT),.PIXEL_SIZE(PIXEL_SIZE),.IMAGE_DIM(IMAGE_DIM)) sig_sq_z(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(new_map),
    .s_axis_tvalid_x(new_map_valid),
    .s_axis_tready_x(out_sig_sq_z_ready_x),
    .s_axis_tlast_x(new_map_last),
    .s_axis_tdata_y(new_map),
    .s_axis_tvalid_y(new_map_valid),
    .s_axis_tready_y(out_sig_sq_z_ready_y),
    .s_axis_tlast_y(new_map_last),
    .m_axis_tdata(out_sig_sq_z),
    .m_axis_tvalid(out_sig_sq_z_valid),
    .m_axis_tready(),
    .m_axis_tlast(out_sig_sq_z_last)
);

SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT),.PIXEL_SIZE(PIXEL_SIZE),.IMAGE_DIM(IMAGE_DIM)) sig_xy(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(old_map),
    .s_axis_tvalid_x(old_map_valid),
    .s_axis_tready_x(out_sig_xy_ready_x),
    .s_axis_tlast_x(old_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(avg_map_valid),
    .s_axis_tready_y(out_sig_xy_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_xy),
    .m_axis_tvalid(out_sig_xy_valid),
    .m_axis_tready(),
    .m_axis_tlast(out_sig_xy_last)
);

SIG_XY #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT),.PIXEL_SIZE(PIXEL_SIZE),.IMAGE_DIM(IMAGE_DIM)) sig_zy(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(new_map),
    .s_axis_tvalid_x(new_map_valid),
    .s_axis_tready_x(out_sig_zy_ready_x),
    .s_axis_tlast_x(new_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(avg_map_valid),
    .s_axis_tready_y(out_sig_zy_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_zy),
    .m_axis_tvalid(out_sig_zy_valid),
    .m_axis_tready(),
    .m_axis_tlast(out_sig_zy_last)
);


// stage - 1: muX^2, muY^2, muZ^2, 2*muX*muY, 2*muX*muZ calculation

genvar j;
generate 
    for(j=0;j<PIXELS_PER_BEAT;j=j+1) begin
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_old_sq (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(out_mu_old_valid),
            .s_axis_tready_x(mul_old_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_old_last),
            .s_axis_tdata_y(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(out_mu_old_valid),
            .s_axis_tready_y(mul_old_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_old_last),
            .m_axis_tdata(muX_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muX_sq_la[j])
        );
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_avg_sq (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(out_mu_avg_valid),
            .s_axis_tready_x(mul_avg_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_avg_last),
            .s_axis_tdata_y(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(out_mu_avg_valid),
            .s_axis_tready_y(mul_avg_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_avg_last),
            .m_axis_tdata(muY_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muY_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muY_sq_la[j])
        );
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_new_sq (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(out_mu_new_valid),
            .s_axis_tready_x(mul_new_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_new_last),
            .s_axis_tdata_y(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(out_mu_new_valid),
            .s_axis_tready_y(mul_new_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_new_last),
            .m_axis_tdata(muZ_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muZ_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muZ_sq_la[j])
        );
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_old_avg_sq (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(out_mu_old_valid),
            .s_axis_tready_x(mul_old_avg_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_old_last),
            .s_axis_tdata_y(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(out_mu_avg_valid),
            .s_axis_tready_y(mul_old_avg_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_old_last),
            .m_axis_tdata(muX_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_muY_times2_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muX_muY_times2_la[j])
        );
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_avg_new_sq (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(out_mu_avg_valid),
            .s_axis_tready_x(mul_avg_new_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_old_last),
            .s_axis_tdata_y(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(out_mu_new_valid),
            .s_axis_tready_y(mul_avg_new_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_new_last),
            .m_axis_tdata(muZ_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muZ_muY_times2_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muZ_muY_times2_la[j])
        );
    end
endgenerate

// stage - 2: muX^2 + muY^2, muZ^2 + muY^2

genvar k;
generate 
    for(k=0;k<PIXELS_PER_BEAT;k=k+1) begin
        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muX_sq_plus_muY_sq(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_x(muX_sq_valid),
            .s_axis_tready_x(muX_sq_plus_muY_sq_ready_1[k]),
            .s_axis_tlast_x(muX_sq_last),
            .s_axis_tdata_y(muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_y(muY_sq_valid),
            .s_axis_tready_y(muX_sq_plus_muY_sq_ready_2[k]),
            .s_axis_tlast_y(muY_sq_last),
            .m_axis_tdata(muX_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .m_axis_tvalid(muX_sq_plus_muY_sq_val[k]),
            .m_axis_tready(adders_ready_stage_3),
            .m_axis_tlast(muX_sq_plus_muY_sq_la[k])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muZ_sq_plus_muY_sq(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muZ_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_x(muZ_sq_valid),
            .s_axis_tready_x(muZ_sq_plus_muY_sq_ready_1[k]),
            .s_axis_tlast_x(muZ_sq_last),
            .s_axis_tdata_y(muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_y(muY_sq_valid),
            .s_axis_tready_y(muZ_sq_plus_muY_sq_ready_2[k]),
            .s_axis_tlast_y(muY_sq_last),
            .m_axis_tdata(muZ_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .m_axis_tvalid(muZ_sq_plus_muY_sq_val[k]),
            .m_axis_tready(adders_ready_stage_3),
            .m_axis_tlast(muZ_sq_plus_muY_sq_la[k])
        );
    end
endgenerate

// stage - 3: (2*muX*muY + c1), (2*muZ*muY + c1), (muX^2 + muY^2 + c1), (muZ^2 + muY^2 + c1)

genvar l;
generate
    for(l=0; l<PIXELS_PER_BEAT; l=l+1) begin
        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) muX_muY_times2_plus_c1(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_muY_times2[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(muX_muY_times2_valid),
            .s_axis_tready_x(muX_muY_times2_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muX_muY_times2_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b0),
            .s_axis_tready_y(muX_muY_times2_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(numr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(numr_part_1_x_val[l]),
            .m_axis_tready(),
            .m_axis_tlast(numr_part_1_x_la[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) muZ_muY_times2_plus_c1(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muZ_muY_times2[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(muZ_muY_times2_valid),
            .s_axis_tready_x(muZ_muY_times2_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muZ_muY_times2_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b0),
            .s_axis_tready_y(muZ_muY_times2_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(numr_part_1_z[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(numr_part_1_z_val[l]),
            .m_axis_tready(),
            .m_axis_tlast(numr_part_1_z_la[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) muX_sq_plus_muY_sq_plus_c1(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq_plus_muY_sq[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(muX_sq_plus_muY_sq_valid),
            .s_axis_tready_x(muX_sq_plus_muY_sq_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muX_sq_plus_muY_sq_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b0),
            .s_axis_tready_y(muX_sq_plus_muY_sq_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(denr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(denr_part_1_x_val[l]),
            .m_axis_tready(),
            .m_axis_tlast(denr_part_1_x_last[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) muZ_sq_plus_muY_sq_plus_c1(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muZ_sq_plus_muY_sq[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(muZ_sq_plus_muY_sq_valid),
            .s_axis_tready_x(muZ_sq_plus_muY_sq_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muZ_sq_plus_muY_sq_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b0),
            .s_axis_tready_y(muZ_sq_plus_muY_sq_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(denr_part_1_z[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(denr_part_1_z_val[l]),
            .m_axis_tready(),
            .m_axis_tlast(denr_part_1_z_last[l])
        );
    end
endgenerate

// stage -4 : numr_part_1_x * (2*sig_xy + c2)) / (denr_part_1_x * (sig_sq_x + sig_sq_y + c2))

wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_z;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_z;

wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_x;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_x;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_z;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_z;

wire [2*PIXEL_SIZE*PIXELS_PER_BEAT:0] out_sig_xy_times_2 = out_sig_xy << 1;
wire [2*PIXEL_SIZE*PIXELS_PER_BEAT:0] out_sig_zy_times_2 = out_sig_zy << 1;

generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            numr_part_2_x[j*18+:18] <= (out_sig_xy_times_2[j*16+:16]) + c2; // one cycle delay for variance terms so that total delay is 5 cycles
            numr_part_2_z[j*18+:18] <= (out_sig_zy_times_2[j*16+:16]) + c2;

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

genvar m;
generate
    for(m=0; m<PIXELS_PER_BEAT; m=m+1) begin


    end
end


/* 
instead of dividing and comparing, we just cross multiply to compare the values
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