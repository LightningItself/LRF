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

localparam c1 = 17'd6;
localparam c2 = 17'd58;

// ---------------------------------------------------------------------------
// WIRE DECLARATIONS
// ---------------------------------------------------------------------------

wire inputs_valid = old_map_valid & avg_map_valid & new_map_valid;

wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_old;
wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_avg;
wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_new;
wire out_mu_old_valid, gauss_old_map_ready, out_mu_old_last;
wire out_mu_avg_valid, gauss_avg_map_ready, out_mu_avg_last;
wire out_mu_new_valid, gauss_new_map_ready, out_mu_new_last;
wire all_mu_valid = out_mu_old_valid & out_mu_avg_valid & out_mu_new_valid;

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

reg  [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] muX_muY;
wire [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] int_muX_muY;
reg  [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] muZ_muY;
wire [(2*PIXEL_SIZE*PIXELS_PER_BEAT)-1:0] int_muZ_muY;

wire [((2*PIXEL_SIZE)*PIXELS_PER_BEAT)-1:0] muX_sq, muY_sq, muZ_sq;

wire [PIXELS_PER_BEAT-1:0] mul_old_sq_ready_1, mul_old_sq_ready_2, mul_avg_sq_ready_1, mul_avg_sq_ready_2, mul_new_sq_ready_1, mul_new_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] mul_old_avg_sq_ready_1, mul_old_avg_sq_ready_2, mul_avg_new_sq_ready_1, mul_avg_new_sq_ready_2;

wire [PIXELS_PER_BEAT-1:0] muX_sq_val, muY_sq_val, muZ_sq_val;
wire [PIXELS_PER_BEAT-1:0] int_muX_muY_times2_val, int_muZ_muY_times2_val;
wire [PIXELS_PER_BEAT-1:0] muX_sq_la,  muY_sq_la,  muZ_sq_la;
wire [PIXELS_PER_BEAT-1:0] int_muX_muY_times2_la, int_muZ_muY_times2_la;

wire muX_sq_valid = &muX_sq_val;
wire muY_sq_valid = &muY_sq_val;
wire muZ_sq_valid = &muZ_sq_val;
wire int_muX_muY_times2_valid = &int_muX_muY_times2_val;
wire int_muZ_muY_times2_valid = &int_muZ_muY_times2_val;

reg  muX_muY_times2_valid, muZ_muY_times2_valid;

wire mu_sq_valids = muX_sq_valid & muY_sq_valid & muZ_sq_valid;
wire alligned_mu_pro_valid = muX_muY_times2_valid & muZ_muY_times2_valid;

wire muX_sq_last             = &muX_sq_la;
wire muY_sq_last             = &muY_sq_la;
wire muZ_sq_last             = &muZ_sq_la;
wire int_muX_muY_times2_last = &int_muX_muY_times2_la;
wire int_muZ_muY_times2_last = &int_muZ_muY_times2_la;

reg  muX_muY_times2_last_1, muZ_muY_times2_last_1;
wire muX_muY_times2_last = muX_muY_times2_last_1;
wire muZ_muY_times2_last = muZ_muY_times2_last_1;

wire mult_old_sq_ready_x     = &mul_old_sq_ready_1;
wire mult_old_sq_ready_y     = &mul_old_sq_ready_2;
wire mult_avg_sq_ready_x     = &mul_avg_sq_ready_1;
wire mult_avg_sq_ready_y     = &mul_avg_sq_ready_2;
wire mult_new_sq_ready_x     = &mul_new_sq_ready_1;
wire mult_new_sq_ready_y     = &mul_new_sq_ready_2;
wire mult_old_avg_sq_ready_x = &mul_old_avg_sq_ready_1;
wire mult_old_avg_sq_ready_y = &mul_old_avg_sq_ready_2;
wire mult_avg_new_sq_ready_x = &mul_avg_new_sq_ready_1;
wire mult_avg_new_sq_ready_y = &mul_avg_new_sq_ready_2;

wire all_mult_ready = mult_old_sq_ready_x & mult_old_sq_ready_y & mult_avg_sq_ready_x & mult_avg_sq_ready_y & mult_new_sq_ready_x & mult_new_sq_ready_y &
    mult_old_avg_sq_ready_x & mult_old_avg_sq_ready_y & mult_avg_new_sq_ready_x & mult_avg_new_sq_ready_y;

wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_ready_1, muX_sq_plus_muY_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] muZ_sq_plus_muY_sq_ready_1, muZ_sq_plus_muY_sq_ready_2;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_ready_3, muZ_sq_plus_muY_sq_ready_3;

