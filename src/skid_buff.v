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

    output [DATA_WIDTH-1:0] m_axis_tdata,
    output                  m_axis_tvalid,
    input                   m_axis_tready,
    output                  m_axis_tlast
);

reg [DATA_WIDTH-1:0] skid_tdata;
reg                  skid_tlast;
reg                  skid_valid;

always @(posedge aclk) begin
    if(~aresetn) begin
        skid_valid    <= 0;
        skid_tdata    <= 0;
        skid_tlast    <= 0;
    end
    else begin
        if(s_axis_tvalid & ~skid_valid & ~m_axis_tready) begin
            skid_tdata <= s_axis_tdata;
            skid_tlast <= s_axis_tlast;
            skid_valid <= 1;
        end
        else if(skid_valid & m_axis_tready) begin
            skid_tlast <= 0;
            skid_valid <= 0;
        end
    end
end

assign m_axis_tdata = skid_valid ? skid_tdata : s_axis_tdata;
assign m_axis_tvalid = skid_valid | s_axis_tvalid;
assign m_axis_tlast = skid_valid ? skid_tlast : s_axis_tlast;

assign s_axis_tready = ~skid_valid;

endmodule