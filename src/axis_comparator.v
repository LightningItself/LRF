`timescale 1ns/10ps

module axis_comparator #(
    parameter DATA_WIDTH = 72
)(
    input                    aclk,
    input                    aresetn,
    input  [DATA_WIDTH-1:0]  s_axis_tdata_1,
    input                    s_axis_tvalid_1,
    output                   s_axis_tready_1,
    input                    s_axis_tlast_1,
    input  [DATA_WIDTH-1:0]  s_axis_tdata_2,
    input                    s_axis_tvalid_2,
    output                   s_axis_tready_2,
    input                    s_axis_tlast_2,
    output reg               m_axis_tdata,
    output reg               m_axis_tvalid,
    input                    m_axis_tready,
    output reg               m_axis_tlast
);

localparam HALF_WIDTH = DATA_WIDTH / 2;

wire out_ready = m_axis_tready | !m_axis_tvalid;

reg [HALF_WIDTH-1:0] lo1_reg, lo2_reg;
reg                  msb_gt_reg, msb_eq_reg;
reg                  pipe1_valid;
reg                  pipe1_tlast;

wire pipe1_ready = out_ready | !pipe1_valid;

always @(posedge aclk) begin
    if (!aresetn) begin
        pipe1_valid <= 1'b0;
        pipe1_tlast <= 1'b0;
    end 
    else begin
        if (s_axis_tready_1 & s_axis_tvalid_1) begin
            lo1_reg     <= s_axis_tdata_1[HALF_WIDTH-1:0];
            lo2_reg     <= s_axis_tdata_2[HALF_WIDTH-1:0];
            msb_gt_reg  <= (s_axis_tdata_1[DATA_WIDTH-1:HALF_WIDTH] > s_axis_tdata_2[DATA_WIDTH-1:HALF_WIDTH]);
            msb_eq_reg  <= (s_axis_tdata_1[DATA_WIDTH-1:HALF_WIDTH] == s_axis_tdata_2[DATA_WIDTH-1:HALF_WIDTH]);
            pipe1_tlast <= s_axis_tlast_1;
            pipe1_valid <= 1'b1;
        end 
        else if (out_ready) begin
            pipe1_valid <= 1'b0;
        end
    end
end

always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tdata  <= 1'b0;
        m_axis_tlast  <= 1'b0;
    end 
    else if (out_ready) begin
        if (pipe1_valid) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tlast  <= pipe1_tlast;
            m_axis_tdata  <= (msb_gt_reg | (msb_eq_reg & (lo1_reg > lo2_reg))) ? 1'b1 : 1'b0;
        end 
        else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end
    end
end

assign s_axis_tready_1 = pipe1_ready & s_axis_tvalid_2;
assign s_axis_tready_2 = pipe1_ready & s_axis_tvalid_1;

endmodule