`timescale 1ns/10ps

module HSSIM #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE = 8,
    parameter IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    input [DATA_WIDTH-1:0] map_x,
    input                  map_x_valid,
    output                 map_x_ready,
    input                  map_x_last,
    input [DATA_WIDTH-1:0] map_y,
    input                  map_y_valid,
    output                 map_y_ready,
    input                  map_y_last,
    output reg [((2*(2*(2*PIXEL_SIZE+2))+1)*PIXELS_PER_BEAT)-1:0] sign_numr_denr,
    output reg              out_valid,
    input                   out_ready,
    output reg              out_last
);

localparam c1 = 17'd6;
localparam c2 = 17'd58;
wire advance = (out_ready | !out_valid);

wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_x;
wire gauss_map_x_ready, out_mu_x_valid, out_mu_x_last;

wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_y;
wire gauss_map_y_ready, out_mu_y_valid, out_mu_y_last;

wire [(2*PIXEL_SIZE+1)*PIXELS_PER_BEAT-1:0] out_sig_sq_x;
wire out_sig_sq_x_ready_x, out_sig_sq_x_ready_y, out_sig_sq_x_valid, out_sig_sq_x_last;

wire [(2*PIXEL_SIZE+1)*PIXELS_PER_BEAT-1:0] out_sig_sq_y;
wire out_sig_sq_y_ready_x, out_sig_sq_y_ready_y, out_sig_sq_y_valid, out_sig_sq_y_last;

wire [(2*PIXEL_SIZE+1)*PIXELS_PER_BEAT-1:0] out_sig_xy;
wire out_sig_xy_ready_x, out_sig_xy_ready_y, out_sig_xy_valid, out_sig_xy_last;

wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] muX_sq, muY_sq, int_muX_muY;
wire [PIXELS_PER_BEAT- 1:0] muX_sq_ready_1, muX_sq_ready_2, muY_sq_ready_1, muY_sq_ready_2, muX_muY_ready_1, muX_muY_ready_2;
wire muX_sq_ready_x = muX_sq_ready_1[0];
wire muX_sq_ready_y = muX_sq_ready_2[0];
wire muY_sq_ready_x = muY_sq_ready_1[0];
wire muY_sq_ready_y = muY_sq_ready_2[0];
wire muX_muY_ready_x = muX_muY_ready_1[0];
wire muX_muY_ready_y = muX_muY_ready_2[0];
wire [PIXELS_PER_BEAT-1:0] muX_sq_val, muY_sq_val, muX_sq_la, muY_sq_la, muX_muY_val, muX_muY_la;
wire muX_sq_valid = muX_sq_val[0];
wire muY_sq_valid = muY_sq_val[0];
wire muX_sq_last = muX_sq_la[0];
wire muY_sq_last = muY_sq_la[0];
wire int_muX_muY_times2_valid = muX_muY_val[0];
wire int_muX_muY_times2_last = muX_muY_la[0];

wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] muX_muY;
wire [PIXELS_PER_BEAT-1:0] buff_ready_1;
wire buff_ready_x = buff_ready_1[0];
wire [PIXELS_PER_BEAT-1:0] muX_muY_val_1, muX_muY_la_1;
wire muX_muY_times2_valid = muX_muY_val_1[0];
wire muX_muY_times2_last = muX_muY_la_1[0];

wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_ready_1, muX_sq_plus_muY_sq_ready_2;
wire muX_sq_plus_muY_sq_ready_x = muX_sq_plus_muY_sq_ready_1[0];
wire muX_sq_plus_muY_sq_ready_y = muX_sq_plus_muY_sq_ready_2[0];
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_val, muX_sq_plus_muY_sq_la;
wire muX_sq_plus_muY_sq_valid = muX_sq_plus_muY_sq_val[0];
wire muX_sq_plus_muY_sq_last = muX_sq_plus_muY_sq_la[0];

wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_x, denr_part_1_x;
wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_1, muX_muY_times2_plus_c1_ready_2;
wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_plus_c1_ready_1, muX_sq_plus_muY_sq_plus_c1_ready_2;
wire muX_sq_plus_muY_sq_plus_c1_ready_x = muX_sq_plus_muY_sq_plus_c1_ready_1[0];
wire muX_muY_times2_plus_c1_ready_x = muX_muY_times2_plus_c1_ready_1[0];
wire muX_muY_times2_plus_c1_ready_y = muX_muY_times2_plus_c1_ready_2[0];
wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_val, numr_part_1_x_la, denr_part_1_x_val, denr_part_1_x_la;
wire numr_part_1_x_valid = numr_part_1_x_val[0];
wire numr_part_1_x_last = numr_part_1_x_la[0];
wire denr_part_1_x_valid = denr_part_1_x_val[0];
wire denr_part_1_x_last = denr_part_1_x_la[0];

wire [(((2*PIXEL_SIZE)+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_x;
wire [(((2*PIXEL_SIZE)+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_x;
wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_ready_1, numr_part_2_x_ready_2;
wire [PIXELS_PER_BEAT-1:0] denr_part_2_x_ready_1, denr_part_2_x_ready_2, denr_part_2_x_ready_3;
wire numr_part_2_x_ready_x = numr_part_2_x_ready_1[0];
wire denr_part_2_x_ready_x = denr_part_2_x_ready_1[0];
wire denr_part_2_x_ready_y = denr_part_2_x_ready_2[0];
wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_val, numr_part_2_x_la, denr_part_2_x_val, denr_part_2_x_la;
wire numr_part_2_x_valid = numr_part_2_x_val[0];
wire numr_part_2_x_last = numr_part_2_x_la[0];
wire denr_part_2_x_valid = denr_part_2_x_val[0];
wire denr_part_2_x_last = denr_part_2_x_la[0];
wire [PIXELS_PER_BEAT-1:0] stage4_sign_x;

wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_x, denr_x;
wire [PIXELS_PER_BEAT-1:0] numr_x_multiplier_ready_1, numr_x_multiplier_ready_2, denr_x_multiplier_ready_1, denr_x_multiplier_ready_2;
wire numr_x_multiplier_ready_x = numr_x_multiplier_ready_1[0];
wire numr_x_multiplier_ready_y = numr_x_multiplier_ready_2[0];
wire denr_x_multiplier_ready_x = denr_x_multiplier_ready_1[0];
wire denr_x_multiplier_ready_y = denr_x_multiplier_ready_2[0];
wire [PIXELS_PER_BEAT-1:0] numr_x_val, numr_x_la, denr_x_val, denr_x_la;
wire numr_x_valid = numr_x_val[0];
wire numr_x_last = numr_x_la[0];
wire denr_x_valid = denr_x_val[0];
wire denr_x_last = denr_x_la[0];

wire [DATA_WIDTH-1:0] map_x_buff, map_y_buff;
wire map_x_buff_valid, map_x_buff_last, map_y_buff_valid, map_y_buff_last;
wire buff_map_x_ready, buff_map_y_ready;

wire [DATA_WIDTH-1:0] buff_out_mu_x, buff_out_mu_y;
wire buff_out_mu_x_ready, buff_out_mu_y_ready, buff_out_mu_x_valid, buff_out_mu_y_valid, buff_out_mu_x_last, buff_out_mu_y_last;

wire [DATA_WIDTH-1:0] buff_out_mu_x2, buff_out_mu_y2;
wire buff_out_mu_x2_ready, buff_out_mu_y2_ready, buff_out_mu_x2_valid, buff_out_mu_y2_valid, buff_out_mu_x2_last, buff_out_mu_y2_last;

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) )buff_map_x (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(map_x),
    .s_axis_tvalid(map_x_valid & map_y_valid),
    .s_axis_tready(buff_map_x_ready),
    .s_axis_tlast(map_x_last),
    .m_axis_tdata(map_x_buff),
    .m_axis_tvalid(map_x_buff_valid),
    .m_axis_tready(gauss_map_x_ready),
    .m_axis_tlast(map_x_buff_last)
);

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) ) buff_map_y (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(map_y),
    .s_axis_tvalid(map_x_valid & map_y_valid),
    .s_axis_tready(buff_map_y_ready),
    .s_axis_tlast(map_y_last),
    .m_axis_tdata(map_y_buff),
    .m_axis_tvalid(map_y_buff_valid),
    .m_axis_tready(gauss_map_x_ready),
    .m_axis_tlast(map_y_buff_last)
);

CONV_GAUSS #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM)) gauss_map_x (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(map_x_buff),
    .s_axis_tvalid(map_x_buff_valid),
    .s_axis_tready(gauss_map_x_ready),
    .s_axis_tlast(map_x_buff_last),
    .m_axis_tdata(out_mu_x),
    .m_axis_tvalid(out_mu_x_valid),
    .m_axis_tready(buff_out_mu_x_ready),
    .m_axis_tlast(out_mu_x_last)
);

CONV_GAUSS #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_WIDTH(IMAGE_DIM) ) gauss_map_y (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(map_y_buff),
    .s_axis_tvalid(map_y_buff_valid),
    .s_axis_tready(gauss_map_y_ready),
    .s_axis_tlast(map_y_buff_last),
    .m_axis_tdata(out_mu_y),
    .m_axis_tvalid(out_mu_y_valid),
    .m_axis_tready(buff_out_mu_y_ready),
    .m_axis_tlast(out_mu_y_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_sq_x (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(map_x),
    .s_axis_tvalid_x(map_x_valid & map_y_valid),
    .s_axis_tready_x(out_sig_sq_x_ready_x),
    .s_axis_tlast_x(map_x_last),
    .s_axis_tdata_y(map_x),
    .s_axis_tvalid_y(map_x_valid & map_y_valid),
    .s_axis_tready_y(out_sig_sq_x_ready_y),
    .s_axis_tlast_y(map_x_last),
    .m_axis_tdata(out_sig_sq_x),
    .m_axis_tvalid(out_sig_sq_x_valid),
    .m_axis_tready(denr_part_2_x_ready_x),
    .m_axis_tlast(out_sig_sq_x_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_sq_y (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(map_y),
    .s_axis_tvalid_x(map_x_valid & map_y_valid),
    .s_axis_tready_x(out_sig_sq_y_ready_x),
    .s_axis_tlast_x(map_y_last),
    .s_axis_tdata_y(map_y),
    .s_axis_tvalid_y(map_x_valid & map_y_valid),
    .s_axis_tready_y(out_sig_sq_y_ready_y),
    .s_axis_tlast_y(map_y_last),
    .m_axis_tdata(out_sig_sq_y),
    .m_axis_tvalid(out_sig_sq_y_valid),
    .m_axis_tready(denr_part_2_x_ready_y),
    .m_axis_tlast(out_sig_sq_y_last)
);

SIG_XY #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) sig_xy (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata_x(map_x),
    .s_axis_tvalid_x(map_x_valid & map_y_valid),
    .s_axis_tready_x(out_sig_xy_ready_x),
    .s_axis_tlast_x(map_x_last),
    .s_axis_tdata_y(map_y),
    .s_axis_tvalid_y(map_x_valid & map_y_valid),
    .s_axis_tready_y(out_sig_xy_ready_y),
    .s_axis_tlast_y(map_y_last),
    .m_axis_tdata(out_sig_xy),
    .m_axis_tvalid(out_sig_xy_valid),
    .m_axis_tready(numr_part_2_x_ready_x),
    .m_axis_tlast(out_sig_xy_last)
);

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) )buffer_out_mu_x (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(out_mu_x),
    .s_axis_tvalid(out_mu_x_valid),
    .s_axis_tready(buff_out_mu_x_ready),
    .s_axis_tlast(out_mu_x_last),
    .m_axis_tdata(buff_out_mu_x),
    .m_axis_tvalid(buff_out_mu_x_valid),
    .m_axis_tready(buff_out_mu_x2_ready),
    .m_axis_tlast(buff_out_mu_x_last)
);

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) )buffer_out_mu_y (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(out_mu_y),
    .s_axis_tvalid(out_mu_y_valid),
    .s_axis_tready(buff_out_mu_y_ready),
    .s_axis_tlast(out_mu_y_last),
    .m_axis_tdata(buff_out_mu_y),
    .m_axis_tvalid(buff_out_mu_y_valid),
    .m_axis_tready(buff_out_mu_y2_ready),
    .m_axis_tlast(buff_out_mu_y_last)
);

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) )buffer_out_mu_x2 (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(buff_out_mu_x),
    .s_axis_tvalid(buff_out_mu_x_valid),
    .s_axis_tready(buff_out_mu_x2_ready),
    .s_axis_tlast(buff_out_mu_x_last),
    .m_axis_tdata(buff_out_mu_x2),
    .m_axis_tvalid(buff_out_mu_x2_valid),
    .m_axis_tready(muX_sq_ready_x),
    .m_axis_tlast(buff_out_mu_x2_last)
);

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH) )buffer_out_mu_y2 (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(buff_out_mu_y),
    .s_axis_tvalid(buff_out_mu_y_valid),
    .s_axis_tready(buff_out_mu_y2_ready),
    .s_axis_tlast(buff_out_mu_y_last),
    .m_axis_tdata(buff_out_mu_y2),
    .m_axis_tvalid(buff_out_mu_y2_valid),
    .m_axis_tready(muY_sq_ready_x),
    .m_axis_tlast(buff_out_mu_y2_last)
);

genvar j;
generate
    for (j = 0; j < PIXELS_PER_BEAT; j = j+1) begin

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE), .mode(0)) muX_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(buff_out_mu_x2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(buff_out_mu_x2_valid),
            .s_axis_tready_x(muX_sq_ready_1[j]),
            .s_axis_tlast_x(buff_out_mu_x2_last),
            .s_axis_tdata_y(buff_out_mu_x2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(buff_out_mu_x2_valid),
            .s_axis_tready_y(muX_sq_ready_2[j]),
            .s_axis_tlast_y(buff_out_mu_x2_last),
            .m_axis_tdata(muX_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_sq_val[j]),
            .m_axis_tready(muX_sq_plus_muY_sq_ready_x),
            .m_axis_tlast(muX_sq_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE), .mode(0)) muY_sq_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(buff_out_mu_y2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(buff_out_mu_y2_valid),
            .s_axis_tready_x(muY_sq_ready_1[j]),
            .s_axis_tlast_x(buff_out_mu_y2_last),
            .s_axis_tdata_y(buff_out_mu_y2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(buff_out_mu_y2_valid),
            .s_axis_tready_y(muY_sq_ready_2[j]),
            .s_axis_tlast_y(buff_out_mu_y2_last),
            .m_axis_tdata(muY_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muY_sq_val[j]),
            .m_axis_tready(muX_sq_plus_muY_sq_ready_y),
            .m_axis_tlast(muY_sq_la[j])
        );

        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE), .mode(0)) muX_muY_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(buff_out_mu_x2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_x(buff_out_mu_x2_valid),
            .s_axis_tready_x(muX_muY_ready_1[j]),
            .s_axis_tlast_x(buff_out_mu_x2_last),
            .s_axis_tdata_y(buff_out_mu_y2[j*PIXEL_SIZE+:PIXEL_SIZE]),
            .s_axis_tvalid_y(buff_out_mu_y2_valid),
            .s_axis_tready_y(muX_muY_ready_2[j]),
            .s_axis_tlast_y(buff_out_mu_y2_last),
            .m_axis_tdata(int_muX_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_muY_val[j]),
            .m_axis_tready(buff_ready_x),
            .m_axis_tlast(muX_muY_la[j])
        );

    end
endgenerate

genvar k;
generate
    for (k = 0; k < PIXELS_PER_BEAT; k = k+1) begin

        axis_adder_2 #(.DATA_WIDTH(2*PIXEL_SIZE), .mode(0)) muX_sq_plus_muY_sq_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(muX_sq_valid),
            .s_axis_tready_x(muX_sq_plus_muY_sq_ready_1[k]),
            .s_axis_tlast_x(muX_sq_last),
            .s_axis_tdata_y(muY_sq[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_y(muY_sq_valid),
            .s_axis_tready_y(muX_sq_plus_muY_sq_ready_2[k]),
            .s_axis_tlast_y(muY_sq_last),
            .m_axis_tdata(muX_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .m_axis_tvalid(muX_sq_plus_muY_sq_val[k]),
            .m_axis_tready(muX_sq_plus_muY_sq_plus_c1_ready_x),
            .m_axis_tlast(muX_sq_plus_muY_sq_la[k])
        );

        axis_buff #( .S_AXIS_DATA_WIDTH(2*PIXEL_SIZE), .M_AXIS_DATA_WIDTH(2*PIXEL_SIZE)) buff(
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata(int_muX_muY[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .s_axis_tvalid(int_muX_muY_times2_valid),
            .s_axis_tready(buff_ready_1[k]),
            .s_axis_tlast(int_muX_muY_times2_last),
            .m_axis_tdata(muX_muY[k*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
            .m_axis_tvalid(muX_muY_val_1[k]),
            .m_axis_tready(muX_muY_times2_plus_c1_ready_x),
            .m_axis_tlast(muX_muY_la_1[k])
        );

    end
endgenerate

genvar l;
generate
    for (l = 0; l < PIXELS_PER_BEAT; l = l+1) begin

        axis_adder_2 #(.DATA_WIDTH(2*PIXEL_SIZE+1), .mode(0)) muX_sq_plus_muY_sq_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(muX_sq_plus_muY_sq[l*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
            .s_axis_tvalid_x(muX_sq_plus_muY_sq_valid),
            .s_axis_tready_x(muX_sq_plus_muY_sq_plus_c1_ready_1[l]),
            .s_axis_tlast_x(muX_sq_plus_muY_sq_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muX_sq_plus_muY_sq_plus_c1_ready_2[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(denr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(denr_part_1_x_val[l]),
            .m_axis_tready(denr_x_multiplier_ready_x),
            .m_axis_tlast(denr_part_1_x_la[l])
        );

        axis_adder_2 #(.DATA_WIDTH(2*PIXEL_SIZE+1), .mode(0)) muX_muY_times2_plus_c1_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(({1'b0, muX_muY[l*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]} << 1)),
            .s_axis_tvalid_x(muX_muY_times2_valid),
            .s_axis_tready_x(muX_muY_times2_plus_c1_ready_1[l]),
            .s_axis_tlast_x(muX_muY_times2_last),
            .s_axis_tdata_y(c1),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(muX_muY_times2_plus_c1_ready_2[l]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(numr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
            .m_axis_tvalid(numr_part_1_x_val[l]),
            .m_axis_tready(numr_x_multiplier_ready_x),
            .m_axis_tlast(numr_part_1_x_la[l])
        );

    end
endgenerate

genvar m;
generate
    for (m = 0; m < PIXELS_PER_BEAT; m = m+1) begin : stage4_adders

        wire signed [2*PIXEL_SIZE+2:0] raw_sum_x_full;
        wire signed [2*PIXEL_SIZE+1:0] multiplied_sig_xy;

        wire [2*PIXEL_SIZE+1:0] c2_numr_padded = c2;

        assign multiplied_sig_xy = $signed({out_sig_xy[m*(2*PIXEL_SIZE+1) + 2*PIXEL_SIZE], out_sig_xy[m*(2*PIXEL_SIZE+1) +: (2*PIXEL_SIZE+1)]}) <<< 1;
        assign stage4_sign_x[m] = raw_sum_x_full[2*PIXEL_SIZE+2];

        axis_adder_2 #(
            .DATA_WIDTH(2*PIXEL_SIZE+2),
            .mode(1)
        ) numr_part_2_x_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(multiplied_sig_xy),
            .s_axis_tvalid_x(out_sig_xy_valid),
            .s_axis_tready_x(numr_part_2_x_ready_1[m]),
            .s_axis_tlast_x(out_sig_xy_last),
            .s_axis_tdata_y(c2_numr_padded),
            .s_axis_tvalid_y(1'b1),
            .s_axis_tready_y(numr_part_2_x_ready_2[m]),
            .s_axis_tlast_y(1'b1),
            .m_axis_tdata(raw_sum_x_full),
            .m_axis_tvalid(numr_part_2_x_val[m]),
            .m_axis_tready(numr_x_multiplier_ready_y),
            .m_axis_tlast(numr_part_2_x_la[m])
        );

        assign numr_part_2_x[m*(2*PIXEL_SIZE+2) +: (2*PIXEL_SIZE+2)] = raw_sum_x_full[2*PIXEL_SIZE+2] ? (~raw_sum_x_full[2*PIXEL_SIZE+1:0] + 1'b1) : raw_sum_x_full[2*PIXEL_SIZE+1:0];

        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE), .mode(0)) denr_part_2_x_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(out_sig_sq_x[m*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(out_sig_sq_x_valid),
            .s_axis_tready_x(denr_part_2_x_ready_1[m]),
            .s_axis_tlast_x(out_sig_sq_x_last),
            .s_axis_tdata_y(out_sig_sq_y[m*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE]),
            .s_axis_tvalid_y(out_sig_sq_y_valid),
            .s_axis_tready_y(denr_part_2_x_ready_2[m]),
            .s_axis_tlast_y(out_sig_sq_y_last),
            .s_axis_tdata_z(c2),
            .s_axis_tvalid_z(1'b1),
            .s_axis_tready_z(denr_part_2_x_ready_3[m]),
            .s_axis_tlast_z(1'b1),
            .m_axis_tdata(denr_part_2_x[m*((2*PIXEL_SIZE)+2)+:(2*PIXEL_SIZE)+2]),
            .m_axis_tvalid(denr_part_2_x_val[m]),
            .m_axis_tready(denr_x_multiplier_ready_y),
            .m_axis_tlast(denr_part_2_x_la[m])
        );

    end
endgenerate

reg [PIXELS_PER_BEAT-1:0] stage4_sign_x_r1;

always @(posedge aclk) begin
    if(!aresetn) begin
        stage4_sign_x_r1 <= 0;
    end
    else begin
        if(numr_part_1_x_valid & numr_x_multiplier_ready_x) begin
            stage4_sign_x_r1 <= stage4_sign_x;
        end
    end
end

genvar n;
generate
    for (n = 0; n < PIXELS_PER_BEAT; n = n+1) begin

        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) numr_x_multiplier (
            .aclk(aclk), 
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_part_1_x[n*(2*PIXEL_SIZE+2)+:(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(numr_part_1_x_valid),
            .s_axis_tready_x(numr_x_multiplier_ready_1[n]),
            .s_axis_tlast_x(numr_part_1_x_last),
            .s_axis_tdata_y(numr_part_2_x[n*(2*PIXEL_SIZE+2)+:(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(numr_part_2_x_valid), 
            .s_axis_tready_y(numr_x_multiplier_ready_2[n]),
            .s_axis_tlast_y(numr_part_2_x_last),
            .m_axis_tdata(numr_x[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(numr_x_val[n]),
            .m_axis_tready(advance),
            .m_axis_tlast(numr_x_la[n])
        );
        
        MULTIPLIER #(.DATA_WIDTH((2*PIXEL_SIZE)+2)) denr_x_multiplier (
            .aclk(aclk), 
            .aresetn(aresetn),
            .s_axis_tdata_x(denr_part_1_x[n*(2*PIXEL_SIZE+2)+:(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(denr_part_1_x_valid),  
            .s_axis_tready_x(denr_x_multiplier_ready_1[n]),
            .s_axis_tlast_x(denr_part_1_x_last),
            .s_axis_tdata_y(denr_part_2_x[n*((2*PIXEL_SIZE)+2)+:(2*PIXEL_SIZE)+2]),
            .s_axis_tvalid_y(denr_part_2_x_valid),  
            .s_axis_tready_y(denr_x_multiplier_ready_2[n]),
            .s_axis_tlast_y(denr_part_2_x_last),
            .m_axis_tdata(denr_x[n*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(denr_x_val[n]),
            .m_axis_tready(advance),
            .m_axis_tlast(denr_x_la[n])
        );

    end
endgenerate

always @(posedge aclk) begin
    if (!aresetn) begin
        sign_numr_denr <= 0;
        out_valid <= 0;
        out_last <= 0;
    end
    else begin
        if (numr_x_valid & advance) begin
            sign_numr_denr <= {stage4_sign_x_r1, numr_x, denr_x};
            out_valid <= 1;
            out_last <= numr_x_last;
        end
        else if (out_valid & out_ready) begin
            sign_numr_denr <= 0;
            out_valid <= 0;
            out_last <= 0;
        end
    end
end

assign map_x_ready = buff_map_x_ready & map_y_valid;
assign map_y_ready = buff_map_y_ready & map_x_valid;

endmodule