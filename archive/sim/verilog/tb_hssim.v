`timescale 1ns/1ps

module tb_HSSIM();

    parameter PIXELS_PER_BEAT = 16;
    parameter INPUT_WIDTH = 8;
    parameter IMAGE_DIM = 512;
    parameter DATA_WIDTH = INPUT_WIDTH * PIXELS_PER_BEAT;

    parameter NUMR_BIT_WIDTH = 36;
    parameter DENR_BIT_WIDTH = 36;

    reg clk;
    reg aresetn;
    reg stall;

    reg [DATA_WIDTH-1:0] old_map;
    reg [DATA_WIDTH-1:0] avg_map;
    reg [DATA_WIDTH-1:0] new_map;

    wire [8*PIXELS_PER_BEAT-1:0] del_out;

    HSSIM #(
        .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
        .INPUT_WIDTH(INPUT_WIDTH),
        .IMAGE_DIM(IMAGE_DIM),
        .NUMR_BIT_WIDTH(NUMR_BIT_WIDTH),
        .DENR_BIT_WIDTH(DENR_BIT_WIDTH)
    ) dut (
        .clk(clk),
        .aresetn(aresetn),
        .stall(stall),
        .old_map(old_map),
        .avg_map(avg_map),
        .new_map(new_map),
        .del_out(del_out)
    );

    initial clk = 0;
    always #1 clk = ~clk;

    integer beat_count = 0;
    integer i,y,z = 0;

    always@(posedge clk) begin
        stall <= $random;
    end

    initial begin
        aresetn = 0;
        stall = 0;
        old_map = 0;
        avg_map = 0;
        new_map = 0;

        // repeat (4) @(posedge clk);
        #8.1 aresetn = 1;

        for (beat_count = 0; beat_count < 400; beat_count = beat_count + 1) begin
            for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
                old_map[i*8+:8] = beat_count[7:0];
                y = beat_count + 1;
                z = beat_count + 2;
                avg_map[i*8+:8] = y[7:0];
                new_map[i*8+:8] = z[7:0];
            end
            @(posedge clk);
        end

    end

endmodule