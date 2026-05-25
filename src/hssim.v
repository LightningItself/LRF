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
        output reg [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr,
        output reg [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] denr,
        output reg [PIXELS_PER_BEAT-1:0] numr_sign,
        output reg              out_valid,
        input                   out_ready,
        output reg              out_last
    );

    localparam c1 = 17'd6;
    localparam c2 = 17'd58;
    wire advance = ( out_ready || !out_valid );

    // calculating mean values of maps

    wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_x;
    wire gauss_map_x_ready, out_mu_x_valid, out_mu_x_last;

    CONV_GAUSS #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_WIDTH(IMAGE_DIM)
    ) gauss_map_x (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(map_x),
        .s_axis_tvalid(map_x_valid),
        .s_axis_tready(gauss_map_x_ready),
        .s_axis_tlast(map_x_last),
        .m_axis_tdata(out_mu_x),
        .m_axis_tvalid(out_mu_x_valid),
        .m_axis_tready(muX_sq_ready_x & muX_sq_ready_y & muX_muY_ready_x),
        .m_axis_tlast(out_mu_x_last)
    );

    wire [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_mu_y;
    wire gauss_map_y_ready, out_mu_y_valid, out_mu_y_last;

    CONV_GAUSS #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_WIDTH(IMAGE_DIM)
    ) gauss_map_y (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(map_y),
        .s_axis_tvalid(map_y_valid),
        .s_axis_tready(gauss_map_y_ready),
        .s_axis_tlast(map_y_last),
        .m_axis_tdata(out_mu_y),
        .m_axis_tvalid(out_mu_y_valid),
        .m_axis_tready(muY_sq_ready_x & muY_sq_ready_y & muX_muY_ready_y),
        .m_axis_tlast(out_mu_y_last)
    );

    // calculating variance and covariance values of maps

    wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_sq_x;
    wire out_sig_sq_x_ready_x, out_sig_sq_x_ready_y, out_sig_sq_x_valid, out_sig_sq_x_last;

    SIG_XY #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) sig_sq_x (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_x(map_x),
        .s_axis_tvalid_x(map_x_valid),
        .s_axis_tready_x(out_sig_sq_x_ready_x),
        .s_axis_tlast_x(map_x_last),
        .s_axis_tdata_y(map_x),
        .s_axis_tvalid_y(map_x_valid),
        .s_axis_tready_y(out_sig_sq_x_ready_y),
        .s_axis_tlast_y(map_x_last),
        .m_axis_tdata(out_sig_sq_x),
        .m_axis_tvalid(out_sig_sq_x_valid),
        .m_axis_tready(denr_part_2_x_ready_x),
        .m_axis_tlast(out_sig_sq_x_last)
    );

    wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_sq_y;
    wire out_sig_sq_y_ready_x, out_sig_sq_y_ready_y, out_sig_sq_y_valid, out_sig_sq_y_last;

    SIG_XY #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) sig_sq_y (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_x(map_y),
        .s_axis_tvalid_x(map_y_valid),
        .s_axis_tready_x(out_sig_sq_y_ready_x),
        .s_axis_tlast_x(map_y_last),
        .s_axis_tdata_y(map_y),
        .s_axis_tvalid_y(map_y_valid),
        .s_axis_tready_y(out_sig_sq_y_ready_y),
        .s_axis_tlast_y(map_y_last),
        .m_axis_tdata(out_sig_sq_y),
        .m_axis_tvalid(out_sig_sq_y_valid),
        .m_axis_tready(denr_part_2_x_ready_y),
        .m_axis_tlast(out_sig_sq_y_last)
    );

    wire signed [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] out_sig_xy;
    wire out_sig_xy_ready_x, out_sig_xy_ready_y, out_sig_xy_valid, out_sig_xy_last;

    SIG_XY #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .PIXEL_SIZE(PIXEL_SIZE),
        .IMAGE_DIM(IMAGE_DIM)
    ) sig_xy (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_x(map_x),
        .s_axis_tvalid_x(map_x_valid),
        .s_axis_tready_x(out_sig_xy_ready_x),
        .s_axis_tlast_x(map_x_last),
        .s_axis_tdata_y(map_y),
        .s_axis_tvalid_y(map_y_valid),
        .s_axis_tready_y(out_sig_xy_ready_y),
        .s_axis_tlast_y(map_y_last),
        .m_axis_tdata(out_sig_xy),
        .m_axis_tvalid(out_sig_xy_valid),
        .m_axis_tready(numr_part_2_x_ready_x),
        .m_axis_tlast(out_sig_xy_last)
    );


    //  muX^2, muY^2, 2*muX*muY calculation

    wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] muX_sq, muY_sq, int_muX_muY;
    wire [PIXELS_PER_BEAT- 1:0] muX_sq_ready_1, muX_sq_ready_2, muY_sq_ready_1, muY_sq_ready_2, muX_muY_ready_1, muX_muY_ready_2;
    wire muX_sq_ready_x = &muX_sq_ready_1;
    wire muX_sq_ready_y = &muX_sq_ready_2;
    wire muY_sq_ready_x = &muY_sq_ready_1;
    wire muY_sq_ready_y = &muY_sq_ready_2;
    wire muX_muY_ready_x = &muX_muY_ready_1;
    wire muX_muY_ready_y = &muX_muY_ready_2;
    wire [PIXELS_PER_BEAT-1:0] muX_sq_val, muY_sq_val, muX_sq_la, muY_sq_la, muX_muY_val, muX_muY_la;
    wire muX_sq_valid = &muX_sq_val;
    wire muY_sq_valid = &muY_sq_val;
    wire muX_sq_last = &muX_sq_la;
    wire muY_sq_last = &muY_sq_la;
    wire int_muX_muY_times2_valid = &muX_muY_val;
    wire int_muX_muY_times2_last = &muX_muY_la;

    genvar j;
    generate
        for (j = 0; j < PIXELS_PER_BEAT; j = j+1) begin

            MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) muX_sq_multiplier (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tdata_x(out_mu_x[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_x(out_mu_x_valid),
                .s_axis_tready_x(muX_sq_ready_1[j]),
                .s_axis_tlast_x(out_mu_x_last),
                .s_axis_tdata_y(out_mu_x[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_y(out_mu_x_valid),
                .s_axis_tready_y(muX_sq_ready_2[j]),
                .s_axis_tlast_y(out_mu_x_last),
                .m_axis_tdata(muX_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
                .m_axis_tvalid(muX_sq_val[j]),
                .m_axis_tready(muX_sq_plus_muY_sq_ready_x),
                .m_axis_tlast(muX_sq_la[j])
            );

            MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) muY_sq_multiplier (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tdata_x(out_mu_y[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_x(out_mu_y_valid),
                .s_axis_tready_x(muY_sq_ready_1[j]),
                .s_axis_tlast_x(out_mu_y_last),
                .s_axis_tdata_y(out_mu_y[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_y(out_mu_y_valid),
                .s_axis_tready_y(muY_sq_ready_2[j]),
                .s_axis_tlast_y(out_mu_y_last),
                .m_axis_tdata(muY_sq[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
                .m_axis_tvalid(muY_sq_val[j]),
                .m_axis_tready(muX_sq_plus_muY_sq_ready_y),
                .m_axis_tlast(muY_sq_la[j])
            );

            MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) muX_muY_multiplier (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tdata_x(out_mu_x[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_x(out_mu_x_valid),
                .s_axis_tready_x(muX_muY_ready_1[j]),
                .s_axis_tlast_x(out_mu_x_last),
                .s_axis_tdata_y(out_mu_y[j*PIXEL_SIZE+:PIXEL_SIZE]),
                .s_axis_tvalid_y(out_mu_y_valid),
                .s_axis_tready_y(muX_muY_ready_2[j]),
                .s_axis_tlast_y(out_mu_y_last),
                .m_axis_tdata(int_muX_muY[j*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
                .m_axis_tvalid(muX_muY_val[j]),
                .m_axis_tready(muX_sq_plus_muY_sq_ready_x & muX_sq_plus_muY_sq_ready_y),
                .m_axis_tlast(muX_muY_la[j])
            );

        end
    endgenerate

    reg [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] muX_muY_1;
    reg muX_muY_times2_valid_1 ,muX_muY_times2_last_1;
    wire [2*PIXEL_SIZE*PIXELS_PER_BEAT-1:0] muX_muY = muX_muY_1;
    wire muX_muY_times2_last = muX_muY_times2_last_1;
    wire muX_muY_times2_valid = muX_muY_times2_valid_1;

    always @(posedge aclk) begin
        if (!aresetn) begin
            muX_muY_1 <= 0;
            muX_muY_times2_valid_1 <= 0;
            muX_muY_times2_last_1 <= 0;
        end
        else begin
            if (muX_sq_plus_muY_sq_ready_x & int_muX_muY_times2_valid) begin
                muX_muY_1 <= int_muX_muY;
                muX_muY_times2_valid_1 <= 1'b1;
                muX_muY_times2_last_1 <= int_muX_muY_times2_last;
            end
            else if (muX_muY_times2_plus_c1_ready_x & muX_muY_times2_valid_1) begin
                muX_muY_1 <= 0;
                muX_muY_times2_valid_1 <= 1'b0;
                muX_muY_times2_last_1 <= 1'b0;
            end
        end
    end

    // muX^2 + muY^2 calculation

    wire [((2*PIXEL_SIZE+1)*PIXELS_PER_BEAT)-1:0] muX_sq_plus_muY_sq;
    wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_ready_1, muX_sq_plus_muY_sq_ready_2, muX_sq_plus_muY_sq_ready_3;
    wire muX_sq_plus_muY_sq_ready_x = &muX_sq_plus_muY_sq_ready_1;
    wire muX_sq_plus_muY_sq_ready_y = &muX_sq_plus_muY_sq_ready_2;
    wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_val, muX_sq_plus_muY_sq_la;
    wire muX_sq_plus_muY_sq_valid = &muX_sq_plus_muY_sq_val;
    wire muX_sq_plus_muY_sq_last = &muX_sq_plus_muY_sq_la;

    genvar k;
    generate
        for (k = 0; k < PIXELS_PER_BEAT; k = k+1) begin

            axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE)) muX_sq_plus_muY_sq_adder (
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
                .s_axis_tdata_z(0),
                .s_axis_tvalid_z(1'b1),
                .s_axis_tready_z(muX_sq_plus_muY_sq_ready_3[k]),
                .s_axis_tlast_z(1'b1),
                .m_axis_tdata(muX_sq_plus_muY_sq[k*(2*PIXEL_SIZE+1)+:2*PIXEL_SIZE+1]),
                .m_axis_tvalid(muX_sq_plus_muY_sq_val[k]),
                .m_axis_tready(muX_sq_plus_muY_sq_plus_c1_ready_x),
                .m_axis_tlast(muX_sq_plus_muY_sq_la[k])
            );

        end
    endgenerate

    // numr_part_1_x = 2*muX*muY + c1, denr_part_1_x = muX^2 + muY^2 + c1 calculation

    wire [((2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_part_1_x, denr_part_1_x;
    wire [PIXELS_PER_BEAT-1:0] muX_muY_times2_plus_c1_ready_1, muX_muY_times2_plus_c1_ready_2, muX_muY_times2_plus_c1_ready_3;
    wire [PIXELS_PER_BEAT-1:0] muX_sq_plus_muY_sq_plus_c1_ready_1, muX_sq_plus_muY_sq_plus_c1_ready_2, muX_sq_plus_muY_sq_plus_c1_ready_3;
    wire muX_sq_plus_muY_sq_plus_c1_ready_x = &muX_sq_plus_muY_sq_plus_c1_ready_1;
    wire muX_muY_times2_plus_c1_ready_x = &muX_muY_times2_plus_c1_ready_1;
    wire muX_muY_times2_plus_c1_ready_y = &muX_muY_times2_plus_c1_ready_2;
    wire muX_muY_times2_plus_c1_ready_z = &muX_muY_times2_plus_c1_ready_3;
    wire [PIXELS_PER_BEAT-1:0] numr_part_1_x_val, numr_part_1_x_la, denr_part_1_x_val, denr_part_1_x_la;
    wire numr_part_1_x_valid = &numr_part_1_x_val;
    wire numr_part_1_x_last = &numr_part_1_x_la;
    wire denr_part_1_x_valid = &denr_part_1_x_val;
    wire denr_part_1_x_last = &denr_part_1_x_la;

    genvar l;
    generate
        for (l = 0; l < PIXELS_PER_BEAT; l = l+1) begin

            axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muX_sq_plus_muY_sq_plus_c1_adder (
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
                .s_axis_tdata_z(0),
                .s_axis_tvalid_z(1'b1),
                .s_axis_tready_z(muX_sq_plus_muY_sq_plus_c1_ready_3[l]),
                .s_axis_tlast_z(1'b1),
                .m_axis_tdata(denr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
                .m_axis_tvalid(denr_part_1_x_val[l]),
                .m_axis_tready(denr_x_multiplier_ready_x),
                .m_axis_tlast(denr_part_1_x_la[l])
            );

            axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) muX_muY_times2_plus_c1_adder (
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
                .s_axis_tdata_z(0),
                .s_axis_tvalid_z(1'b1),
                .s_axis_tready_z(muX_muY_times2_plus_c1_ready_3[l]),
                .s_axis_tlast_z(1'b1),
                .m_axis_tdata(numr_part_1_x[l*(2*PIXEL_SIZE+2)+:2*PIXEL_SIZE+2]),
                .m_axis_tvalid(numr_part_1_x_val[l]),
                .m_axis_tready(numr_x_multiplier_ready_x),
                .m_axis_tlast(numr_part_1_x_la[l])
            );

        end
    endgenerate

    // numr_part_2_x = 2*sig_xy + c2, denr_part_2_x = sig_sq_x + sig_sq_y + c2 calculation

    wire [(((2*PIXEL_SIZE)+2)*PIXELS_PER_BEAT)-1:0] numr_part_2_x;
    wire [(((2*PIXEL_SIZE)+2)*PIXELS_PER_BEAT)-1:0] denr_part_2_x;
    wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_ready_1, numr_part_2_x_ready_2, numr_part_2_x_ready_3;
    wire [PIXELS_PER_BEAT-1:0] denr_part_2_x_ready_1, denr_part_2_x_ready_2, denr_part_2_x_ready_3;
    wire numr_part_2_x_ready_x = &numr_part_2_x_ready_1;
    wire denr_part_2_x_ready_x = &denr_part_2_x_ready_1;
    wire denr_part_2_x_ready_y = &denr_part_2_x_ready_2;
    wire [PIXELS_PER_BEAT-1:0] numr_part_2_x_val, numr_part_2_x_la, denr_part_2_x_val, denr_part_2_x_la;
    wire numr_part_2_x_valid = &numr_part_2_x_val;
    wire numr_part_2_x_last = &numr_part_2_x_la;
    wire denr_part_2_x_valid = &denr_part_2_x_val;
    wire denr_part_2_x_last = &denr_part_2_x_la;
    wire [PIXELS_PER_BEAT-1:0] stage4_sign_x;

    genvar m;
    generate
        for (m = 0; m < PIXELS_PER_BEAT; m = m+1) begin : stage4_adders

        wire signed [2*PIXEL_SIZE+2:0] raw_sum_x_full;
        assign stage4_sign_x[m] = raw_sum_x_full[2*PIXEL_SIZE+2];

            axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE+1)) numr_part_2_x_adder (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tdata_x($signed({{1{out_sig_xy[m*(2*PIXEL_SIZE) + (2*PIXEL_SIZE)-1]}},out_sig_xy[m*(2*PIXEL_SIZE)+:(2*PIXEL_SIZE)]}) <<< 1),
                .s_axis_tvalid_x(out_sig_xy_valid),
                .s_axis_tready_x(numr_part_2_x_ready_1[m]),
                .s_axis_tlast_x(out_sig_xy_last),
                .s_axis_tdata_y(c2),
                .s_axis_tvalid_y(1'b1),
                .s_axis_tready_y(numr_part_2_x_ready_2[m]),
                .s_axis_tlast_y(1'b1),
                .s_axis_tdata_z(0),
                .s_axis_tvalid_z(1'b1),
                .s_axis_tready_z(numr_part_2_x_ready_3[m]),
                .s_axis_tlast_z(1'b1),
                .m_axis_tdata(raw_sum_x_full),
                .m_axis_tvalid(numr_part_2_x_val[m]),
                .m_axis_tready(numr_x_multiplier_ready_y),
                .m_axis_tlast(numr_part_2_x_la[m])
            );

            assign numr_part_2_x[m*(2*PIXEL_SIZE+2)+:(2*PIXEL_SIZE+2)] = raw_sum_x_full[2*PIXEL_SIZE+2] ? (-raw_sum_x_full)[2*PIXEL_SIZE+1:0] : raw_sum_x_full[2*PIXEL_SIZE+1:0];

            axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE)) denr_part_2_x_adder (
                .aclk(aclk),
                .aresetn(aresetn),
                .s_axis_tdata_x(out_sig_sq_x[m*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
                .s_axis_tvalid_x(out_sig_sq_x_valid),
                .s_axis_tready_x(denr_part_2_x_ready_1[m]),
                .s_axis_tlast_x(out_sig_sq_x_last),
                .s_axis_tdata_y(out_sig_sq_y[m*(2*PIXEL_SIZE)+:2*PIXEL_SIZE]),
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
            if(numr_part_1_x_valid & numr_x_multiplier_ready_x & numr_part_2_x_valid & numr_x_multiplier_ready_y) begin
                stage4_sign_x_r1 <= stage4_sign_x;
            end
        end
    end

    // numr and denr calculation

    wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_x, denr_x;
    wire [PIXELS_PER_BEAT-1:0] numr_x_multiplier_ready_1, numr_x_multiplier_ready_2, denr_x_multiplier_ready_1, denr_x_multiplier_ready_2;
    wire numr_x_multiplier_ready_x = &numr_x_multiplier_ready_1;
    wire numr_x_multiplier_ready_y = &numr_x_multiplier_ready_2;
    wire denr_x_multiplier_ready_x = &denr_x_multiplier_ready_1;
    wire denr_x_multiplier_ready_y = &denr_x_multiplier_ready_2;
    wire [PIXELS_PER_BEAT-1:0] numr_x_val, numr_x_la, denr_x_val, denr_x_la;
    wire numr_x_valid = &numr_x_val;
    wire numr_x_last = &numr_x_la;
    wire denr_x_valid = &denr_x_val;
    wire denr_x_last = &denr_x_la;

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
            numr <= 0;
            denr <= 0;
            numr_sign <= 0;
            out_valid <= 0;
            out_last <= 0;
        end
        else begin
            if (numr_x_valid & denr_x_valid & advance) begin
                numr <= numr_x;
                denr <= denr_x;
                numr_sign <= stage4_sign_x_r1;
                out_valid <= 1;
                out_last <= numr_x_last & denr_x_last;
            end
            else if (out_valid & out_ready) begin
                numr <= 0;
                denr <= 0;
                numr_sign <= 0;
                out_valid <= 0;
                out_last <= 0;
            end
        end
    end

    assign map_x_ready = gauss_map_x_ready & out_sig_sq_x_ready_x & out_sig_sq_x_ready_y & out_sig_xy_ready_x;
    assign map_y_ready = gauss_map_y_ready & out_sig_sq_y_ready_x & out_sig_sq_y_ready_y & out_sig_xy_ready_y; 

    endmodule