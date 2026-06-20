`timescale 1ns/10ps

module LSU #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM  = 512,
    parameter BIT_WIDTH = 8,
    localparam DATA_WIDTH = PIXELS_PER_BEAT * BIT_WIDTH
) (
    input wire aclk,
    input wire aresetn,

    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire                  s_axis_tvalid,
    output wire                 s_axis_tready,
    input wire                  s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input wire                  m_axis_tready,
    output reg                  m_axis_tlast   
);

localparam MEM_DEPTH = IMAGE_DIM * IMAGE_DIM / PIXELS_PER_BEAT;
localparam ADDR_WIDTH = $clog2(MEM_DEPTH); 

reg [DATA_WIDTH-1:0] ram [MEM_DEPTH-1:0];

reg [ADDR_WIDTH:0] write_ptr, read_ptr;

wire empty = (write_ptr == read_ptr);
wire full  = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]) && (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]);

wire write_step = s_axis_tvalid & s_axis_tready;
wire read_step = m_axis_tready || !m_axis_tvalid;

always @(posedge aclk) begin
    if(~aresetn) begin
        write_ptr <= 0; 
    end
    else if(write_step) begin
        ram[write_ptr[ADDR_WIDTH-1:0]] <= s_axis_tdata;
        write_ptr <= write_ptr + 1;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        read_ptr <= 0;
        m_axis_tdata <= 0;
        m_axis_tvalid <= 1'b0;
        m_axis_tlast <= 1'b0;
    end
    else if (read_step) begin
        if (!empty) begin
            m_axis_tdata <= ram[read_ptr[ADDR_WIDTH-1:0]];
            m_axis_tvalid <= 1'b1;
            m_axis_tlast <= (read_ptr[ADDR_WIDTH-1:0] == (MEM_DEPTH-1));
            read_ptr <= read_ptr + 1;
        end
        else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
    end
end

assign s_axis_tready = !full;

endmodule