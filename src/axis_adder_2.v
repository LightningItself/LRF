`timescale 1ns/10ps

module axis_adder_2 #(
    parameter DATA_WIDTH = 16, 
    parameter mode = 0 // 0 - unsigned addition, 1- signed addition
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
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

wire advance = (m_axis_tready | !m_axis_tvalid);

always@(posedge aclk) begin
    if(!aresetn) begin
        m_axis_tdata <=0;
        m_axis_tvalid <=0;
        m_axis_tlast <=0;
    end
    else begin
        if(s_axis_tvalid_x & s_axis_tready_x) begin
            if(mode == 0) begin
                m_axis_tdata <= s_axis_tdata_x + s_axis_tdata_y;
            end
            else begin
                m_axis_tdata <= $signed(s_axis_tdata_x) + $signed(s_axis_tdata_y);
            end
            m_axis_tvalid <= 1;
            m_axis_tlast <= s_axis_tlast_x;
        end
        else if(m_axis_tvalid & m_axis_tready) begin
            m_axis_tdata <=0;
            m_axis_tvalid <=0; 
            m_axis_tlast <=0;
        end 
    end
end

assign s_axis_tready_x = advance & s_axis_tvalid_y;
assign s_axis_tready_y = advance & s_axis_tvalid_x;

endmodule