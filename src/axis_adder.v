module axis_adder #(
    parameter DATA_WIDTH = 16
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
    output reg [DATA_WIDTH:0] m_axis_tdata,
    output reg                m_axis_tvalid,
    input                     m_axis_tready,
    output reg                m_axis_tlast
);

wire pair_last = s_axis_tlast_x & s_axis_tlast_y;
wire pair_valid = s_axis_tvalid_x & s_axis_tvalid_y;

always@(posedge aclk) begin
    if(!aresetn) begin
        m_axis_tdata <=0;
        m_axis_tvalid <=0;
        m_axis_tlast <=0;
    end
    else begin
        if(pair_valid && (m_axis_tready || !m_axis_tvalid)) begin
            m_axis_tdata <= s_axis_tdata_x + s_axis_tdata_y;
            m_axis_tvalid <= 1;
            m_axis_tlast <= pair_last;
        end
        else if(m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata <=0;
            m_axis_tvalid <=0; 
            m_axis_tlast <=0;
        end 
    end
end

assign s_axis_tready_x = (m_axis_tready || !m_axis_tvalid) && s_axis_tvalid_y;
assign s_axis_tready_y = (m_axis_tready || !m_axis_tvalid) && s_axis_tvalid_x;

endmodule