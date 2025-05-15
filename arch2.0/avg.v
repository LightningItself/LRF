module AVG #(
    parameter IMAGE_DIM  = 512,
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 14
)(
    input wire clk,
    input wire aresetn,
    input wire stall,

    input wire [DATA_WIDTH-1:0] idata,
    output reg [DATA_WIDTH-1:0] odata

);

localparam STATE_UNSET = 0;
localparam STATE_SET   = 1;
reg state;

reg [ADDR_WIDTH-1:0] read_ptr, write_ptr;

always @(posedge clk) begin
    if(~aresetn) begin
        state <= STATE_UNSET;
        read_ptr <= 0;
        write_ptr <= 0;
    end
    else if(~stall) begin
        case (state)
            STATE_UNSET: begin
                
            end
            STATE_SET: begin
                
            end
        endcase
    end
end
wire read_enable, write_enable;
reg [ADDR_WIDTH-1:0] read_ptr, write_ptr;
lsu #(IMAGE_DIM,DATA_WIDTH,ADDR_WIDTH) bram (clk,read_enable,read_ptr,read_data,write_enable,write_ptr,write_data);

endmodule