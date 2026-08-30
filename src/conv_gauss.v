`timescale 1ns/10ps

module CONV_GAUSS #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE      = 8,
    parameter IMAGE_WIDTH     = 512,
    localparam DATA_WIDTH     = PIXELS_PER_BEAT * PIXEL_SIZE
)(
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    output reg  [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,
    output reg                    m_axis_tlast
);

localparam BUFF_DEPTH    = IMAGE_WIDTH / PIXELS_PER_BEAT;
localparam COL_PTR_WIDTH = $clog2(BUFF_DEPTH);
localparam VERT_WIDTH    = PIXEL_SIZE + 2;

reg [DATA_WIDTH-1:0] buff_top [BUFF_DEPTH-1:0];
reg [DATA_WIDTH-1:0] buff_mid [BUFF_DEPTH-1:0];

wire advance = (m_axis_tready || !m_axis_tvalid);
assign s_axis_tready = advance;

reg [DATA_WIDTH-1:0] tdata_s0;
reg                  tvalid_s0;
reg                  tlast_s0;

always @(posedge aclk) begin
    if (~aresetn) begin
        tdata_s0  <= 0;
        tvalid_s0 <= 0;
        tlast_s0  <= 0;
    end
    else if (advance) begin
        tdata_s0  <= s_axis_tdata;
        tvalid_s0 <= s_axis_tvalid;
        tlast_s0  <= s_axis_tlast;
    end
end

reg [15:0]               row_ptr;
reg [COL_PTR_WIDTH-1:0]  col_ptr;
wire [COL_PTR_WIDTH-1:0] col_ptr_next = col_ptr + 1;

reg [DATA_WIDTH-1:0] buff_top_out;
reg [DATA_WIDTH-1:0] buff_mid_out;

reg [VERT_WIDTH-1:0] vert_s1 [PIXELS_PER_BEAT-1:0];
reg                  valid_s1;
reg                  tlast_s1;
reg                  row_lt2_s1;
reg                  col_zero_s1;

integer p;
always @(posedge aclk) begin
    if (~aresetn) begin
        row_ptr      <= 0;
        col_ptr      <= 0;
        buff_top_out <= 0;
        buff_mid_out <= 0;
        valid_s1     <= 0;
        tlast_s1     <= 0;
        row_lt2_s1   <= 0;
        col_zero_s1  <= 0;
        for (p = 0; p < PIXELS_PER_BEAT; p = p + 1)
            vert_s1[p] <= 0;
    end
    else if (advance) begin
        valid_s1 <= tvalid_s0;
        if (tvalid_s0) begin
            buff_top[col_ptr] <= buff_mid[col_ptr];
            buff_mid[col_ptr] <= tdata_s0;

            buff_top_out <= buff_top[col_ptr_next];
            buff_mid_out <= buff_mid[col_ptr_next];

            col_ptr <= col_ptr + 1;
            if (col_ptr == BUFF_DEPTH - 1)
                row_ptr <= (tlast_s0) ? 0 : row_ptr + 1;

            row_lt2_s1  <= (row_ptr < 2);
            col_zero_s1 <= (col_ptr == 0);
            tlast_s1    <= tlast_s0;

            for (p = 0; p < PIXELS_PER_BEAT; p = p + 1)
                vert_s1[p] <= {2'b0, buff_top_out[p*PIXEL_SIZE +: PIXEL_SIZE]}
                            + ({2'b0, buff_mid_out[p*PIXEL_SIZE +: PIXEL_SIZE]} << 1)
                            + {2'b0, tdata_s0[p*PIXEL_SIZE +: PIXEL_SIZE]};
        end
        else begin
            tlast_s1 <= 1'b0;
        end
    end
end

reg [VERT_WIDTH-1:0] last_vert0, last_vert1;

integer q;
always @(posedge aclk) begin
    if (~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
        m_axis_tdata  <= 0;
        last_vert0    <= 0;
        last_vert1    <= 0;
    end
    else if (advance) begin
        m_axis_tvalid <= valid_s1;
        m_axis_tlast  <= tlast_s1;

        if (valid_s1) begin
            for (q = 0; q < PIXELS_PER_BEAT; q = q + 1) begin
                if (row_lt2_s1 || (col_zero_s1 && q < 2))
                    m_axis_tdata[q*PIXEL_SIZE +: PIXEL_SIZE] <= 0;
                else if (q == 0)
                    m_axis_tdata[q*PIXEL_SIZE +: PIXEL_SIZE] <=
                        ({2'b0, last_vert0} + ({2'b0, last_vert1} << 1) + {2'b0, vert_s1[0]}) >> 4;
                else if (q == 1)
                    m_axis_tdata[q*PIXEL_SIZE +: PIXEL_SIZE] <=
                        ({2'b0, last_vert1} + ({2'b0, vert_s1[0]} << 1) + {2'b0, vert_s1[1]}) >> 4;
                else
                    m_axis_tdata[q*PIXEL_SIZE +: PIXEL_SIZE] <=
                        ({2'b0, vert_s1[q-2]} + ({2'b0, vert_s1[q-1]} << 1) + {2'b0, vert_s1[q]}) >> 4;
            end

            last_vert0 <= vert_s1[PIXELS_PER_BEAT-2];
            last_vert1 <= vert_s1[PIXELS_PER_BEAT-1];
        end
        else begin
            m_axis_tdata <= 0;
        end
    end
end

endmodule