wire muX_sq_plus_muY_sq_ready = (&muX_sq_plus_muY_sq_ready_1) & (&muX_sq_plus_muY_sq_ready_2) & (&muX_sq_plus_muY_sq_ready_3);
wire muZ_sq_plus_muY_sq_ready = (&muZ_sq_plus_muY_sq_ready_1) & (&muZ_sq_plus_muY_sq_ready_2) & (&muZ_sq_plus_muY_sq_ready_3);
wire adders_ready_stage_2 = muX_sq_plus_muY_sq_ready & muZ_sq_plus_muY_sq_ready;

wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq;
wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muZ_sq_plus_muY_sq;

wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_val, muZ_sq_plus_muY_sq_val;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_la,  muZ_sq_plus_muY_sq_la;
wire muX_sq_plus_muY_sq_valid = &muX_sq_plus_muY_sq_val;
wire muZ_sq_plus_muY_sq_valid = &muZ_sq_plus_muY_sq_val;
wire stage_2_valids = muX_sq_plus_muY_sq_valid & muZ_sq_plus_muY_sq_valid;
wire muX_sq_plus_muY_sq_last = &muX_sq_plus_muY_sq_la;
wire muZ_sq_plus_muY_sq_last = &muZ_sq_plus_muY_sq_la;

wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_3, muZ_muY_times2_plus_c1_ready_3;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_plus_c1_ready_3, muZ_sq_plus_muY_sq_plus_c1_ready_3;

wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_z;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_1_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_1_z;

wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_val, numr_part_1_z_val;
wire [PIXELS_PER_BEAT-1:0] denr_part_1_x_val, denr_part_1_z_val;
wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_la,  numr_part_1_z_la;
wire [PIXELS_PER_BEAT-1:0] denr_part_1_x_la,  denr_part_1_z_la;

wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_x, muZ_muY_times2_plus_c1_ready_x;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_plus_c1_ready_x, muZ_sq_plus_muY_sq_plus_c1_ready_x;
wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_y, muZ_muY_times2_plus_c1_ready_y;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_plus_c1_ready_y, muZ_sq_plus_muY_sq_plus_c1_ready_y;

wire muX_muY_times2_plus_c1_ready = (&muX_muY_times2_plus_c1_ready_x) & (&muX_muY_times2_plus_c1_ready_y) & (&muX_muY_times2_plus_c1_ready_3);
wire muZ_muY_times2_plus_c1_ready = (&muZ_muY_times2_plus_c1_ready_x) & (&muZ_muY_times2_plus_c1_ready_y) & (&muZ_muY_times2_plus_c1_ready_3);
wire muX_sq_plus_muY_sq_plus_c1_ready = (&muX_sq_plus_muY_sq_plus_c1_ready_x) & (&muX_sq_plus_muY_sq_plus_c1_ready_y) & (&muX_sq_plus_muY_sq_plus_c1_ready_3);
wire muZ_sq_plus_muY_sq_plus_c1_ready = (&muZ_sq_plus_muY_sq_plus_c1_ready_x) & (&muZ_sq_plus_muY_sq_plus_c1_ready_y) & (&muZ_sq_plus_muY_sq_plus_c1_ready_3);

wire adders_ready_stage_3 = muX_muY_times2_plus_c1_ready & muZ_muY_times2_plus_c1_ready & muX_sq_plus_muY_sq_plus_c1_ready & muZ_sq_plus_muY_sq_plus_c1_ready;

wire numr_part_1_x_valid = &numr_part_1_x_val;
wire numr_part_1_z_valid = &numr_part_1_z_val;
wire denr_part_1_x_valid = &denr_part_1_x_val;
wire denr_part_1_z_valid = &denr_part_1_z_val;

wire part_1_valids = numr_part_1_x_valid & numr_part_1_z_valid & denr_part_1_x_valid & denr_part_1_z_valid;

wire numr_part_1_x_last  = &numr_part_1_x_la;
wire numr_part_1_z_last  = &numr_part_1_z_la;
wire denr_part_1_x_last  = &denr_part_1_x_la;
wire denr_part_1_z_last  = &denr_part_1_z_la;

wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_z;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_x;
wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_z;

wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_ready_x, numr_part_2_x_ready_y, numr_part_2_x_ready_z;
wire [PIXELS_PER_BEAT-1:0] numr_part_2_z_ready_x, numr_part_2_z_ready_y, numr_part_2_z_ready_z;
wire [PIXELS_PER_BEAT-1:0] denr_part_2_x_ready_x, denr_part_2_x_ready_y, denr_part_2_x_ready_z;
wire [PIXELS_PER_BEAT-1:0] denr_part_2_z_ready_x, denr_part_2_z_ready_y, denr_part_2_z_ready_z;

wire numr_part_2_x_ready = (&numr_part_2_x_ready_x) & (&numr_part_2_x_ready_y) & (&numr_part_2_x_ready_z);
wire numr_part_2_z_ready = (&numr_part_2_z_ready_x) & (&numr_part_2_z_ready_y) & (&numr_part_2_z_ready_z);
wire denr_part_2_x_ready = (&denr_part_2_x_ready_x) & (&denr_part_2_x_ready_y) & (&denr_part_2_x_ready_z);
wire denr_part_2_z_ready = (&denr_part_2_z_ready_x) & (&denr_part_2_z_ready_y) & (&denr_part_2_z_ready_z);

