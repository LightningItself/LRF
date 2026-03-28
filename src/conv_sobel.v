`timescale 1ns/10ps

module CONV_SOBEL #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE      = 8,
    parameter IMAGE_WIDTH     = 512,
    parameter DATA_WIDTH      = 8*PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,

    // AXIS input interface
    input [DATA_WIDTH-1:0] s_axis_tdata,
    input                  s_axis_tvalid,
    output                 s_axis_tready,
    input                  s_axis_tlast,

    // AXIS output interface
    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                  m_axis_tvalid,
    input                       m_axis_tready,
    output reg                  m_axis_tlast
);

    localparam BUFF_DEPTH = IMAGE_WIDTH / PIXELS_PER_BEAT;
    localparam COL_PTR_WIDTH = $clog2(BUFF_DEPTH);

    reg [15:0] row_ptr;
    reg [COL_PTR_WIDTH-1:0] col_ptr;
    wire [COL_PTR_WIDTH-1:0] col_ptr_next = col_ptr + 1;

    reg [DATA_WIDTH-1:0] buff_top [BUFF_DEPTH-1:0];
    reg [DATA_WIDTH-1:0] buff_mid [BUFF_DEPTH-1:0];

    reg [2*PIXEL_SIZE-1:0] last_top;
    reg [2*PIXEL_SIZE-1:0] last_mid;
    reg [2*PIXEL_SIZE-1:0] last_bot;

    reg [DATA_WIDTH-1:0] buff_top_out;
    reg [DATA_WIDTH-1:0] buff_mid_out;

    reg signed [10:0] conv_sum_x[PIXELS_PER_BEAT-1:0];
    reg signed [10:0] conv_sum_y[PIXELS_PER_BEAT-1:0];

    reg signed [21:0] conv_sum_x2[PIXELS_PER_BEAT-1:0];
    reg signed [21:0] conv_sum_y2[PIXELS_PER_BEAT-1:0];

    wire advance;
    assign advance = (m_axis_tready || !m_axis_tvalid);

    integer i;

    always @(posedge aclk) begin
        if (!aresetn) begin
            for(i = 0; i < BUFF_DEPTH; i = i + 1) begin
                buff_top[i] <= 0;
                buff_mid[i] <= 0;
            end
        end
    end

    always @(posedge aclk) begin
        if (~aresetn) begin
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;

            row_ptr <= 0;
            col_ptr <= 0;

            buff_top_out <= 0;
            buff_mid_out <= 0;

            last_top <= 0;
            last_mid <= 0;
            last_bot <= 0;
        end
        else begin
            if (s_axis_tvalid && advance) begin
                buff_top[col_ptr] <= buff_mid[col_ptr];
                buff_mid[col_ptr] <= s_axis_tdata;

                buff_top_out <= buff_top[col_ptr_next];
                buff_mid_out <= buff_mid[col_ptr_next];

                col_ptr <= col_ptr_next;
                
                if (col_ptr == BUFF_DEPTH - 1) begin
                    row_ptr <= (s_axis_tlast) ? 0 : row_ptr + 1;
                end

                conv_sum_x[0] <= ((row_ptr < 2 || col_ptr == 0)) ? 0 : (-last_top[0+:PIXEL_SIZE] + buff_top_out[0+:PIXEL_SIZE] 
                                 -(last_mid[0+:PIXEL_SIZE]<<1) + (buff_mid_out[0+:PIXEL_SIZE]<<1)
                                 -last_bot[0+:PIXEL_SIZE] + s_axis_tdata[0+:PIXEL_SIZE]);
                conv_sum_y[0] <= (row_ptr < 2 || col_ptr == 0) ? 0 : (last_top[0+:PIXEL_SIZE] + (last_top[PIXEL_SIZE+:PIXEL_SIZE]<<1) + buff_top_out[0+:PIXEL_SIZE]
                                 -last_bot[0+:PIXEL_SIZE] - (last_bot[PIXEL_SIZE+:PIXEL_SIZE]<<1) - s_axis_tdata[0+:PIXEL_SIZE]);
                
                conv_sum_x[1] <= (row_ptr < 2) ? 0 : (-last_top[PIXEL_SIZE+:PIXEL_SIZE] + buff_top_out[PIXEL_SIZE+:PIXEL_SIZE] 
                                 -(last_mid[PIXEL_SIZE+:PIXEL_SIZE]<<1) + (buff_mid_out[PIXEL_SIZE+:PIXEL_SIZE]<<1)
                                 -last_bot[PIXEL_SIZE+:PIXEL_SIZE] + s_axis_tdata[PIXEL_SIZE+:PIXEL_SIZE]);
                conv_sum_y[1] <= (row_ptr < 2) ? 0 : (last_top[PIXEL_SIZE+:PIXEL_SIZE] + (buff_top_out[0+:PIXEL_SIZE]<<1) + buff_top_out[PIXEL_SIZE+:PIXEL_SIZE]
                                 -last_bot[PIXEL_SIZE+:PIXEL_SIZE] - (s_axis_tdata[0+:PIXEL_SIZE]<<1) - s_axis_tdata[PIXEL_SIZE+:PIXEL_SIZE]);
                
                for(i=2; i<PIXELS_PER_BEAT; i=i+1) begin
                    conv_sum_x[i] <= (row_ptr < 2) ? 0 : (-buff_top_out[(i-2)*PIXEL_SIZE+:PIXEL_SIZE] + buff_top_out[i*PIXEL_SIZE+:PIXEL_SIZE] 
                                     -(buff_mid_out[(i-2)*PIXEL_SIZE+:PIXEL_SIZE]<<1) + (buff_mid_out[i*PIXEL_SIZE+:PIXEL_SIZE]<<1)
                                     - s_axis_tdata[(i-2)*PIXEL_SIZE+:PIXEL_SIZE] + s_axis_tdata[i*PIXEL_SIZE+:PIXEL_SIZE]);
                    conv_sum_y[i] <= (row_ptr < 2) ? 0 : (buff_top_out[(i-2)*PIXEL_SIZE+:PIXEL_SIZE] + (buff_top_out[(i-1)*PIXEL_SIZE+:PIXEL_SIZE]<<1) + buff_top_out[i*PIXEL_SIZE+:PIXEL_SIZE]
                                     - s_axis_tdata[(i-2)*PIXEL_SIZE+:PIXEL_SIZE] - (s_axis_tdata[(i-1)*PIXEL_SIZE+:PIXEL_SIZE]<<1) - s_axis_tdata[i*PIXEL_SIZE+:PIXEL_SIZE]);
                end

                last_top <= buff_top_out[DATA_WIDTH-2*PIXEL_SIZE+:2*PIXEL_SIZE];
                last_mid <= buff_mid_out[DATA_WIDTH-2*PIXEL_SIZE+:2*PIXEL_SIZE];
                last_bot <= s_axis_tdata[DATA_WIDTH-2*PIXEL_SIZE+:2*PIXEL_SIZE];
            end
        end
    end

    genvar j;
    generate
        for (j=0; j<PIXELS_PER_BEAT; j=j+1) begin
            always @(posedge aclk) begin
                if(advance) begin
                    conv_sum_x2[j] <= conv_sum_x[j] * conv_sum_x[j];
                    conv_sum_y2[j] <= conv_sum_y[j] * conv_sum_y[j];
                end
            end
        end
    endgenerate

    reg valid_s1, valid_s2, valid_s3;

    always @(posedge aclk) begin
        if (!aresetn) begin
            valid_s1 <= 0;
            valid_s2 <= 0;
            valid_s3 <= 0;
        end else if(advance) begin
            valid_s1 <= s_axis_tvalid && s_axis_tready;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;
        end
    end

    reg [21:0] conv_sum_reg[PIXELS_PER_BEAT-1:0];
    wire [10:0] sobel_out_wire[PIXELS_PER_BEAT-1:0];
    wire [PIXELS_PER_BEAT-1:0] cordic_valid_out;

    genvar k;
    generate
        for (k=0; k<PIXELS_PER_BEAT; k=k+1) begin : STAGE3
            always @(posedge aclk) begin
                if (advance) begin
                    conv_sum_reg[k] <= conv_sum_x2[k] + conv_sum_y2[k];
                end
            end

            cordic_0 sqrt_inst (
                .aclk(aclk),
                .aclken(advance),
                .s_axis_cartesian_tvalid(valid_s3),
                .s_axis_cartesian_tdata(conv_sum_reg[k] >> 1),
                .m_axis_dout_tvalid(cordic_valid_out[k]),
                .m_axis_dout_tdata(sobel_out_wire[k])
            );
        end
    endgenerate

    generate
        for (j=0; j<PIXELS_PER_BEAT; j=j+1) begin
            always @(posedge aclk) begin
                if(advance) begin
                    m_axis_tdata[j*PIXEL_SIZE+:PIXEL_SIZE] <= (sobel_out_wire[j] > 255) ? 255 : sobel_out_wire[j][7:0];
                end
            end
        end
    endgenerate

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end 
        else if (advance) begin
            m_axis_tvalid <= cordic_valid_out[0];
        end
    end

    localparam TOTAL_LATENCY = 16; 
    reg [TOTAL_LATENCY-1:0] tlast_pipe;

    wire safe_tlast;
    assign safe_tlast = (s_axis_tvalid && s_axis_tready && (s_axis_tlast === 1'b1));

    always @(posedge aclk) begin
        if (!aresetn)
            tlast_pipe <= {TOTAL_LATENCY{1'b0}};
        else if (advance)
            tlast_pipe <= {tlast_pipe[TOTAL_LATENCY-2:0], safe_tlast};
    end

    always @(posedge aclk) begin
        if (!aresetn)
            m_axis_tlast <= 1'b0;
        else if (advance)
            m_axis_tlast <= tlast_pipe[TOTAL_LATENCY-1];
    end

    assign s_axis_tready = advance;

endmodule