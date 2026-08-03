`timescale 1ns/10ps

module SIG_XY #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  PIXEL_SIZE = 8,
    parameter  IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE * PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    input [DATA_WIDTH-1:0] s_axis_tdata_x,
    input                  s_axis_tvalid_x,
    output                 s_axis_tready_x,
    input                  s_axis_tlast_x,
    input [DATA_WIDTH-1:0] s_axis_tdata_y,
    input                  s_axis_tvalid_y,
    output                 s_axis_tready_y,
    input                  s_axis_tlast_y,
    output reg signed [(2*PIXEL_SIZE+1) * PIXELS_PER_BEAT-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

// WIRE DECLARATIONS

wire gauss_xy_ready;
wire advance = (m_axis_tready || !m_axis_tvalid);
wire [PIXELS_PER_BEAT-1:0] mul2_x_ready;
wire [PIXELS_PER_BEAT-1:0] mul2_y_ready;
wire mult_x_ready2 = mul2_x_ready[0];
wire mult_y_ready2 = mul2_y_ready[0];
wire [PIXELS_PER_BEAT-1:0] sub_1_ready, sub_2_ready, sub_val, sub_la;

wire sub_a_ready = sub_1_ready[0];
wire sub_b_ready = sub_2_ready[0];
wire pair_valid = s_axis_tvalid_x & s_axis_tvalid_y;

wire [DATA_WIDTH-1:0] mu_x, mu_y;
wire mu_valid_x, mu_valid_y, mu_last_x, mu_last_y, conv_gauss_x_ready, conv_gauss_y_ready;

wire [2*DATA_WIDTH-1:0] mu_x_mu_y;
wire [PIXELS_PER_BEAT-1:0] mu_x_mu_y_val;
wire [PIXELS_PER_BEAT-1:0] mu_x_mu_y_la;
wire mu_pair_valid = mu_valid_x & mu_valid_y;

wire mu_x_mu_y_valid = mu_x_mu_y_val[0];
wire mu_x_mu_y_last  = mu_x_mu_y_la[0];

wire [2*DATA_WIDTH-1:0] mult_xy;
wire [PIXELS_PER_BEAT-1:0] mul_xy_valid, mul_xy_last;

wire [PIXELS_PER_BEAT-1:0] mul1_x_ready;
wire [PIXELS_PER_BEAT-1:0] mul1_y_ready;

wire mult_x_ready1 = mul1_x_ready[0];
wire mult_y_ready1= mul1_y_ready[0];
wire mult_xy_valid = mul_xy_valid[0];
wire mult_xy_last  = mul_xy_last[0];

localparam CONV_GAUSS_INPUT_WIDTH = 2 * PIXEL_SIZE;
wire [CONV_GAUSS_INPUT_WIDTH*PIXELS_PER_BEAT-1:0] out_gauss_xy;
wire out_gauss_xy_valid, out_gauss_xy_last;

wire signed[(2*PIXEL_SIZE+1) * PIXELS_PER_BEAT -1:0] sub_out;
wire sub_valid = sub_val[0];
wire sub_last  = sub_la[0];



// DATAPATH

CONV_GAUSS #(PIXELS_PER_BEAT, PIXEL_SIZE, IMAGE_DIM) mean_x (aclk, aresetn, s_axis_tdata_x, pair_valid, conv_gauss_x_ready, s_axis_tlast_x, mu_x, mu_valid_x, (mult_x_ready2 & mult_y_ready2), mu_last_x);

CONV_GAUSS #(PIXELS_PER_BEAT, PIXEL_SIZE, IMAGE_DIM) mean_y (aclk, aresetn, s_axis_tdata_y, pair_valid, conv_gauss_y_ready, s_axis_tlast_y, mu_y, mu_valid_y, (mult_x_ready2 & mult_y_ready2), mu_last_y);

genvar k;
generate
    for (k=0; k<PIXELS_PER_BEAT; k=k+1) begin
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE), .mode(0)) mult2 (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(mu_x[k*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_x(mu_pair_valid),
            .s_axis_tready_x(mul2_x_ready[k]),
            .s_axis_tlast_x(mu_last_x),
            .s_axis_tdata_y(mu_y[k*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_y(mu_pair_valid),
            .s_axis_tready_y(mul2_y_ready[k]),
            .s_axis_tlast_y(mu_last_y),
            .m_axis_tdata(mu_x_mu_y[k*2*PIXEL_SIZE +: 2*PIXEL_SIZE]),
            .m_axis_tvalid(mu_x_mu_y_val[k]),
            .m_axis_tready(sub_b_ready),
            .m_axis_tlast(mu_x_mu_y_la[k])
        );
    end
endgenerate

genvar j;
generate
    for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE), .mode (0)) mult1 (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(s_axis_tdata_x[j*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_x(s_axis_tvalid_x),
            .s_axis_tready_x(mul1_x_ready[j]),
            .s_axis_tlast_x(s_axis_tlast_x),
            .s_axis_tdata_y(s_axis_tdata_y[j*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_y(s_axis_tvalid_y),
            .s_axis_tready_y(mul1_y_ready[j]),
            .s_axis_tlast_y(s_axis_tlast_y),
            .m_axis_tdata(mult_xy[j*2*PIXEL_SIZE +: 2*PIXEL_SIZE]),
            .m_axis_tvalid(mul_xy_valid[j]),
            .m_axis_tready(gauss_xy_ready),
            .m_axis_tlast(mul_xy_last[j])
        );
    end
endgenerate

CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) gauss_xy (aclk, aresetn, mult_xy, mult_xy_valid, gauss_xy_ready, mult_xy_last, out_gauss_xy, out_gauss_xy_valid, sub_a_ready, out_gauss_xy_last);

genvar i;
generate begin
    for (i=0; i<PIXELS_PER_BEAT; i=i+1) begin
    AXIS_SUB #(
    .DATA_WIDTH(2*PIXEL_SIZE)
    ) sub (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_a_tdata(out_gauss_xy[i*2*PIXEL_SIZE +: 2*PIXEL_SIZE]),
        .s_axis_a_tvalid(out_gauss_xy_valid),
        .s_axis_a_tready(sub_1_ready[i]),
        .s_axis_a_tlast(out_gauss_xy_last),
        .s_axis_b_tdata(mu_x_mu_y[i*2*PIXEL_SIZE +: 2*PIXEL_SIZE]),
        .s_axis_b_tvalid(mu_x_mu_y_valid),
        .s_axis_b_tready(sub_2_ready[i]),
        .s_axis_b_tlast(mu_x_mu_y_last),
        .m_axis_tdata(sub_out[i*(2*PIXEL_SIZE+1)+: 2*PIXEL_SIZE+1]),
        .m_axis_tvalid(sub_val[i]),
        .m_axis_tready(advance),
        .m_axis_tlast(sub_la[i])
    );
    end
end
endgenerate

always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_tdata  <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
    end
    else begin
        if (sub_valid && advance) begin
            m_axis_tdata  <= sub_out;
            m_axis_tvalid <= sub_valid;
            m_axis_tlast  <= sub_last;
        end
        else if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata  <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
        end
    end
end

assign s_axis_tready_x = conv_gauss_x_ready & conv_gauss_y_ready & mult_x_ready1 & mult_y_ready1 & s_axis_tvalid_y;
assign s_axis_tready_y = conv_gauss_x_ready & conv_gauss_y_ready & mult_x_ready1 & mult_y_ready1 & s_axis_tvalid_x;

endmodule