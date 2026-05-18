`timescale 1ns/10ps

module AXIS_SUB #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  PIXEL_SIZE      = 8,
    localparam COMP_WIDTH      = 2 * PIXEL_SIZE,
    localparam BUS_WIDTH       = COMP_WIDTH * PIXELS_PER_BEAT
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire [BUS_WIDTH-1:0]   s_axis_a_tdata,
    input  wire                   s_axis_a_tvalid,
    output wire                   s_axis_a_tready,
    input  wire                   s_axis_a_tlast,

    input  wire [BUS_WIDTH-1:0]   s_axis_b_tdata,
    input  wire                   s_axis_b_tvalid,
    output wire                   s_axis_b_tready,
    input  wire                   s_axis_b_tlast,

    output reg  signed [BUS_WIDTH-1:0] m_axis_tdata,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,
    output reg                    m_axis_tlast
);

wire pair_last = s_axis_a_tlast & s_axis_b_tlast;

integer i;

always @(posedge aclk) begin
    if (~aresetn) begin
        m_axis_tdata  <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
    end 
    else begin 
        if (s_axis_a_tready && s_axis_b_tready) begin
            for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
                m_axis_tdata[i*COMP_WIDTH +: COMP_WIDTH] <= $signed($signed({1'b0, s_axis_a_tdata[i*COMP_WIDTH +: COMP_WIDTH]}) - $signed({1'b0, s_axis_b_tdata[i*COMP_WIDTH +: COMP_WIDTH]}));
            end
            m_axis_tvalid <= 1;
            m_axis_tlast  <= pair_last;
        end
        else if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata  <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
        end
    end
end

assign s_axis_a_tready = (m_axis_tready || !m_axis_tvalid) && s_axis_b_tvalid;
assign s_axis_b_tready = (m_axis_tready || !m_axis_tvalid) && s_axis_a_tvalid;

endmodule