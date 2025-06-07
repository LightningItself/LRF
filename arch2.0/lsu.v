`timescale 1ns/10ps

module LSU #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM  = 512,
    parameter BIT_WIDTH = 8,
    parameter WRITE_DELAY = 1,
    parameter RW_SHIFT = 1,
    parameter DATA_WIDTH = PIXELS_PER_BEAT*BIT_WIDTH
) (
    input wire clk,
    input wire aresetn,

    input wire read_enable,
    output reg [DATA_WIDTH-1:0] read_data,

    input wire write_enable,
    input wire [DATA_WIDTH-1:0] write_data    
);

localparam MEM_DEPTH = IMAGE_DIM * IMAGE_DIM / PIXELS_PER_BEAT;
localparam ADDR_WIDTH = $clog2(MEM_DEPTH);

reg [DATA_WIDTH-1:0] ram [MEM_DEPTH-1:0];
reg [ADDR_WIDTH-1:0] read_ptr, write_ptr;

// reduce read and write enables into single transition.

always @(posedge clk) begin
    if(~aresetn)
        write_ptr <= -WRITE_DELAY;
    else if(write_enable) begin
        ram[write_ptr] <= write_data;
        write_ptr <= write_ptr+1;
    end
end

always @(posedge clk) begin
    if(~aresetn)
        read_ptr <= RW_SHIFT-WRITE_DELAY;
    else if(read_enable) begin
        read_data <= ram[read_ptr];
        read_ptr <= read_ptr+1;
    end
end

endmodule