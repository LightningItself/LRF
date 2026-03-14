module axis_buff #(
    parameter S_AXIS_DATA_WIDTH = 8,
    parameter M_AXIS_DATA_WIDTH = 16
)(
    input wire aclk,
    input wire aresetn,
    // AXI-Stream Input
    input wire [S_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    // AXI-Stream Output
    output reg [M_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast
);

always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
        m_axis_tdata <= 0;
    end
    else begin
        if(s_axis_tvalid && s_axis_tready) begin
            m_axis_tvalid <= 1;
            m_axis_tdata <= {M_AXIS_DATA_WIDTH{1'b0}} | s_axis_tdata;
            m_axis_tlast <= s_axis_tlast;
        end
        else if(m_axis_tvalid && m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            m_axis_tdata <= 0;
        end
    end
end

assign s_axis_tready = ~m_axis_tvalid || m_axis_tready;

endmodule