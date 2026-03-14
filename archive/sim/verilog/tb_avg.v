`timescale 1ns/10ps

module TB_AVG;
parameter PIXELS_PER_BEAT = 8;
parameter IMAGE_DIM = 16;
parameter N_FUSE_COUNT = 4;
parameter DATA_WIDTH = 8*PIXELS_PER_BEAT;
parameter BEATS_PER_IMAGE = IMAGE_DIM*IMAGE_DIM/PIXELS_PER_BEAT;

reg clk=0, aresetn=0, stall;
reg [DATA_WIDTH-1:0] inp_frame=64'h0001020304050607;
wire [DATA_WIDTH-1:0] out_frame;

reg s_tvalid,s_tlast,m_tready;
wire m_tvalid,m_tlast,s_tready;

LRF #(
    PIXELS_PER_BEAT,
    IMAGE_DIM,
    N_FUSE_COUNT
) dut (
    clk,aresetn,inp_frame,1,s_tready,s_tlast,out_frame,m_tvalid,1,m_tlast
);


//CLOCKING
always #1 
    clk <= ~clk;

//STALL
always @(posedge clk)
   stall <= 0;
    // stall <= $random;

//RESET
initial begin
    #3.1 aresetn = 1;
end

//DATA INPUT
reg [63:0] data_counter = 0;
always @(posedge clk) begin
    if(aresetn) begin
        inp_frame <= inp_frame + {8{8'h8}};
        data_counter <= data_counter + 1;
    end
end

always @*
    s_tlast = data_counter == BEATS_PER_IMAGE-1;


endmodule