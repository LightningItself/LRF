`timescale 1ns/10ps

module AXIS_SUB #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  PIXEL_SIZE      = 8,
    localparam COMP_WIDTH      = 2 * PIXEL_SIZE,
    localparam BUS_WIDTH       = COMP_WIDTH * PIXELS_PER_BEAT,
    localparam DIFF_WIDTH      = COMP_WIDTH + 1,
    localparam OUT_BUS_WIDTH   = DIFF_WIDTH * PIXELS_PER_BEAT
)(
    input                               aclk,
    input                               aresetn,
    input [BUS_WIDTH-1:0]               s_axis_a_tdata,
    input                               s_axis_a_tvalid,
    output                              s_axis_a_tready,
    input                               s_axis_a_tlast,
    input [BUS_WIDTH-1:0]               s_axis_b_tdata,
    input                               s_axis_b_tvalid,
    output                              s_axis_b_tready,
    input                               s_axis_b_tlast,
    output reg signed [OUT_BUS_WIDTH-1:0] m_axis_tdata,
    output reg                             m_axis_tvalid,
    input                                  m_axis_tready,
    output reg                             m_axis_tlast
);

wire out_ready = (m_axis_tready || !m_axis_tvalid);
wire fire      = s_axis_a_tvalid && s_axis_a_tready;
wire pair_last = s_axis_a_tlast & s_axis_b_tlast;

assign s_axis_a_tready = out_ready && s_axis_b_tvalid;
assign s_axis_b_tready = out_ready && s_axis_a_tvalid;

integer i;

always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_tdata  <= {OUT_BUS_WIDTH{1'b0}};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
    end else begin
        if (fire) begin
            for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
                m_axis_tdata[i*DIFF_WIDTH +: DIFF_WIDTH] <= $signed({1'b0, s_axis_a_tdata[i*COMP_WIDTH +: COMP_WIDTH]}) - $signed({1'b0, s_axis_b_tdata[i*COMP_WIDTH +: COMP_WIDTH]});
            end
            m_axis_tvalid <= 1'b1;
            m_axis_tlast  <= pair_last;
        end else if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata  <= {OUT_BUS_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end
    end
end

endmodule