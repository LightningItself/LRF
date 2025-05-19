module LRF_dummy #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter N_FUSE_COUNT = 4,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT,
    parameter OUT_DELAY = 10 //not correct
) (
    input wire s_axis_aclk,
    input wire s_axis_aresetn,

    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output reg s_axis_tready,
    input wire s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast
);

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tdata  <= 0;
        m_axis_tlast  <= 0;
    end
    else begin
        m_axis_tvalid <= s_axis_tvalid;
        m_axis_tdata  <= s_axis_tdata;
        m_axis_tlast  <= s_axis_tlast;
    end
end
always @(*) begin
    s_axis_tready = m_axis_tready;
end

endmodule