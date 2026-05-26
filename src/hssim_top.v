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


wire advance = (del_ready || !del_valid);
wire hssim_old_avg_x_ready, hssim_old_avg_y_ready, out_valid_x, out_last_x;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_x, denr_x;
wire [PIXELS_PER_BEAT-1:0] numr_sign_x;

HSSIM #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)
) HSSIM_OLD_AVG (
    .aclk(aclk),
    .aresetn(aresetn),
    .map_x(old_map),
    .map_x_valid(old_map_valid),
    .map_x_ready(hssim_old_avg_x_ready),
    .map_x_last(old_map_last),
    .map_y(avg_map),
    .map_y_valid(avg_map_valid),
    .map_y_ready(hssim_old_avg_y_ready),
    .map_y_last(avg_map_last),
    .numr(numr_x),
    .denr(denr_x),
    .numr_sign(numr_sign_x),
    .out_valid(out_valid_x),
    .out_ready(p1_mult_ready_x & p2_mult_ready_y),
    .out_last(out_last_x)
);

wire hssim_avg_new_x_ready, hssim_avg_new_y_ready, out_valid_z, out_last_z;
wire [(2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] numr_z, denr_z;
wire [PIXELS_PER_BEAT-1:0] numr_sign_z;


HSSIM #(.PIXELS_PER_BEAT(PIXELS_PER_BEAT), .PIXEL_SIZE(PIXEL_SIZE), .IMAGE_DIM(IMAGE_DIM)
) HSSIM_AVG_NEW (
    .aclk(aclk),
    .aresetn(aresetn),
    .map_x(avg_map),
    .map_x_valid(avg_map_valid),
    .map_x_ready(hssim_avg_new_x_ready),
    .map_x_last(avg_map_last),
    .map_y(new_map),
    .map_y_valid(new_map_valid),
    .map_y_ready(hssim_avg_new_y_ready),
    .map_y_last(new_map_last),
    .numr(numr_z),
    .denr(denr_z),
    .numr_sign(numr_sign_z),
    .out_valid(out_valid_z),
    .out_ready(p2_mult_ready_x & p1_mult_ready_y),
    .out_last(out_last_z)
);

wire [(2*2*(2*PIXEL_SIZE+2)*PIXELS_PER_BEAT)-1:0] p1, p2;
wire [PIXELS_PER_BEAT-1:0] p1_mult_ready_1, p1_mult_ready_2, p1_valid_1, p1_last_1, p2_mult_ready_1, p2_mult_ready_2, p2_valid_1, p2_last_1;
wire p1_mult_ready_x = &p1_mult_ready_1;
wire p1_mult_ready_y = &p1_mult_ready_2;
wire p1_valid = &p1_valid_1;
wire p1_last = &p1_last_1;
wire p2_mult_ready_x = &p2_mult_ready_1;
wire p2_mult_ready_y = &p2_mult_ready_2;
wire p2_valid = &p2_valid_1;
wire p2_last = &p2_last_1;