wire numr_denr_part_2_ready = numr_part_2_x_ready & numr_part_2_z_ready & denr_part_2_x_ready & denr_part_2_z_ready;

wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_val, numr_part_2_x_la;
wire [PIXELS_PER_BEAT-1:0] numr_part_2_z_val, numr_part_2_z_la;
wire [PIXELS_PER_BEAT-1:0] denr_part_2_x_val, denr_part_2_x_la;
wire [PIXELS_PER_BEAT-1:0] denr_part_2_z_val, denr_part_2_z_la;

wire numr_part_2_x_valid = &numr_part_2_x_val;
wire numr_part_2_z_valid = &numr_part_2_z_val;
wire denr_part_2_x_valid = &denr_part_2_x_val;
wire denr_part_2_z_valid = &denr_part_2_z_val;

wire part_2_valids = numr_part_2_x_valid & numr_part_2_z_valid & denr_part_2_x_valid & denr_part_2_z_valid;

wire numr_part_2_x_last  = &numr_part_2_x_la;
wire numr_part_2_z_last  = &numr_part_2_z_la;
wire denr_part_2_x_last  = &denr_part_2_x_la;
wire denr_part_2_z_last  = &denr_part_2_z_la;

wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_x;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_x;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_z;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr_z;

wire [PIXELS_PER_BEAT-1:0] numr_x_la, numr_z_la, denr_x_la, denr_z_la;
wire [PIXELS_PER_BEAT-1:0] numr_x_val, numr_z_val, denr_x_val, denr_z_val;

wire numr_x_valid = &numr_x_val;
wire numr_z_valid = &numr_z_val;
wire denr_x_valid = &denr_x_val;
wire denr_z_valid = &denr_z_val;

wire all_numr_denr_valid = numr_x_valid & denr_z_valid & numr_z_valid & denr_x_valid;

wire numr_x_last  = &numr_x_la;
wire numr_z_last  = &numr_z_la;
wire denr_x_last  = &denr_x_la;
wire denr_z_last  = &denr_z_la;

wire [PIXELS_PER_BEAT-1:0] numr_x_multiplier_ready_x, numr_x_multiplier_ready_y;
wire [PIXELS_PER_BEAT-1:0] numr_z_multiplier_ready_x, numr_z_multiplier_ready_y;
wire [PIXELS_PER_BEAT-1:0] denr_x_multiplier_ready_x, denr_x_multiplier_ready_y;
wire [PIXELS_PER_BEAT-1:0] denr_z_multiplier_ready_x, denr_z_multiplier_ready_y;

wire numr_x_multiplier_ready = (&numr_x_multiplier_ready_x) & (&numr_x_multiplier_ready_y);
wire numr_z_multiplier_ready = (&numr_z_multiplier_ready_x) & (&numr_z_multiplier_ready_y);
wire denr_x_multiplier_ready = (&denr_x_multiplier_ready_x) & (&denr_x_multiplier_ready_y);
wire denr_z_multiplier_ready = (&denr_z_multiplier_ready_x) & (&denr_z_multiplier_ready_y);

wire x_ports_ready = (&numr_x_multiplier_ready_x) & (&numr_z_multiplier_ready_x) & (&denr_x_multiplier_ready_x) & (&denr_z_multiplier_ready_x);

wire y_ports_ready = (&numr_x_multiplier_ready_y) & (&numr_z_multiplier_ready_y) & (&denr_x_multiplier_ready_y) & (&denr_z_multiplier_ready_y);

