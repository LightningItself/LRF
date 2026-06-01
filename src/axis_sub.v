`timescale 1ns/10ps

module AXIS_SUB #(
    parameter DATA_WIDTH = 256
)(
    input  wire                  aclk,
    input  wire                  aresetn,
    input  wire [DATA_WIDTH-1:0] s_axis_a_tdata,
    input  wire                  s_axis_a_tvalid,
    output wire                  s_axis_a_tready,
    input  wire                  s_axis_a_tlast,
    input  wire [DATA_WIDTH-1:0] s_axis_b_tdata,
    input  wire                  s_axis_b_tvalid,
    output wire                  s_axis_b_tready,
    input  wire                  s_axis_b_tlast,
    output reg  [DATA_WIDTH:0]   m_axis_tdata,
    output reg                   m_axis_tvalid,
    input  wire                  m_axis_tready,
    output reg                   m_axis_tlast
);

wire advance = (m_axis_tready || !m_axis_tvalid);

assign s_axis_a_tready = advance && s_axis_b_tvalid;
assign s_axis_b_tready = advance && s_axis_a_tvalid;

always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_tdata  <= {(DATA_WIDTH+1){1'b0}};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
    end 
    else begin
        if (s_axis_a_tvalid & s_axis_a_tready & s_axis_b_tvalid & s_axis_b_tready) begin
            m_axis_tdata  <= $signed({1'b0, s_axis_a_tdata}) - $signed({1'b0, s_axis_b_tdata});
            m_axis_tvalid <= 1'b1;
            m_axis_tlast  <= s_axis_a_tlast & s_axis_b_tlast;
        end 
        else if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata  <= {(DATA_WIDTH+1){1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end
    end
end

endmodule