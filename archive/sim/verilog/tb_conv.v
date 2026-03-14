module conv;
parameter PIXELS_PER_BEAT = 8;
parameter IMAGE_DIM = 64;
parameter DATA_WIDTH = 8*PIXELS_PER_BEAT;

reg clk=0, aresetn=0, stall;
reg [DATA_WIDTH-1:0] inp_frame=64'h0001020304050607;
wire [DATA_WIDTH-1:0] out_frame;

CONV_SOBEL #(PIXELS_PER_BEAT,IMAGE_DIM) dut (clk,aresetn,stall,inp_frame,out_frame);

//CLOCKING
always #1 
    clk <= ~clk;

//STALL
always @(posedge clk)
   stall <= 0;
    // stall <= $random;

//RESET
initial begin
    #4 aresetn = 1;
end

//DATA INPUT
always @(posedge clk) begin
    if(~stall & aresetn)
        inp_frame <= inp_frame + {8{8'h8}};
end



endmodule