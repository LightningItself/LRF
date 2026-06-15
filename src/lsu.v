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
reg [ADDR_WIDTH:0] read_ptr, write_ptr;

wire write_enable = s_axis_tvalid; 

wire output_stage_advance = m_axis_tready || !m_axis_tvalid;
wire data_available = (write_ptr > read_ptr);
wire read_enable = data_available && output_stage_advance;

always @(posedge aclk) begin
    if(~aresetn) begin
        write_ptr <= 0; 
    end
    else if(write_enable) begin
        ram[write_ptr] <= s_axis_tdata;
        write_ptr <= write_ptr + 1;
    end
    else if((write_ptr == MEM_DEPTH) & m_axis_tlast) begin
        write_ptr <= 0;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        read_ptr <= 0;
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else if (output_stage_advance) begin
        if (read_enable) begin
            m_axis_tdata <= ram[read_ptr];
            m_axis_tlast <= (read_ptr == (MEM_DEPTH-1));
            m_axis_tvalid <= (write_ptr > read_ptr);
            if(read_ptr == (MEM_DEPTH-1)) begin
                read_ptr <= 0;
            end
            else read_ptr <= read_ptr + 1;
        end
        else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
    end
end

assign s_axis_tready = 1'b1;

endmodule