`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:16:40 AM
// Design Name: 
// Module Name: FusionTop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/***
UPDATES:

Added valid chain 
***/

module FusionTop #(
parameter   HIM_LEN=520, 
            HIM_WID=520,  
            HNO_IMAGES=16,
            INPUT_DATA_WIDTH = 32,
            OUTPUT_DATA_WIDTH = 32,
            DATA_WIDTH = 8,
            LOG2_NO_OF_IMAGES = 4,
            PIPELINE_LATENCY = 20
)(  
    input wire                          axi_clk,
    input wire                          axi_aresetn,
    input wire                          s_axis_tvalid,
    input wire [INPUT_DATA_WIDTH-1:0]   s_axis_tdata,
    output reg                          s_axis_tready,
    output reg                          m_axis_tvalid,
    output reg [OUTPUT_DATA_WIDTH-1:0]  m_axis_tdata,
    input wire                          m_axis_tready,
    output reg                          m_axis_tlast
);

    reg [OUTPUT_DATA_WIDTH-1:0] m_axis_output_reg;

    // Input & computation pipeline
    wire [DATA_WIDTH-1:0] avg_image, new_image, fused_image, old_image, new_average_delayed_more20;
    wire [DATA_WIDTH-1:0] new_fused_image;
    wire [OUTPUT_DATA_WIDTH-1:0] output_data;
    wire done_pr2;

    reg [DATA_WIDTH+LOG2_NO_OF_IMAGES+1:0] mult_result;
    reg [DATA_WIDTH-1:0] new_average_reg;

    assign avg_image   = s_axis_tdata[7:0];
    assign new_image   = s_axis_tdata[15:8];
    assign fused_image = s_axis_tdata[23:16];
    assign old_image   = s_axis_tdata[31:24];

    wire ovalid, olast; //validity of value in last stage of the hfusion pipeline
    wire step = (s_axis_tvalid & m_axis_tready);
    wire gated_clk = axi_clk & step;

    //2 stage avg calculation
    always @(posedge gated_clk) begin
        if (~axi_reset_n) begin
            mult_result <= 0;
            new_average_reg <= 0;
        end
        else begin
            mult_result <= (avg_image<<LOG2_NO_OF_IMAGES)+new_image;
            new_average_reg <= (mult_result - old_image)>>LOG2_NO_OF_IMAGES;
        end
    end
    
    
    
    //18 more delay stages for avg calculation
    hmultipledelay #(DATA_WIDTH,8'd18) hod_fuse1 (gated_clk,~axi_reset_n,new_average_reg,new_average_delayed_more20);
    hfusion #(DATA_WIDTH,HIM_LEN) hfusion_inst (gated_clk,~axi_reset_n,fused_image,new_image,avg_image,new_fused_image,done_pr2);

    always @(*) begin
        s_axis_tready = step;
        m_axis_tvalid = ovalid;
        m_axis_tdata = {16'h0000, new_average_delayed_more20, new_fused_image};
        m_axis_tlast = olast;
    end
    
endmodule
