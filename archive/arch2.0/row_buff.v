`timescale 1ns/10ps

module ROW_BUFF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_WIDTH = 8,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = PIXEL_WIDTH*PIXELS_PER_BEAT
)(
    input wire clk,
    input wire aresetn,

    input wire read_enable,
    input wire write_enable,
    input wire [DATA_WIDTH-1:0] inp_frame,
    output reg [DATA_WIDTH-1:0] out_frame
);

localparam BUFF_DEPTH = IMAGE_DIM / PIXELS_PER_BEAT;
localparam PTR_WIDTH = $clog2(BUFF_DEPTH);
reg [DATA_WIDTH-1:0] ram [BUFF_DEPTH-1:0];

reg[PTR_WIDTH-1:0] read_ptr, write_ptr;

always @(posedge clk) begin
    if(~aresetn) begin
        read_ptr <= 0;
        write_ptr <= 0;
    end
    else begin
        if(write_enable) begin
            ram[write_ptr] <= inp_frame;
            write_ptr <= write_ptr + 1;
        end
        if(read_enable) begin
            out_frame <= ram[read_ptr];
            read_ptr <= read_ptr + 1;
        end
    end
end

endmodule