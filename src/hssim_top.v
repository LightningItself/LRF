`timescale 1ns/10ps

module HSSIM_TOP #(
    parameter PIXELS_PER_BEAT = 16,
    parameter PIXEL_SIZE = 8,
    parameter IMAGE_DIM = 512,
    localparam DATA_WIDTH = PIXEL_SIZE*PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    input [DATA_WIDTH-1:0] old_map,
    input                  old_map_valid,
    output                 old_map_ready,
    input                  old_map_last,
    input [DATA_WIDTH-1:0] avg_map,
    input                  avg_map_valid,
    output                 avg_map_ready,
    input                  avg_map_last,
    input [DATA_WIDTH-1:0] new_map,
    input                  new_map_valid,
    output                 new_map_ready,
    input                  new_map_last,
    output reg [PIXEL_SIZE*PIXELS_PER_BEAT-1:0] del,
    output reg              del_valid,
    input                   del_ready,
    output reg              del_last
);

// Wire Declarations 
wire maps_valid = old_map_valid & avg_map_valid & new_map_valid;
wire advance = (del_ready || !del_valid);

wire [((2*(2*(2*PIXEL_SIZE+2))+1)*PIXELS_PER_BEAT)-1:0] hssim_out_old_avg;
wire hssim_old_avg_ready_1, hssim_old_avg_ready_2, hssim_out_old_avg_valid, hssim_out_old_avg_last;

wire [((2*(2*(2*PIXEL_SIZE+2))+1)*PIXELS_PER_BEAT)-1:0] hssim_out_avg_new;
wire hssim_avg_new_ready_1, hssim_avg_new_ready_2, hssim_out_avg_new_valid, hssim_out_avg_new_last;

wire [((2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)-1:0] numr_x, denr_x, numr_z, denr_z;
wire [PIXELS_PER_BEAT-1:0] numr_x_sign, numr_z_sign;

assign numr_x_sign = hssim_out_old_avg[((2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT) + PIXELS_PER_BEAT)- 1:(2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)];
assign numr_x = hssim_out_old_avg[(2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)-1:(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT];
assign denr_x = hssim_out_old_avg[((2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)-1:0];

assign numr_z_sign = hssim_out_avg_new[((2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT) + PIXELS_PER_BEAT)- 1:(2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)];
assign numr_z = hssim_out_avg_new[(2*(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)-1:(2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT];
assign denr_z = hssim_out_avg_new[((2*(2*PIXEL_SIZE+2))*PIXELS_PER_BEAT)-1:0];

wire [(2*2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] p1, p2;
wire [PIXELS_PER_BEAT-1:0] p1_mult_ready_1, p1_mult_ready_2, p1_valid_1, p1_last_1, p2_mult_ready_1, p2_mult_ready_2, p2_valid_1, p2_last_1;
wire p1_mult_ready_x = p1_mult_ready_1[0];
wire p1_mult_ready_y = p1_mult_ready_2[0];
wire p1_valid = p1_valid_1[0];
wire p1_last = p1_last_1[0];
wire p2_mult_ready_x = p2_mult_ready_1[0];
wire p2_mult_ready_y = p2_mult_ready_2[0];
wire p2_valid = p2_valid_1[0];
wire p2_last = p2_last_1[0];

reg [PIXELS_PER_BEAT-1:0] numr_x_sign_1, numr_z_sign_1;

wire [PIXELS_PER_BEAT-1:0] comp_out;
wire [PIXELS_PER_BEAT-1:0] comp_ready_1, comp_ready_2, comp_valid_1, comp_last_1;
wire comp_ready_x = comp_ready_1[0];
wire comp_ready_y = comp_ready_2[0];
wire comp_valid = comp_valid_1[0];
wire comp_last = comp_last_1[0];

reg [PIXELS_PER_BEAT-1:0] numr_x_sign_2, numr_z_sign_2;

reg [PIXELS_PER_BEAT-1:0] numr_x_sign_3,numr_z_sign_3;

// DataPath

wire [DATA_WIDTH-1:0] avg_map_buff_1;
wire avg_map_valid_buff_1, avg_map_last_buff_1, avg_map_buffer_1_ready;

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH)) avg_map_buffer_1(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(avg_map),
    .s_axis_tvalid(maps_valid),
    .s_axis_tready(avg_map_buffer_1_ready),
    .s_axis_tlast(avg_map_last),
    .m_axis_tdata(avg_map_buff_1),
    .m_axis_tvalid(avg_map_valid_buff_1),
    .m_axis_tready(hssim_old_avg_ready_2),
    .m_axis_tlast(avg_map_last_buff_1)
);

wire [DATA_WIDTH-1:0] avg_map_buff_2;
wire avg_map_valid_buff_2, avg_map_last_buff_2, avg_map_buffer_2_ready;

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH)) avg_map_buffer_2(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(avg_map),
    .s_axis_tvalid(maps_valid),
    .s_axis_tready(avg_map_buffer_2_ready),
    .s_axis_tlast(avg_map_last),
    .m_axis_tdata(avg_map_buff_2),
    .m_axis_tvalid(avg_map_valid_buff_2),
    .m_axis_tready(hssim_avg_new_ready_1),
    .m_axis_tlast(avg_map_last_buff_2)
);

wire [DATA_WIDTH-1:0] old_map_buff;
wire old_map_valid_buff, old_map_last_buff, old_map_buffer_ready;

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH)) old_map_buffer(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(old_map),
    .s_axis_tvalid(maps_valid),
    .s_axis_tready(old_map_buffer_ready),
    .s_axis_tlast(old_map_last),
    .m_axis_tdata(old_map_buff),
    .m_axis_tvalid(old_map_valid_buff),
    .m_axis_tready(hssim_old_avg_ready_1),
    .m_axis_tlast(old_map_last_buff)
);

wire [DATA_WIDTH-1:0] new_map_buff;
wire new_map_valid_buff, new_map_last_buff, new_map_buffer_ready;

axis_buff #( .S_AXIS_DATA_WIDTH(DATA_WIDTH), .M_AXIS_DATA_WIDTH(DATA_WIDTH)) new_map_buffer(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(new_map),
    .s_axis_tvalid(maps_valid),
    .s_axis_tready(new_map_buffer_ready),
    .s_axis_tlast(new_map_last),
    .m_axis_tdata(new_map_buff),
    .m_axis_tvalid(new_map_valid_buff),
    .m_axis_tready(hssim_avg_new_ready_2),
    .m_axis_tlast(new_map_last_buff)
);

HSSIM #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) old_avg (
    .aclk(aclk),
    .aresetn(aresetn),
    .map_x(old_map_buff),
    .map_x_valid(old_map_valid_buff),
    .map_x_ready(hssim_old_avg_ready_1),
    .map_x_last(old_map_last_buff),
    .map_y(avg_map_buff_1),
    .map_y_valid(avg_map_valid_buff_1),
    .map_y_ready(hssim_old_avg_ready_2),
    .map_y_last(avg_map_last_buff_1),
    .sign_numr_denr(hssim_out_old_avg),
    .out_valid(hssim_out_old_avg_valid),
    .out_ready(p1_mult_ready_x),
    .out_last(hssim_out_old_avg_last)
);

HSSIM #( .PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)) avg_new (
    .aclk(aclk),
    .aresetn(aresetn),
    .map_x(avg_map_buff_2),
    .map_x_valid(avg_map_valid_buff_2),
    .map_x_ready(hssim_avg_new_ready_1),
    .map_x_last(avg_map_last_buff_2),
    .map_y(new_map_buff),
    .map_y_valid(new_map_valid_buff),
    .map_y_ready(hssim_avg_new_ready_2),
    .map_y_last(new_map_last_buff),
    .sign_numr_denr(hssim_out_avg_new),
    .out_valid(hssim_out_avg_new_valid),
    .out_ready(p1_mult_ready_y),
    .out_last(hssim_out_avg_new_last)
);

genvar i;
generate  
    for (i = 0; i < PIXELS_PER_BEAT; i = i + 1) begin
        MULTIPLIER #( .DATA_WIDTH((2*(2*PIXEL_SIZE+2))), .mode(0)) p1_mul (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(hssim_out_old_avg_valid),
            .s_axis_tready_x(p1_mult_ready_1[i]),
            .s_axis_tlast_x(hssim_out_old_avg_last),
            .s_axis_tdata_y(denr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(hssim_out_avg_new_valid),
            .s_axis_tready_y(p1_mult_ready_2[i]),
            .s_axis_tlast_y(hssim_out_avg_new_last),
            .m_axis_tdata(p1[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p1_valid_1[i]),
            .m_axis_tready(comp_ready_x),
            .m_axis_tlast(p1_last_1[i])
        );

        MULTIPLIER #( .DATA_WIDTH((2*(2*PIXEL_SIZE+2))), .mode(0)) p2_mul (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(hssim_out_avg_new_valid),
            .s_axis_tready_x(p2_mult_ready_1[i]),
            .s_axis_tlast_x(hssim_out_avg_new_last),
            .s_axis_tdata_y(denr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(hssim_out_old_avg_valid),
            .s_axis_tready_y(p2_mult_ready_2[i]),
            .s_axis_tlast_y(hssim_out_old_avg_last),
            .m_axis_tdata(p2[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p2_valid_1[i]),
            .m_axis_tready(comp_ready_x),
            .m_axis_tlast(p2_last_1[i])
        );
    end
endgenerate

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_x_sign_1 <= 0;
        numr_z_sign_1 <= 0;
    end
    else begin
        if(p1_mult_ready_x & hssim_out_old_avg_valid) begin
            numr_x_sign_1 <= numr_x_sign;
            numr_z_sign_1 <= numr_z_sign;
        end
    end
end

genvar j;
generate
    for (j = 0; j < PIXELS_PER_BEAT; j = j + 1) begin
        axis_comparator #( .DATA_WIDTH(2*2*(2*PIXEL_SIZE+2))) comp (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_1(p2[j*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_1(p2_valid),
            .s_axis_tready_1(comp_ready_1[j]),
            .s_axis_tlast_1(p2_last),
            .s_axis_tdata_2(p1[j*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]), 
            .s_axis_tvalid_2(p1_valid),
            .s_axis_tready_2(comp_ready_2[j]),
            .s_axis_tlast_2(p1_last),
            .m_axis_tdata(comp_out[j]), // 1 if p2 > p1 else 0
            .m_axis_tvalid(comp_valid_1[j]),
            .m_axis_tready(advance),
            .m_axis_tlast(comp_last_1[j])
        );
    end
endgenerate

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_x_sign_2 <= 0;
        numr_z_sign_2 <= 0;
        p1_buff_1 <= 0;
        p2_buff_1 <= 0;
        p1_buff_1_valid <= 0;
        p2_buff_1_valid <= 0;
    end
    else begin
        if(comp_ready_x & & p1_valid) begin
            numr_x_sign_2 <= numr_x_sign_1;
            numr_z_sign_2 <= numr_z_sign_1;
            p1_buff_1 <= p1;
            p2_buff_1 <= p2;
            p1_buff_1_valid <= p1_valid;
            p2_buff_1_valid <= p2_valid;
        end
    end
end

reg [(2*2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] p1_buff_1, p2_buff_1, p1_buff_2, p2_buff_2;
reg p1_buff_1_valid, p2_buff_1_valid, p1_buff_2_valid, p2_buff_2_valid;

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_x_sign_3 <= 0;
        numr_z_sign_3 <= 0;
        p1_buff_2 <= 0;
        p2_buff_2 <= 0;
        p1_buff_2_valid <= 0;
        p2_buff_2_valid <= 0;
    end
    else begin
        if(advance | !comp_valid) begin
            numr_x_sign_3 <= numr_x_sign_2;
            numr_z_sign_3 <= numr_z_sign_2;
            p1_buff_2 <= p1_buff_1;
            p2_buff_2 <= p2_buff_1;
            p1_buff_2_valid <= p1_buff_1_valid;
            p2_buff_2_valid <= p2_buff_1_valid;
        end
    end
end

integer k;
always @(posedge aclk) begin
    if(!aresetn) begin
        del <= 0;
        del_valid <= 0;
        del_last <= 0;
    end
    else begin
        for (k = 0; k < PIXELS_PER_BEAT; k = k + 1) begin
            if (comp_valid & advance) begin
                if (numr_x_sign_3[k] == 1'b1 && numr_z_sign_3[k] == 1'b0) begin
                    del[k*PIXEL_SIZE +: PIXEL_SIZE] <= 255;
                end
                else if (numr_x_sign_3[k] == 1'b0 && numr_z_sign_3[k] == 1'b1) begin
                    del[k*PIXEL_SIZE +: PIXEL_SIZE] <= 0;
                end
                else if (numr_x_sign_3[k] == 1'b0 && numr_z_sign_3[k] == 1'b0) begin
                    del[k*PIXEL_SIZE +: PIXEL_SIZE] <= {PIXEL_SIZE{comp_out[k]}};
                end
                else begin
                    if((p1_buff_2[k*4*(2*PIXEL_SIZE+2) +: 4*(2*PIXEL_SIZE+2)] != p2_buff_2[k*4*(2*PIXEL_SIZE+2) +: 4*(2*PIXEL_SIZE+2)]) & p1_buff_2_valid & p2_buff_2_valid) begin
                        del[k*PIXEL_SIZE +: PIXEL_SIZE] <= {PIXEL_SIZE{!comp_out[k]}};
                    end
                    else if((p1_buff_2[k*4*(2*PIXEL_SIZE+2) +: 4*(2*PIXEL_SIZE+2)] == p2_buff_2[k*4*(2*PIXEL_SIZE+2) +: 4*(2*PIXEL_SIZE+2)]) & p1_buff_2_valid & p2_buff_2_valid) begin
                        del[k*PIXEL_SIZE +: PIXEL_SIZE] <= 0;
                    end
                end
            end
            else if (del_ready && del_valid) begin
                del[k*PIXEL_SIZE +: PIXEL_SIZE] <= 0;
            end
        end

        if (comp_valid & advance) begin
            del_valid <= 1'b1;
            del_last <= comp_last;
        end
        else if (del_ready & del_valid) begin
            del_valid <= 1'b0;
            del_last <= 1'b0;
        end
    end
end

assign old_map_ready = old_map_buffer_ready & avg_map_valid & new_map_valid;
assign avg_map_ready = avg_map_buffer_1_ready & old_map_valid & new_map_valid;
assign new_map_ready = new_map_buffer_ready & old_map_valid & avg_map_valid;

endmodule