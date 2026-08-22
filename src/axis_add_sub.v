`timescale 1ns/10ps
module axis_add_sub #(
    parameter DATA_WIDTH = 16, 
    parameter mode = 0
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
    input [DATA_WIDTH-1:0] s_axis_tdata_z,
    input                  s_axis_tvalid_z,
    output                 s_axis_tready_z,
    input                  s_axis_tlast_z,
    output reg [DATA_WIDTH+1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

reg [DATA_WIDTH:0] sub_stage;
reg [DATA_WIDTH-1:0] z_stage;
reg sub_stage_valid, sub_stage_last;

wire stage2_advance = (m_axis_tready | !m_axis_tvalid);
wire stage1_advance = (stage2_advance | !sub_stage_valid);

always @(posedge aclk) begin
    if(!aresetn) begin
        sub_stage <= 0;
        z_stage <= 0;
        sub_stage_valid <= 0;
        sub_stage_last <= 0;
    end
    else begin
        if(s_axis_tvalid_x & s_axis_tready_x) begin
            sub_stage <= (mode == 0) ? (s_axis_tdata_x - s_axis_tdata_y) : ($signed(s_axis_tdata_x) - $signed(s_axis_tdata_y));
            z_stage <= s_axis_tdata_z;
            sub_stage_valid <= 1;
            sub_stage_last <= s_axis_tlast_x;
        end
        else if(stage2_advance) begin
            sub_stage_valid <= 0;
            sub_stage_last <= 0;
        end
    end
end

always@(posedge aclk) begin
    if(!aresetn) begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else begin
        if(sub_stage_valid & stage2_advance) begin
            m_axis_tdata <= (mode == 0) ? (sub_stage + z_stage) : ($signed(sub_stage) + $signed(z_stage));
            m_axis_tvalid <= 1;
            m_axis_tlast <= sub_stage_last;
        end
        else if(m_axis_tvalid & m_axis_tready) begin
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0; 
            m_axis_tlast <= 0;
        end 
    end
end

assign s_axis_tready_x = stage1_advance & s_axis_tvalid_y & s_axis_tvalid_z;
assign s_axis_tready_y = stage1_advance & s_axis_tvalid_x & s_axis_tvalid_z;
assign s_axis_tready_z = stage1_advance & s_axis_tvalid_x & s_axis_tvalid_y;

endmodule