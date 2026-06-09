`timescale 1ns/10ps

module LSU #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM  = 512,
    parameter BIT_WIDTH = 8,
    parameter WRITE_DELAY = 1,
    parameter RW_SHIFT = 1,
    parameter DATA_WIDTH = PIXELS_PER_BEAT*BIT_WIDTH
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

reg [DATA_WIDTH:0] ram [MEM_DEPTH-1:0];
reg [ADDR_WIDTH:0] read_ptr, write_ptr;
reg [$clog2(MEM_DEPTH):0] fill_count; // Elements occupancy tracking counter

wire write_enable = s_axis_tvalid; 

wire output_stage_advance = m_axis_tready || !m_axis_tvalid;
wire data_available = (fill_count > 0);
wire read_enable = data_available && output_stage_advance;

always @(posedge aclk) begin
    if(~aresetn) begin
        write_ptr <= MEM_DEPTH - WRITE_DELAY;
    end
    else if(write_enable) begin
        ram[write_ptr] <= {s_axis_tlast, s_axis_tdata};
        if(write_ptr == MEM_DEPTH - WRITE_DELAY) begin
            write_ptr <= 0;
        end
        else write_ptr <= write_ptr + 1;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        fill_count <= 0;
    end
    else begin
        case ({write_enable, read_enable})
            2'b10: fill_count <= fill_count + 1;
            2'b01: fill_count <= fill_count - 1;
            default: fill_count <= fill_count;
        endcase
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        read_ptr <= RW_SHIFT - WRITE_DELAY;
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end
    else if (output_stage_advance) begin
        if (read_enable) begin
            m_axis_tdata <= ram[read_ptr][DATA_WIDTH-1:0];
            m_axis_tlast <= ram[read_ptr][DATA_WIDTH];
            m_axis_tvalid <= (write_ptr > read_ptr);
            read_ptr <= read_ptr + 1;
        end
        else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
    end
end

assign s_axis_tready = 1'b1;

endmodule