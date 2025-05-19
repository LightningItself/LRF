`timescale 1ns / 1ps

/*
new image   -> fetched from DDR, I(n)
old image   -> fetched from DDR, I(n - 16)
avg of 16   -> stored in BRAM (updates after each fusion)
fused image -> stored in BRAM for 15 cycles and written to DDR in 16th cycle
*/

module fusionTop #(
    parameter IM_LEN              = 520, 
    parameter IM_WID              = 520,  
    parameter NO_IMAGES           = 16,
    parameter DATA_WIDTH          = 128,
    parameter NO_PARALLEL_UNITS   = 4,
    parameter LOG2_NO_OF_IMAGES   = 4,
    parameter PIPELINE_LATENCY    = 20
)(  
    input wire                          s_axis_clk,
    input wire                          s_axis_aresetn,

    input wire [DATA_WIDTH-1:0]         s_axis_tdata, 
    input wire                          s_axis_tvalid,
    output reg                          s_axis_tready,
    input wire                          s_axis_tlast,

    output reg [DATA_WIDTH-1:0]         m_axis_tdata,
    output reg                          m_axis_tvalid,
    input wire                          m_axis_tready,
    output reg                          m_axis_tlast
);

localparam STATE_AVG = 0;
localparam STATE_NEW = 1;
reg state;                                  //first calculate average image, then calculate next frame  

reg [3:0] curr_frame;                       //which frame out of 16 is currently being fused


always @(posedge s_axis_clk) begin
    if(~s_axis_aresetn) begin
        state <= STATE_AVG;
        curr_frame <= 0;

    end
end


//PIPELINED DATAPATH

//Calculate edgemap of incoming frame
wire [DATA_WIDTH-1:0] edge_frame;
assign edge_frame = s_axis_tdata; //TODO: replace with conv unit to calculate edgemap

//If in STATE_AVG, use edge_frame 
    
endmodule