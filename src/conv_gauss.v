`timescale 1ns/10ps

module CONV_GAUSS #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE      = 8,
    parameter IMAGE_WIDTH     = 512,
    localparam DATA_WIDTH     = PIXELS_PER_BEAT * PIXEL_SIZE
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    // AXI-Stream Input
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    // AXI-Stream Output
    output reg  [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,
    output reg                    m_axis_tlast
);

localparam BUFF_DEPTH = IMAGE_WIDTH / PIXELS_PER_BEAT;

reg [DATA_WIDTH-1:0] buff_top [BUFF_DEPTH-1:0];
reg [DATA_WIDTH-1:0] buff_mid [BUFF_DEPTH-1:0];

localparam COL_PTR_WIDTH = $clog2(BUFF_DEPTH);

reg [15:0] row_ptr;
reg [COL_PTR_WIDTH-1:0] col_ptr;

wire [COL_PTR_WIDTH-1:0] col_ptr_next = col_ptr + 1;

reg [DATA_WIDTH-1:0] out;
reg [2*PIXEL_SIZE-1:0] last_top;
reg [2*PIXEL_SIZE-1:0] last_mid;
reg [2*PIXEL_SIZE-1:0] last_bot;
reg [DATA_WIDTH-1:0] buff_top_out;
reg [DATA_WIDTH-1:0] buff_mid_out;


integer i;
always @(posedge aclk) begin
    if(~aresetn) begin
        row_ptr <= 0;
        col_ptr <= 0;

        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
        m_axis_tdata <= 0;

        buff_top_out <= 0;
        buff_mid_out <= 0;

        last_top <= 0;
        last_mid <= 0;
        last_bot <= 0;
    end
    else begin
        if(s_axis_tvalid && s_axis_tready) begin
            buff_top[col_ptr] <= buff_mid[col_ptr];
            buff_mid[col_ptr] <= s_axis_tdata;

            buff_top_out <= buff_top[col_ptr_next];
            buff_mid_out <= buff_mid[col_ptr_next];
            
            col_ptr <= col_ptr + 1;
            if(col_ptr == BUFF_DEPTH - 1) begin
                row_ptr <= (s_axis_tlast) ? 0 : row_ptr + 1;
            end

            m_axis_tvalid <= 1;
            m_axis_tdata <= 3; // Placeholder for convolution result

            m_axis_tdata[0 +: PIXEL_SIZE] <= (row_ptr < 2 || col_ptr==0) ? 0 : ((last_top[0+: PIXEL_SIZE]   ) + (last_top[PIXEL_SIZE +: PIXEL_SIZE]<<1) + (buff_top_out[0+: PIXEL_SIZE]   ) + 
                                              (last_mid[0+: PIXEL_SIZE]<<1) + (last_mid[PIXEL_SIZE +: PIXEL_SIZE]<<2) + (buff_mid_out[0+: PIXEL_SIZE]<<1) +
                                              (last_bot[0+: PIXEL_SIZE]   ) + (last_bot[PIXEL_SIZE +: PIXEL_SIZE]<<1) + (s_axis_tdata[0+: PIXEL_SIZE]   )) >> 4;

            m_axis_tdata[PIXEL_SIZE +: PIXEL_SIZE] <= (row_ptr < 2 || col_ptr==0) ? 0 : ((last_top[PIXEL_SIZE +: PIXEL_SIZE]   ) + (buff_top_out[0 +: PIXEL_SIZE]<<1) + (buff_top_out[PIXEL_SIZE+: PIXEL_SIZE]   ) + 
                                                       (last_mid[PIXEL_SIZE +: PIXEL_SIZE]<<1) + (buff_mid_out[0 +: PIXEL_SIZE]<<2) + (buff_mid_out[PIXEL_SIZE+: PIXEL_SIZE]<<1) +
                                                       (last_bot[PIXEL_SIZE +: PIXEL_SIZE]   ) + (s_axis_tdata[0 +: PIXEL_SIZE]<<1) + (s_axis_tdata[PIXEL_SIZE+: PIXEL_SIZE]   )) >> 4;
            for(i = 2; i < PIXELS_PER_BEAT; i = i + 1) begin
                m_axis_tdata[i*PIXEL_SIZE +: PIXEL_SIZE] <= (row_ptr < 2) ? 0 : ((buff_top_out[(i-2)*PIXEL_SIZE +: PIXEL_SIZE]) + (buff_top_out[(i-1)*PIXEL_SIZE +: PIXEL_SIZE]<<1) + (buff_top_out[i*PIXEL_SIZE +: PIXEL_SIZE]) + 
                                                            (buff_mid_out[(i-2)*PIXEL_SIZE +: PIXEL_SIZE]<<1) + (buff_mid_out[(i-1)*PIXEL_SIZE +: PIXEL_SIZE]<<2) + (buff_mid_out[i*PIXEL_SIZE +: PIXEL_SIZE]<<1) +
                                                            s_axis_tdata[(i-2)*PIXEL_SIZE +: PIXEL_SIZE] + (s_axis_tdata[(i-1)*PIXEL_SIZE +: PIXEL_SIZE]<<1) + s_axis_tdata[i*PIXEL_SIZE +: PIXEL_SIZE]) >> 4;
            end
            last_top <= buff_top[col_ptr][DATA_WIDTH-1 -: 2*PIXEL_SIZE];
            last_mid <= buff_mid[col_ptr][DATA_WIDTH-1 -: 2*PIXEL_SIZE];
            last_bot <= s_axis_tdata[DATA_WIDTH-1 -: 2*PIXEL_SIZE];
            
            m_axis_tlast <= s_axis_tlast;
        end
        else if(m_axis_tvalid && m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            m_axis_tdata <= 0;
        end
    end
end

assign s_axis_tready = (~m_axis_tvalid || m_axis_tready);

endmodule