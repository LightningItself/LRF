`timescale 1ns/10ps

module axis_skid_buff #(
    parameter DATA_WIDTH = 8
)(
    input                     aclk,
    input                     aresetn,

    input  [DATA_WIDTH-1:0]   s_axis_tdata,
    input                     s_axis_tvalid,
    output                    s_axis_tready,
    input                     s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                        m_axis_tready,
    output reg                  m_axis_tlast
);

reg [DATA_WIDTH-1:0] skid_tdata;
reg                  skid_tlast;
reg                  skid_valid;

always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
        m_axis_tdata  <= 0;
        skid_valid    <= 0;
        skid_tdata    <= 0;
        skid_tlast    <= 0;
    end
    else begin
        if(m_axis_tvalid & m_axis_tready) begin
            if(skid_valid) begin
                m_axis_tdata <= skid_tdata;
                m_axis_tlast <= skid_tlast;
                m_axis_tvalid <= 1'b1;
                skid_valid <= 1'b0;
            end
            else begin
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tlast  <= s_axis_tlast;
            end
        end
        else if(~m_axis_tvalid) begin
            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tdata  <= s_axis_tdata;
            m_axis_tlast  <= s_axis_tlast;
        end
        else if(s_axis_tvalid & s_axis_tready_i & ~m_axis_tready) begin
            skid_tdata <= s_axis_tdata;
            skid_tlast <= s_axis_tlast;
            skid_valid <= 1'b1;
        end
    end
end

wire s_axis_tready_i = ~skid_valid;
assign s_axis_tready = s_axis_tready_i;

endmodule