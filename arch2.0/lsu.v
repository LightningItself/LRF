module LSU #(
    parameter IMAGE_DIM  = 512,
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 14
) (
    input wire clk,
    input wire aresetn,

    input wire read_enable,
    output reg [DATA_WIDTH-1:0] read_data,

    input wire write_enable,
    input wire [DATA_WIDTH-1:0] write_data    
);
localparam PIXELS_PER_BEAT = 16;
localparam MEM_DEPTH = IMAGE_DIM * IMAGE_DIM / PIXELS_PER_BEAT;
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
        read_ptr <= 0;
        write_ptr <= 0;
    end
    else begin
        read_ptr <= read_ptr+1;
        write_ptr <= write_ptr+1;
    end
end

endmodule