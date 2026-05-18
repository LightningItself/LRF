`timescale 1ns/10ps

module AXIS_SUB #(
    parameter  PIXELS_PER_BEAT = 16,
    parameter  PIXEL_SIZE      = 8,
    localparam COMP_WIDTH      = 2 * PIXEL_SIZE,
    localparam BUS_WIDTH       = COMP_WIDTH * PIXELS_PER_BEAT,
    localparam DIFF_WIDTH      = COMP_WIDTH + 1  // 17-bit signed to prevent truncation
)(
    input  wire                        aclk,
    input  wire                        aresetn,

    input  wire [BUS_WIDTH-1:0]        s_axis_a_tdata,
    input  wire                        s_axis_a_tvalid,
    output wire                        s_axis_a_tready,
    input  wire                        s_axis_a_tlast,

    input  wire [BUS_WIDTH-1:0]        s_axis_b_tdata,
    input  wire                        s_axis_b_tvalid,
    output wire                        s_axis_b_tready,
    input  wire                        s_axis_b_tlast,

    output reg  signed [BUS_WIDTH-1:0] m_axis_tdata,
    output reg                         m_axis_tvalid,
    input  wire                        m_axis_tready,
    output reg                         m_axis_tlast
);

wire out_ready = (m_axis_tready || !m_axis_tvalid);
wire fire = s_axis_a_tvalid && s_axis_a_tready;
wire pair_last = s_axis_a_tlast & s_axis_b_tlast;

reg signed [DIFF_WIDTH-1:0] diff_reg [0:PIXELS_PER_BEAT-1]; // 17-bit signed
reg                         diff_valid;
reg                         diff_last;

wire out_ready_d = (m_axis_tready || !m_axis_tvalid);

integer i;
always @(posedge aclk) begin
    if (!aresetn) begin
        diff_valid <= 1'b0;
        diff_last  <= 1'b0;
        for (i = 0; i < PIXELS_PER_BEAT; i = i + 1)
            diff_reg[i] <= {DIFF_WIDTH{1'b0}};
    end
    else begin
        if (fire) begin
            for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
                diff_reg[i] <= $signed({1'b0, s_axis_a_tdata[i*COMP_WIDTH +: COMP_WIDTH]})
                                 - $signed({1'b0, s_axis_b_tdata[i*COMP_WIDTH +: COMP_WIDTH]});
            end
            diff_valid <= 1'b1;
            diff_last  <= pair_last;
        end
        else if (diff_valid && out_ready_d) begin
            diff_valid <= 1'b0;
            diff_last  <= 1'b0;
        end
    end
end

localparam signed [DIFF_WIDTH-1:0] SAT_MAX =  { {(DIFF_WIDTH-COMP_WIDTH){1'b0}}, 1'b0, {(COMP_WIDTH-1){1'b1}} }; // +32767
localparam signed [DIFF_WIDTH-1:0] SAT_MIN =  { {(DIFF_WIDTH-COMP_WIDTH){1'b1}}, 1'b1, {(COMP_WIDTH-1){1'b0}} }; // -32768

always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_tdata  <= {BUS_WIDTH{1'b0}};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
    end
    else begin
        if (diff_valid && out_ready_d) begin
            for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
                if(diff_reg[i] > SAT_MAX)
                    m_axis_tdata[i*COMP_WIDTH +: COMP_WIDTH] <= SAT_MAX[COMP_WIDTH-1:0];
                else if (diff_reg[i] < SAT_MIN)
                    m_axis_tdata[i*COMP_WIDTH +: COMP_WIDTH] <= SAT_MIN[COMP_WIDTH-1:0];
                else
                    m_axis_tdata[i*COMP_WIDTH +: COMP_WIDTH] <= diff_reg[i][COMP_WIDTH-1:0];
            end
            m_axis_tvalid <= diff_valid;
            m_axis_tlast  <= diff_last;
        end
        else if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata  <= {BUS_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end
    end
end
wire stage1_ready = !diff_valid || out_ready_d;

assign s_axis_a_tready = stage1_ready && s_axis_b_tvalid;
assign s_axis_b_tready = stage1_ready && s_axis_a_tvalid;
endmodule