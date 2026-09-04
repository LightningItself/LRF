module axis_buff_4 #(
    parameter DATA_WIDTH = 8
)(
    input  aclk,
    input  aresetn,

    input  [DATA_WIDTH-1:0] s_axis_tdata,
    input                   s_axis_tvalid,
    output                  s_axis_tready,
    input                   s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

wire [DATA_WIDTH-1:0] w1_tdata, w2_tdata;
wire                  w1_tvalid, w2_tvalid;
wire                  w1_tready, w2_tready;
wire                  w1_tlast,  w2_tlast;

axis_buff #(
    .S_AXIS_DATA_WIDTH(DATA_WIDTH),
    .M_AXIS_DATA_WIDTH(DATA_WIDTH)
) buff_1 (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(w1_tdata),
    .m_axis_tvalid(w1_tvalid),
    .m_axis_tready(w1_tready),
    .m_axis_tlast(w1_tlast)
);

axis_buff #(
    .S_AXIS_DATA_WIDTH(DATA_WIDTH),
    .M_AXIS_DATA_WIDTH(DATA_WIDTH)
) buff_2 (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(w1_tdata),
    .s_axis_tvalid(w1_tvalid),
    .s_axis_tready(w1_tready),
    .s_axis_tlast(w1_tlast),
    .m_axis_tdata(w2_tdata),
    .m_axis_tvalid(w2_tvalid),
    .m_axis_tready(w2_tready),
    .m_axis_tlast(w2_tlast)
);

always @(posedge aclk) begin
    if (~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
        m_axis_tdata  <= 0;
    end
    else begin
        if (w2_tvalid & w2_tready) begin
            m_axis_tvalid <= 1;
            m_axis_tdata  <= w2_tdata;
            m_axis_tlast  <= w2_tlast;
        end
        else if (m_axis_tvalid & m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= 0;
        end
    end
end

assign w2_tready = ~m_axis_tvalid | m_axis_tready;

endmodule