wire [(4*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] p1;
wire [(4*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] p2;

wire [PIXELS_PER_BEAT-1:0] p1_val, p1_la, p2_val, p2_la;
wire [PIXELS_PER_BEAT-1:0] p1_multiplier_ready_x, p1_multiplier_ready_y;
wire [PIXELS_PER_BEAT-1:0] p2_multiplier_ready_x, p2_multiplier_ready_y;

wire p1_multiplier_ready   = (&p1_multiplier_ready_x) & (&p1_multiplier_ready_y);
wire p2_multiplier_ready   = (&p2_multiplier_ready_x) & (&p2_multiplier_ready_y);
wire p1_p2_multipliers_ready = p1_multiplier_ready & p2_multiplier_ready;

wire p1_valid = &p1_val;
wire p2_valid = &p2_val;

wire p1_p2_valid = p1_valid & p2_valid;

wire p1_last  = &p1_la;
wire p2_last  = &p2_la;

wire all_sig_valid = out_sig_sq_x_valid & out_sig_sq_y_valid & out_sig_sq_z_valid & out_sig_xy_valid & out_sig_zy_valid;

reg [PIXELS_PER_BEAT-1:0] comp_val;
wire advance = (del_ready || !del_valid);

wire temp = gauss_old_map_ready & gauss_avg_map_ready & gauss_new_map_ready & out_sig_sq_x_ready_x & out_sig_sq_x_ready_y & out_sig_sq_y_ready_x 
    & out_sig_sq_y_ready_y & out_sig_sq_z_ready_x & out_sig_sq_z_ready_y & out_sig_xy_ready_x & out_sig_xy_ready_y & out_sig_zy_ready_x & out_sig_zy_ready_y;

wire [PIXELS_PER_BEAT-1:0] stage4_sign_x;
wire [PIXELS_PER_BEAT-1:0] stage4_sign_z;
wire part_1_2_valids = part_1_valids & part_2_valids;
reg [PIXELS_PER_BEAT-1:0] stage4_sign_x_1, stage4_sign_z_1;
reg [PIXELS_PER_BEAT-1:0] stage4_sign_x_2, stage4_sign_z_2;

wire penultimate_multipliers_ready = x_ports_ready & y_ports_ready;

// ---------------------------------------------------------------------------
// DATAPATH
// ---------------------------------------------------------------------------

CONV_GAUSS #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_WIDTH(IMAGE_DIM)
) gauss_old_map (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(old_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(gauss_old_map_ready),
    .s_axis_tlast(old_map_last),
    .m_axis_tdata(out_mu_old),
    .m_axis_tvalid(out_mu_old_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_old_last)
);

CONV_GAUSS #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_WIDTH(IMAGE_DIM)
) gauss_avg_map (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(avg_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(gauss_avg_map_ready),
    .s_axis_tlast(avg_map_last),
    .m_axis_tdata(out_mu_avg),
    .m_axis_tvalid(out_mu_avg_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_avg_last)
);

CONV_GAUSS #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_WIDTH(IMAGE_DIM)
) gauss_new_map (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(new_map),
    .s_axis_tvalid(inputs_valid),
    .s_axis_tready(gauss_new_map_ready),
    .s_axis_tlast(new_map_last),
    .m_axis_tdata(out_mu_new),
    .m_axis_tvalid(out_mu_new_valid),
    .m_axis_tready(all_mult_ready),
    .m_axis_tlast(out_mu_new_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_sq_x (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(old_map),
    .s_axis_tvalid_x(inputs_valid),
    .s_axis_tready_x(out_sig_sq_x_ready_x),
    .s_axis_tlast_x(old_map_last),
    .s_axis_tdata_y(old_map),
    .s_axis_tvalid_y(inputs_valid),
    .s_axis_tready_y(out_sig_sq_x_ready_y),
    .s_axis_tlast_y(old_map_last),
    .m_axis_tdata(out_sig_sq_x),
    .m_axis_tvalid(out_sig_sq_x_valid),
    .m_axis_tready(numr_denr_part_2_ready),
    .m_axis_tlast(out_sig_sq_x_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_sq_y (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(avg_map),
    .s_axis_tvalid_x(inputs_valid),
    .s_axis_tready_x(out_sig_sq_y_ready_x),
    .s_axis_tlast_x(avg_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(inputs_valid),
    .s_axis_tready_y(out_sig_sq_y_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_sq_y),
    .m_axis_tvalid(out_sig_sq_y_valid),
    .m_axis_tready(numr_denr_part_2_ready),
    .m_axis_tlast(out_sig_sq_y_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_sq_z (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(new_map),
    .s_axis_tvalid_x(inputs_valid),
    .s_axis_tready_x(out_sig_sq_z_ready_x),
    .s_axis_tlast_x(new_map_last),
    .s_axis_tdata_y(new_map),
    .s_axis_tvalid_y(inputs_valid),
    .s_axis_tready_y(out_sig_sq_z_ready_y),
    .s_axis_tlast_y(new_map_last),
    .m_axis_tdata(out_sig_sq_z),
    .m_axis_tvalid(out_sig_sq_z_valid),
    .m_axis_tready(numr_denr_part_2_ready),
    .m_axis_tlast(out_sig_sq_z_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_xy (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(old_map),
    .s_axis_tvalid_x(inputs_valid),
    .s_axis_tready_x(out_sig_xy_ready_x),
    .s_axis_tlast_x(old_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(inputs_valid),
    .s_axis_tready_y(out_sig_xy_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_xy),
    .m_axis_tvalid(out_sig_xy_valid),
    .m_axis_tready(numr_denr_part_2_ready),
    .m_axis_tlast(out_sig_xy_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_zy (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(new_map),
    .s_axis_tvalid_x(inputs_valid),
    .s_axis_tready_x(out_sig_zy_ready_x),
    .s_axis_tlast_x(new_map_last),
    .s_axis_tdata_y(avg_map),
    .s_axis_tvalid_y(inputs_valid),
    .s_axis_tready_y(out_sig_zy_ready_y),
    .s_axis_tlast_y(avg_map_last),
    .m_axis_tdata(out_sig_zy),
    .m_axis_tvalid(out_sig_zy_valid),
    .m_axis_tready(numr_denr_part_2_ready),
    .m_axis_tlast(out_sig_zy_last)
);

genvar j;
generate
    for (j = 0; j < PIXELS_PER_BEAT; j = j+1) begin

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_old_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(all_mu_valid),
            .s_axis_tready_x(mul_old_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_old_last),
            .s_axis_tdata_y(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(all_mu_valid),
            .s_axis_tready_y(mul_old_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_old_last),
            .m_axis_tdata(muX_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muX_sq_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_avg_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(all_mu_valid),
            .s_axis_tready_x(mul_avg_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_avg_last),
            .s_axis_tdata_y(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(all_mu_valid),
            .s_axis_tready_y(mul_avg_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_avg_last),
            .m_axis_tdata(muY_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muY_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muY_sq_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_new_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(all_mu_valid),
            .s_axis_tready_x(mul_new_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_new_last),
            .s_axis_tdata_y(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(all_mu_valid),
            .s_axis_tready_y(mul_new_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_new_last),
            .m_axis_tdata(muZ_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muZ_sq_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(muZ_sq_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_old_avg_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_old[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(all_mu_valid),
            .s_axis_tready_x(mul_old_avg_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_old_last),
            .s_axis_tdata_y(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(all_mu_valid),
            .s_axis_tready_y(mul_old_avg_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_avg_last),
            .m_axis_tdata(int_muX_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(int_muX_muY_times2_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(int_muX_muY_times2_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult_avg_new_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_mu_avg[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(all_mu_valid),
            .s_axis_tready_x(mul_avg_new_sq_ready_1[j]),
            .s_axis_tlast_x(out_mu_avg_last),
            .s_axis_tdata_y(out_mu_new[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(all_mu_valid),
            .s_axis_tready_y(mul_avg_new_sq_ready_2[j]),
            .s_axis_tlast_y(out_mu_new_last),
            .m_axis_tdata(int_muZ_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(int_muZ_muY_times2_val[j]),
            .m_axis_tready(adders_ready_stage_2),
            .m_axis_tlast(int_muZ_muY_times2_la[j])
        );

    end
endgenerate

always @(posedge aclk) begin
    if (!aresetn) begin
        muX_muY <= 0;
        muZ_muY <= 0;
        muX_muY_times2_valid <= 0;
        muZ_muY_times2_valid <= 0;
        muX_muY_times2_last_1 <= 0;
        muZ_muY_times2_last_1 <= 0;
    end
    else begin
        if (adders_ready_stage_2 & int_muX_muY_times2_valid & int_muZ_muY_times2_valid) begin
            muX_muY <= int_muX_muY;
            muZ_muY <= int_muZ_muY;
            muX_muY_times2_valid <= 1'b1;
            muZ_muY_times2_valid <= 1'b1;
            muX_muY_times2_last_1 <= int_muX_muY_times2_last;
            muZ_muY_times2_last_1 <= int_muZ_muY_times2_last;
        end
        else if (adders_ready_stage_3 & muX_muY_times2_valid & muZ_muY_times2_valid) begin
            muX_muY <= 0;
            muZ_muY <= 0;
            muX_muY_times2_valid <= 1'b0;
            muZ_muY_times2_valid <= 1'b0;
            muX_muY_times2_last_1 <= 1'b0;
            muZ_muY_times2_last_1 <= 1'b0;
        end
    end
end

genvar k;
generate
    for (k = 0; k < PIXELS_PER_BEAT; k = k+1) begin

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE)) muX_sq_plus_muY_sq_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(mu_sq_valids),
            .s_axis_tready_x(muX_sq_plus_muY_sq_ready_1[k]),
            .s_axis_tlast_x(muX_sq_last),
            .s_axis_tdata_y(muY_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_y(mu_sq_valids),
            .s_axis_tready_y(muX_sq_plus_muY_sq_ready_2[k]),
            .s_axis_tlast_y(muY_sq_last),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muX_sq_plus_muY_sq_ready_3[k]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(muX_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .m_axis_tvalid(muX_sq_plus_muY_sq_val[k]),
            .m_axis_tready(adders_ready_stage_3),
            .m_axis_tlast(muX_sq_plus_muY_sq_la[k])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE)) muZ_sq_plus_muY_sq_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muZ_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(mu_sq_valids),
            .s_axis_tready_x(muZ_sq_plus_muY_sq_ready_1[k]),
            .s_axis_tlast_x(muZ_sq_last),
            .s_axis_tdata_y(muY_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_y(mu_sq_valids),
            .s_axis_tready_y(muZ_sq_plus_muY_sq_ready_2[k]),
            .s_axis_tlast_y(muY_sq_last),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muZ_sq_plus_muY_sq_ready_3[k]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(muZ_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .m_axis_tvalid(muZ_sq_plus_muY_sq_val[k]),
            .m_axis_tready(adders_ready_stage_3),
            .m_axis_tlast(muZ_sq_plus_muY_sq_la[k])
        );

    end
endgenerate

genvar l;
generate
    for (l = 0; l < PIXELS_PER_BEAT; l = l+1) begin

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muX_muY_times2_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(({1'b0, muX_muY[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]} << 1)),
            .s_axis_tvalid_x(alligned_mu_pro_valid),
            .s_axis_tready_x(muX_muY_times2_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muX_muY_times2_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muX_muY_times2_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muX_muY_times2_plus_c1_ready_3[l]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(numr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(numr_part_1_x_val[l]),
            .m_axis_tready(x_ports_ready),
            .m_axis_tlast(numr_part_1_x_la[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muZ_muY_times2_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(({1'b0, muZ_muY[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]} << 1)),
            .s_axis_tvalid_x(alligned_mu_pro_valid),
            .s_axis_tready_x(muZ_muY_times2_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muZ_muY_times2_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muZ_muY_times2_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muZ_muY_times2_plus_c1_ready_3[l]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(numr_part_1_z[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(numr_part_1_z_val[l]),
            .m_axis_tready(x_ports_ready),
            .m_axis_tlast(numr_part_1_z_la[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muX_sq_plus_muY_sq_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq_plus_muY_sq[l*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_x(stage_2_valids),
            .s_axis_tready_x(muX_sq_plus_muY_sq_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muX_sq_plus_muY_sq_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muX_sq_plus_muY_sq_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muX_sq_plus_muY_sq_plus_c1_ready_3[l]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(denr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(denr_part_1_x_val[l]),
            .m_axis_tready(x_ports_ready),
            .m_axis_tlast(denr_part_1_x_la[l])
        );

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muZ_sq_plus_muY_sq_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muZ_sq_plus_muY_sq[l*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_x(stage_2_valids),
            .s_axis_tready_x(muZ_sq_plus_muY_sq_plus_c1_ready_x[l]),
            .s_axis_tlast_x(muZ_sq_plus_muY_sq_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muZ_sq_plus_muY_sq_plus_c1_ready_y[l]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(muZ_sq_plus_muY_sq_plus_c1_ready_3[l]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(denr_part_1_z[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(denr_part_1_z_val[l]),
            .m_axis_tready(x_ports_ready),
            .m_axis_tlast(denr_part_1_z_la[l])
        );

    end
endgenerate

genvar m;
generate
    for (m = 0; m < PIXELS_PER_BEAT; m = m+1) begin : stage4_adders

        wire [19:0] raw_sum_x_full;
        wire [19:0] raw_sum_z_full;
        
        wire [17:0] raw_sum_x = raw_sum_x_full[17:0];
        wire [17:0] raw_sum_z = raw_sum_z_full[17:0];

        wire local_sign_x = raw_sum_x[17];
        wire local_sign_z = raw_sum_z[17];

        assign stage4_sign_x[m] = local_sign_x;
        assign stage4_sign_z[m] = local_sign_z;
        wire [17:0] neg_sum_x = ~raw_sum_x + 18'd1;
        wire [17:0] neg_sum_z = ~raw_sum_z + 18'd1;

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) numr_part_2_x_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x({out_sig_xy[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_xy[m*2*PIXEL_SIZE+:2*PIXEL_SIZE], 1'b0}),
            .s_axis_tvalid_x(all_sig_valid),
            .s_axis_tready_x(numr_part_2_x_ready_x[m]),
            .s_axis_tlast_x(out_sig_xy_last),
            .s_axis_tdata_y({1'b0, c2}),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(numr_part_2_x_ready_y[m]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(18'd0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(numr_part_2_x_ready_z[m]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(raw_sum_x_full),
            .m_axis_tvalid(numr_part_2_x_val[m]),
            .m_axis_tready(y_ports_ready),
            .m_axis_tlast(numr_part_2_x_la[m])
        );

        assign numr_part_2_x[m*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2] = local_sign_x ? {1'b0, neg_sum_x[16:0]} : {1'b0, raw_sum_x[16:0]};

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+2)) numr_part_2_z_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x({out_sig_zy[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_zy[m*2*PIXEL_SIZE+:2*PIXEL_SIZE], 1'b0}),
            .s_axis_tvalid_x(all_sig_valid),
            .s_axis_tready_x(numr_part_2_z_ready_x[m]),
            .s_axis_tlast_x(out_sig_zy_last),
            .s_axis_tdata_y({1'b0, c2}),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(numr_part_2_z_ready_y[m]),
            .s_axis_tlast_y(1'b1),
            .s_axis_tdata_z(18'd0),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(numr_part_2_z_ready_z[m]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(raw_sum_z_full),
            .m_axis_tvalid(numr_part_2_z_val[m]),
            .m_axis_tready(y_ports_ready),
            .m_axis_tlast(numr_part_2_z_la[m])
        );

        assign numr_part_2_z[m*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2] = local_sign_z ? {1'b0, neg_sum_z[16:0]} : {1'b0, raw_sum_z[16:0]};

        wire [18:0] raw_denr_2_x_full;
        wire [18:0] raw_denr_2_z_full;

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) denr_part_2_x_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x({out_sig_sq_x[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_sq_x[m*2*PIXEL_SIZE+:2*PIXEL_SIZE]}),
            .s_axis_tvalid_x(all_sig_valid),
            .s_axis_tready_x(denr_part_2_x_ready_x[m]),
            .s_axis_tlast_x(out_sig_sq_x_last),
            .s_axis_tdata_y({out_sig_sq_y[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_sq_y[m*2*PIXEL_SIZE+:2*PIXEL_SIZE]}),
            .s_axis_tvalid_y(all_sig_valid),
            .s_axis_tready_y(denr_part_2_x_ready_y[m]),
            .s_axis_tlast_y(out_sig_sq_y_last),
            .s_axis_tdata_z({1'b0, c2[15:0]}),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(denr_part_2_x_ready_z[m]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(raw_denr_2_x_full),
            .m_axis_tvalid(denr_part_2_x_val[m]),
            .m_axis_tready(y_ports_ready),
            .m_axis_tlast(denr_part_2_x_la[m])
        );

        assign denr_part_2_x[m*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2] = raw_denr_2_x_full[17:0];

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) denr_part_2_z_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x({out_sig_sq_z[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_sq_z[m*2*PIXEL_SIZE+:2*PIXEL_SIZE]}),
            .s_axis_tvalid_x(all_sig_valid),
            .s_axis_tready_x(denr_part_2_z_ready_x[m]),
            .s_axis_tlast_x(out_sig_sq_z_last),
            .s_axis_tdata_y({out_sig_sq_y[m*2*PIXEL_SIZE + 2*PIXEL_SIZE - 1], out_sig_sq_y[m*2*PIXEL_SIZE+:2*PIXEL_SIZE]}),
            .s_axis_tvalid_y(all_sig_valid),
            .s_axis_tready_y(denr_part_2_z_ready_y[m]),
            .s_axis_tlast_y(out_sig_sq_y_last),
            .s_axis_tdata_z({1'b0, c2[15:0]}),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(denr_part_2_z_ready_z[m]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(raw_denr_2_z_full),
            .m_axis_tvalid(denr_part_2_z_val[m]),
            .m_axis_tready(y_ports_ready),
            .m_axis_tlast(denr_part_2_z_la[m])
        );

        assign denr_part_2_z[m*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2] = raw_denr_2_z_full[17:0];

    end
endgenerate

genvar n;
generate
    for (n = 0; n < PIXELS_PER_BEAT; n = n+1) begin

        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) numr_x_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_part_1_x[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_x(part_1_2_valids),
            .s_axis_tready_x(numr_x_multiplier_ready_x[n]),
            .s_axis_tlast_x(numr_part_1_x_last),
            .s_axis_tdata_y(numr_part_2_x[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_y(part_1_2_valids),
            .s_axis_tready_y(numr_x_multiplier_ready_y[n]),
            .s_axis_tlast_y(numr_part_2_x_last),
            .m_axis_tdata(numr_x[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(numr_x_val[n]),
            .m_axis_tready(p1_p2_multipliers_ready),
            .m_axis_tlast(numr_x_la[n])
        );

        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) numr_z_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_part_1_z[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_x(part_1_2_valids),
            .s_axis_tready_x(numr_z_multiplier_ready_x[n]),
            .s_axis_tlast_x(numr_part_1_z_last),
            .s_axis_tdata_y(numr_part_2_z[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_y(part_1_2_valids),
            .s_axis_tready_y(numr_z_multiplier_ready_y[n]),
            .s_axis_tlast_y(numr_part_2_z_last),
            .m_axis_tdata(numr_z[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(numr_z_val[n]),
            .m_axis_tready(p1_p2_multipliers_ready),
            .m_axis_tlast(numr_z_la[n])
        );

        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) denr_x_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(denr_part_1_x[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_x(part_1_2_valids),
            .s_axis_tready_x(denr_x_multiplier_ready_x[n]),
            .s_axis_tlast_x(denr_part_1_x_last),
            .s_axis_tdata_y(denr_part_2_x[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_y(part_1_2_valids),
            .s_axis_tready_y(denr_x_multiplier_ready_y[n]),
            .s_axis_tlast_y(denr_part_2_x_last),
            .m_axis_tdata(denr_x[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(denr_x_val[n]),
            .m_axis_tready(p1_p2_multipliers_ready),
            .m_axis_tlast(denr_x_la[n])
        );

        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) denr_z_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(denr_part_1_z[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_x(part_1_2_valids),
            .s_axis_tready_x(denr_z_multiplier_ready_x[n]),
            .s_axis_tlast_x(denr_part_1_z_last),
            .s_axis_tdata_y(denr_part_2_z[n*2*(PIXEL_SIZE+1)+:2*(PIXEL_SIZE+1)]),
            .s_axis_tvalid_y(part_1_2_valids),
            .s_axis_tready_y(denr_z_multiplier_ready_y[n]),
            .s_axis_tlast_y(denr_part_2_z_last),
            .m_axis_tdata(denr_z[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(denr_z_val[n]),
            .m_axis_tready(p1_p2_multipliers_ready),
            .m_axis_tlast(denr_z_la[n])
        );

    end
endgenerate

always @(posedge aclk) begin
    if (!aresetn) begin
        stage4_sign_x_1 <= 0;
        stage4_sign_z_1 <= 0;
    end
    else begin
        if (penultimate_multipliers_ready & part_1_2_valids) begin
            stage4_sign_x_1 <= stage4_sign_x;
            stage4_sign_z_1 <= stage4_sign_z;
        end
    end
end

genvar i;
generate
    for (i = 0; i < PIXELS_PER_BEAT; i = i+1) begin

        MULTIPLIER #(.DATA_WIDTH(2*(2*PIXEL_SIZE+2))) p1_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(all_numr_denr_valid),
            .s_axis_tready_x(p1_multiplier_ready_x[i]),
            .s_axis_tlast_x(numr_x_last),
            .s_axis_tdata_y(denr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(all_numr_denr_valid),
            .s_axis_tready_y(p1_multiplier_ready_y[i]),
            .s_axis_tlast_y(denr_z_last),
            .m_axis_tdata(p1[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p1_val[i]),
            .m_axis_tready(advance),
            .m_axis_tlast(p1_la[i])
        );

        MULTIPLIER #(.DATA_WIDTH(2*(2*PIXEL_SIZE+2))) p2_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(all_numr_denr_valid),
            .s_axis_tready_x(p2_multiplier_ready_x[i]),
            .s_axis_tlast_x(numr_z_last),
            .s_axis_tdata_y(denr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(all_numr_denr_valid),
            .s_axis_tready_y(p2_multiplier_ready_y[i]),
            .s_axis_tlast_y(denr_x_last),
            .m_axis_tdata(p2[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p2_val[i]),
            .m_axis_tready(advance),
            .m_axis_tlast(p2_la[i])
        );

    end
endgenerate

always @(posedge aclk) begin
    if (!aresetn) begin
        stage4_sign_x_2 <= 0;
        stage4_sign_z_2 <= 0;
    end
    else begin
        if (p1_p2_multipliers_ready & all_numr_denr_valid) begin
            stage4_sign_x_2 <= stage4_sign_x_1;
            stage4_sign_z_2 <= stage4_sign_z_1;
        end
    end
end

genvar p;
generate
    for (p = 0; p < PIXELS_PER_BEAT; p = p+1) begin
        always @(*) begin
            if (stage4_sign_x_2[p] == 0 && stage4_sign_z_2[p] == 0) begin
                comp_val[p] = p2[p*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)] > p1[p*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)];
            end
            else if (stage4_sign_x_2[p] == 1 && stage4_sign_z_2[p] == 1) begin
                comp_val[p] = p1[p*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)] > p2[p*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)];
            end
            else if (stage4_sign_x_2[p] == 1 && stage4_sign_z_2[p] == 0) begin
                comp_val[p] = 1'b1;
            end
            else begin
                comp_val[p] = 1'b0;
            end
        end
    end
endgenerate

integer idx;
always @(posedge aclk) begin
    if (!aresetn) begin
        del <= 0;
        del_valid <= 0;
        del_last <= 0;
    end
    else begin
        if (p1_p2_valid & advance) begin
            for (idx = 0; idx < PIXELS_PER_BEAT; idx = idx+1) begin
                del[idx*PIXEL_SIZE+:PIXEL_SIZE] <= comp_val[idx] ? 8'd255 : 8'd0;
            end
            del_valid <= 1;
            del_last  <= (p1_last & p2_last);
        end
        else if (del_valid & del_ready) begin
            del <= 0;
            del_valid <= 0;
            del_last <= 0;
        end
    end
end

assign old_map_ready = avg_map_valid & new_map_valid & temp;

assign avg_map_ready = old_map_valid & new_map_valid & temp;

assign new_map_ready = old_map_valid & avg_map_valid & temp;

endmodule