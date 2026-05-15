`timescale 1ns/10ps

module SIG_XY #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  PIXEL_SIZE = 8,
    parameter  IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE * PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    // AXIS interface for x
    input [DATA_WIDTH-1:0] s_axis_tdata_x,
    input                  s_axis_tvalid_x,
    output                 s_axis_tready_x,
    input                  s_axis_tlast_x,
    // AXIS interface for y
    input [DATA_WIDTH-1:0] s_axis_tdata_y,
    input                  s_axis_tvalid_y,
    output                 s_axis_tready_y,
    input                  s_axis_tlast_y,
    // AXIS interface for output
    output reg signed [2*DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

wire gauss_xy_ready;
wire advance = (m_axis_tready || !m_axis_tvalid);
wire mult_x_ready2 = &mul2_x_ready;
wire mult_y_ready2 = &mul2_y_ready;

// ----mean-x and mean-y calculation------

wire [DATA_WIDTH-1:0] mu_x, mu_y;
wire mu_valid_x, mu_valid_y, mu_last_x, mu_last_y, conv_gauss_x_ready, conv_gauss_y_ready;
wire mu_pair_valid = mu_valid_x & mu_valid_y;

wire pair_valid = s_axis_tvalid_x & s_axis_tvalid_y;

CONV_GAUSS #(PIXELS_PER_BEAT, PIXEL_SIZE, IMAGE_DIM) mean_x (aclk, aresetn, s_axis_tdata_x, pair_valid, conv_gauss_x_ready, s_axis_tlast_x, mu_x, mu_valid_x, (advance & mult_x_ready2), mu_last_x);

CONV_GAUSS #(PIXELS_PER_BEAT, PIXEL_SIZE, IMAGE_DIM) mean_y (aclk, aresetn, s_axis_tdata_y, pair_valid, conv_gauss_y_ready, s_axis_tlast_y, mu_y, mu_valid_y, (advance & mult_y_ready2), mu_last_y);

// ----end of mean-x and mean-y calculation------

// -----multiply x and y------
wire [2*DATA_WIDTH-1:0] mult_xy;
wire [PIXELS_PER_BEAT-1:0] mul_xy_valid, mul_xy_last;
wire mul_xy_ready = advance & gauss_xy_ready;

wire [PIXELS_PER_BEAT-1:0] mul1_x_ready;
wire [PIXELS_PER_BEAT-1:0] mul1_y_ready;

genvar j;
generate
    for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult1 (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(s_axis_tdata_x[j*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_x(pair_valid),
            .s_axis_tready_x(mul1_x_ready[j]),
            .s_axis_tlast_x(s_axis_tlast_x),
            .s_axis_tdata_y(s_axis_tdata_y[j*PIXEL_SIZE +:PIXEL_SIZE]),
            .s_axis_tvalid_y(pair_valid),
            .s_axis_tready_y(mul1_y_ready[j]),
            .s_axis_tlast_y(s_axis_tlast_y),
            .m_axis_tdata(mult_xy[j*2*PIXEL_SIZE +: 2*PIXEL_SIZE]),
            .m_axis_tvalid(mul_xy_valid[j]),
            .m_axis_tready(mul_xy_ready),
            .m_axis_tlast(mul_xy_last[j])
        );
    end
endgenerate

wire mult_x_ready1 = &mul1_x_ready;
wire mult_y_ready1= &mul1_y_ready;
wire mult_xy_valid = &mul_xy_valid;
wire mult_xy_last  = &mul_xy_last;

// ----end of multiply x and y------

// ---- mu_x_mu_y calculation ----

wire [2*DATA_WIDTH-1:0] mu_x_mu_y;
wire [PIXELS_PER_BEAT-1:0] mu_x_mu_y_val;
wire [PIXELS_PER_BEAT-1:0] mu_x_mu_y_la;
wire [PIXELS_PER_BEAT-1:0] mul2_x_ready;
wire [PIXELS_PER_BEAT-1:0] mul2_y_ready;

genvar k;
generate
    for (k=0; k<PIXELS_PER_BEAT; k=k+1) begin
        MULTIPLIER #(.DATA_WIDTH(PIXEL_SIZE)) mult2 (
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
            .m_axis_tready(advance),
            .m_axis_tlast(mu_x_mu_y_la[k])
        );
    end
endgenerate

wire mu_x_mu_y_valid = &mu_x_mu_y_val;
wire mu_x_mu_y_last  = &mu_x_mu_y_la;

// ---- end of mu_x_mu_y calculation ----

// ----gauss(xy) calculation------

localparam CONV_GAUSS_INPUT_WIDTH = 2 * PIXEL_SIZE;
wire [CONV_GAUSS_INPUT_WIDTH*PIXELS_PER_BEAT-1:0] out_gauss_xy;
wire out_gauss_xy_valid, out_gauss_xy_last;

CONV_GAUSS #(PIXELS_PER_BEAT, CONV_GAUSS_INPUT_WIDTH, IMAGE_DIM) gauss_xy (aclk, aresetn, mult_xy, mult_xy_valid, gauss_xy_ready, mult_xy_last, out_gauss_xy, out_gauss_xy_valid, advance, out_gauss_xy_last);

// ----end of gauss(xy) calculation------

// ---difference---
integer i;

always @(posedge aclk) begin
    if (~aresetn) begin
        m_axis_tdata <= 0;
    end
    else if(advance & out_gauss_xy_valid & mu_x_mu_y_valid) begin
        for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin
            m_axis_tdata[i*2*PIXEL_SIZE +:2*PIXEL_SIZE] <= $signed(out_gauss_xy[i*2*PIXEL_SIZE +:2*PIXEL_SIZE]) - $signed(mu_x_mu_y[i*2*PIXEL_SIZE +:2*PIXEL_SIZE]);
        end
    end
end     

always @(posedge aclk) begin
    if (~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else if(advance) begin
        m_axis_tvalid <= out_gauss_xy_valid & mu_x_mu_y_valid;
        m_axis_tlast <= (out_gauss_xy_valid & mu_x_mu_y_valid) ? (out_gauss_xy_last & mu_x_mu_y_last) : 0;
    end
end

// ---end of difference---

assign s_axis_tready_x = conv_gauss_x_ready & conv_gauss_y_ready & mult_x_ready1 & mult_y_ready1 & advance & s_axis_tvalid_y;
assign s_axis_tready_y = conv_gauss_x_ready & conv_gauss_y_ready & mult_x_ready1 & mult_y_ready1 & advance & s_axis_tvalid_x;

endmodule