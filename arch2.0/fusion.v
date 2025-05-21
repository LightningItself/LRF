module FUSION #(
    parameter PIXELS_PER_BEAT = 16,
    parameter INPUT_WIDTH = 8,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = INPUT_WIDTH*PIXELS_PER_BEAT
)(
    input clk,
    input aresetn,
    input [DATA_WIDTH-1:0] old_frame,
    input [DATA_WIDTH-1:0] new_frame,
    input [DATA_WIDTH-1:0] old_map,
    input [DATA_WIDTH-1:0] new_map,
    input [DATA_WIDTH-1:0] avg_map,
    output reg [DATA_WIDTH-1:0] fused_frame
);

localparam FRAME_DELAY_VAL = 10;  // hssim module takes 10 cycles to produce del_out

// old,new frame delay block
reg [DATA_WIDTH-1:0] old_frame_sr [FRAME_DELAY_VAL-1:0];
reg [DATA_WIDTH-1:0] new_frame_sr [FRAME_DELAY_VAL-1:0];
reg [DATA_WIDTH-1:0] old_frame_delayed;
reg [DATA_WIDTH-1:0] new_frame_delayed;

integer i;
always@(posedge clk) begin
    if(~stall) begin
        old_frame_sr[0] <= old_frame;
        new_frame_sr[0] <= new_frame;

        for (i=0; i<FRAME_DELAY_VAL; i = i+1) begin
            old_frame_sr[i+1] <= old_frame_sr[i];
            new_frame_sr[i+1] <= new_frame_sr[i];
        end
    end
end

always@(*) begin
    old_frame_delayed <= old_frame_sr[FRAME_DELAY_VAL-1];
    new_frame_delayed <= new_frame_sr[FRAME_DELAY_VAL-1];
end


// HSSIM
wire [DATA_WIDTH-1:0] del_out;

HSSIM #(PIXELS_PER_BEAT, INPUT_WIDTH,IMAGE_DIM) hssim_mod (clk, aresetn, stall, old_map, avg_map, new_map, del_out);

/*
 z= y*d + x*~d
    y = new_frame_delayed
    x = old_frame_delayed
*/

reg [((2*8+1)*PIXELS_PER_BEAT)-1:0] z;
reg [2*8*PIXELS_PER_BEAT-1:0] xd_bar, yd;

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            xd_bar[j*16+:16] <= old_frame_delayed[j*8+:8] * (~del_out[j*8+:8]);
            yd[j*16+:16] <= new_frame_delayed[j*8+:8] * del_out[j*8+:8];
        end
    end
end
endgenerate


generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            z[j*17+:17] <= xd_bar[j*16+:16] + yd[j*16+:16];
        end
    end
end
endgenerate

// delay the already delayed old frame by 2 more cycles for final selection
reg [DATA_WIDTH-1:0] old_frame_delayed_dly1, old_frame_delayed_dly2;
reg [DATA_WIDTH-1:0] del_out_dly1, del_out_dly2;

always@(posedge clk) begin
    if(~stall) begin
        old_frame_delayed_dly1 <= old_frame_delayed;
        old_frame_delayed_dly2 <= old_frame_delayed_dly1;

        del_out_dly1 <= del_out;
        del_out_dly2 <= del_out_dly1;
    end
end

// final fused selection
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always@(posedge clk) begin
        if(~stall) begin
            fused_frame[j*8+:8] <= (del_out_dly2[j*8+:8] == 8'b0) ? old_frame_delayed_dly2[j*8+:8] : (z[j*16+:16]>>8);
        end
    end
end
endgenerate

endmodule