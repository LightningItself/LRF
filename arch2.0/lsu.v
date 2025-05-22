module LSU #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM  = 512,
    parameter BIT_WIDTH = 8,
    parameter WRITE_DELAY = 1,
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

always @(posedge clk) begin
    if(write_enable) begin
        ram[write_ptr] <= write_data;
    end
end

always @(posedge clk) begin
    if(read_enable) begin
        read_data <= ram[read_ptr];
    end
end

always @(posedge clk) begin
    if(~aresetn) begin
        read_ptr <= 1-WRITE_DELAY;
        write_ptr <= -WRITE_DELAY;
    end
    else begin
        read_ptr <= read_ptr+1;
        write_ptr <= write_ptr+1;
    end
end

endmodule