genvar i;
generate
    for (i = 0; i < PIXELS_PER_BEAT; i = i+1) begin

        MULTIPLIER #(.DATA_WIDTH(2*(2*PIXEL_SIZE+2))) p1_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(out_valid_x),
            .s_axis_tready_x(p1_mult_ready_1[i]),
            .s_axis_tlast_x(out_last_x),
            .s_axis_tdata_y(denr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(out_valid_z),
            .s_axis_tready_y(p1_mult_ready_2[i]),
            .s_axis_tlast_y(out_last_z),
            .m_axis_tdata(p1[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p1_valid_1[i]),
            .m_axis_tready(comp_ready_x),
            .m_axis_tlast(p1_last_1[i])
        );

        MULTIPLIER #(.DATA_WIDTH(2*(2*PIXEL_SIZE+2))) p2_multiplier (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(numr_z[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_x(out_valid_z),
            .s_axis_tready_x(p2_mult_ready_1[i]),
            .s_axis_tlast_x(out_last_z),
            .s_axis_tdata_y(denr_x[i*2*(2*PIXEL_SIZE+2)+:2*(2*PIXEL_SIZE+2)]),
            .s_axis_tvalid_y(out_valid_x),
            .s_axis_tready_y(p2_mult_ready_2[i]),
            .s_axis_tlast_y(out_last_x),
            .m_axis_tdata(p2[i*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
            .m_axis_tvalid(p2_valid_1[i]),
            .m_axis_tready(comp_ready_y),
            .m_axis_tlast(p2_last_1[i])
        );

    end
endgenerate

reg [PIXELS_PER_BEAT-1:0] numr_sign_x_1;

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_sign_x_1 <= 0;
    end
    else begin
        if(out_valid_x & out_valid_z & p1_mult_ready_x & p1_mult_ready_y) begin
            numr_sign_x_1 <= numr_sign_x;
        end
        else if(p1_valid & comp_ready_x) begin
            numr_sign_x_1 <= 0;
        end
    end
end

reg [PIXELS_PER_BEAT-1:0] numr_sign_z_1;

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_sign_z_1 <= 0;
    end
    else begin
        if(out_valid_x & out_valid_z & p2_mult_ready_x & p2_mult_ready_y) begin
            numr_sign_z_1 <= numr_sign_z;
        end
        else if(p2_valid & comp_ready_y) begin
            numr_sign_z_1 <= 0;
        end
    end
end

wire [PIXELS_PER_BEAT-1:0] s_axis_tready_1, s_axis_tready_2, comp, comp_valid_1, comp_last_1;
wire comp_ready_x = &s_axis_tready_1;
wire comp_ready_y = &s_axis_tready_2;
wire comp_valid = &comp_valid_1;
wire comp_last = &comp_last_1;

genvar j;

generate
    for(j = 0; j < PIXELS_PER_BEAT; j = j+1) begin
        axis_comparator #( .DATA_WIDTH(2*2*(2*PIXEL_SIZE+2))
    ) comp (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_1(p1[j*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
        .s_axis_tvalid_1(p1_valid),
        .s_axis_tready_1(s_axis_tready_1[j]),
        .s_axis_tlast_1(p1_last),
        .s_axis_tdata_2(p2[j*4*(2*PIXEL_SIZE+2)+:4*(2*PIXEL_SIZE+2)]),
        .s_axis_tvalid_2(p2_valid),
        .s_axis_tready_2(s_axis_tready_2[j]),
        .s_axis_tlast_2(p2_last),
        .m_axis_tdata(comp[j]),
        .m_axis_tvalid(comp_valid_1[j]),
        .m_axis_tready(advance),
        .m_axis_tlast(comp_last_1[j])
    );
    end
endgenerate

reg [PIXELS_PER_BEAT-1:0] numr_sign_x_2, numr_sign_z_2;

always @(posedge aclk) begin
    if(!aresetn) begin
        numr_sign_x_2 <= 0;
        numr_sign_z_2 <= 0;
    end
    else begin
        if(p1_valid & p2_valid & comp_ready_x & comp_ready_y) begin
            numr_sign_x_2 <= numr_sign_x_1;
            numr_sign_z_2 <= numr_sign_z_1;
        end
        else if(advance & comp_valid) begin
            numr_sign_x_2 <= 0;
            numr_sign_z_2 <= 0;
        end
    end
end

integer idx;
always @(posedge aclk) begin
    if (!aresetn) begin
        del <= 0;
        del_valid <= 0;
        del_last <= 0;
    end
    else begin
        if (comp_valid & advance) begin
            for (idx = 0; idx < PIXELS_PER_BEAT; idx = idx+1) begin
                if((numr_sign_x_2[idx] == 0) && (numr_sign_z_2[idx] == 0)) begin
                    del[idx*PIXEL_SIZE+:PIXEL_SIZE] <= !comp[idx] ? 8'd255 : 8'd0;
                end
                else if((numr_sign_x_2[idx] == 1) && (numr_sign_z_2[idx] == 0)) begin
                    del[idx*PIXEL_SIZE+:PIXEL_SIZE] <= 8'd255;
                end
                else if((numr_sign_x_2[idx] == 0) && (numr_sign_z_2[idx] == 1)) begin
                    del[idx*PIXEL_SIZE+:PIXEL_SIZE] <= 8'd0;
                end
                else begin
                    del[idx*PIXEL_SIZE+:PIXEL_SIZE] <= comp[idx] ? 8'd255 : 8'd0;
                end
            end
            del_valid <= 1;
            del_last  <= comp_last;
        end
        else if (del_valid & del_ready) begin
            del <= 0;
            del_valid <= 0;
            del_last <= 0;
        end
    end
end

assign old_map_ready = hssim_old_avg_x_ready;
assign avg_map_ready = hssim_old_avg_y_ready & hssim_avg_new_x_ready;
assign new_map_ready = hssim_avg_new_y_ready;

endmodule