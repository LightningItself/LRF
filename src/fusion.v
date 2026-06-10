`timescale 1ns/10ps

// Blending module which does z = y * d + x * (~d)

module FUSION #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter PIXEL_SIZE = 8,
    localparam DATA_WIDTH = PIXEL_SIZE * PIXELS_PER_BEAT
)(
    input aclk,
    input aresetn,
    input [DATA_WIDTH-1:0] old_frame,
    input                  old_frame_tvalid,
    output                 old_frame_tready,
    input                  old_frame_tlast,
    input [DATA_WIDTH-1:0] new_frame,
    input                  new_frame_tvalid,
    output                 new_frame_tready,
    input                  new_frame_tlast,
    input [DATA_WIDTH-1:0] del_gauss,
    input                  del_gauss_tvalid,
    output                 del_gauss_tready,
    input                  del_gauss_tlast,
    output reg [DATA_WIDTH-1:0] fused_frame,
    output reg                  fused_frame_tvalid,
    input                       fused_frame_tready,
    output reg                  fused_frame_tlast
);

// Wire Declarations

wire advance = ( fused_frame_tready || ~fused_frame_tvalid);
wire last = old_frame_tlast & new_frame_tlast & del_gauss_tlast;

wire [DATA_WIDTH-1:0] dbar;

reg [2*DATA_WIDTH-1:0] x_dbar, y_d;
wire [PIXELS_PER_BEAT-1:0] x_dbar_mult_ready_1, x_dbar_mult_ready_2, x_dbar_valid_1, x_dbar_last_1;
wire [PIXELS_PER_BEAT-1:0] y_d_mult_ready_1, y_d_mult_ready_2, y_d_valid_1, y_d_last_1;
wire x_dbar_mult_ready_x = &x_dbar_mult_ready_1;
wire x_dbar_mult_ready_y = &x_dbar_mult_ready_2;
wire x_dbar_valid = &x_dbar_valid_1;
wire x_dbar_last = &x_dbar_last_1;
wire y_d_mult_ready_x = &y_d_mult_ready_1;
wire y_d_mult_ready_y = &y_d_mult_ready_2;
wire y_d_valid = &y_d_valid_1;
wire y_d_last = &y_d_last_1;

wire [((2*PIXEL_SIZE)+2)*PIXELS_PER_BEAT-1:0] int_value;
wire [PIXELS_PER_BEAT-1:0] final_adder_ready_1, final_adder_ready_2, final_adder_ready_3, int_value_valid, int_value_last;
wire final_adder_ready_x = &final_adder_ready_1;
wire final_adder_ready_y = &final_adder_ready_2;
wire final_adder_ready_z = &final_adder_ready_3;
wire adder_ready = final_adder_ready_x & final_adder_ready_y & final_adder_ready_z;
wire final_valid = &int_value_valid;
wire final_last = &int_value_last;

// DataPath

genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin

    assign dbar[j*PIXEL_SIZE+:PIXEL_SIZE] = ~del_gauss[j*PIXEL_SIZE+:PIXEL_SIZE];     // assign dbar[j*9+:9] = {1'b0, ~del_gauss[j*8+:8]}+9'b1;

    MULTIPLIER #( .DATA_WIDTH(PIXEL_SIZE), .mode(0)) x_dbar_mult (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_x(old_frame[j*PIXEL_SIZE+:PIXEL_SIZE]),
        .s_axis_tvalid_x(old_frame_tvalid),
        .s_axis_tready_x(x_dbar_mult_ready_1[j]),
        .s_axis_tlast_x(old_frame_tlast),
        .s_axis_tdata_y(dbar[j*PIXEL_SIZE+:PIXEL_SIZE]),
        .s_axis_tvalid_y(del_gauss_tvalid),
        .s_axis_tready_y(x_dbar_mult_ready_2[j]),
        .s_axis_tlast_y(del_gauss_tlast),
        .m_axis_tdata(x_dbar[j*2*PIXEL_SIZE+:2*PIXEL_SIZE]),
        .m_axis_tvalid(x_dbar_valid_1[j]),
        .m_axis_tready(adder_ready),
        .m_axis_tlast(x_dbar_last_1[j])
    );

    MULTIPLIER #( .DATA_WIDTH(PIXEL_SIZE), .mode(0)) y_d_mult (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata_x(new_frame[j*PIXEL_SIZE+:PIXEL_SIZE]),
        .s_axis_tvalid_x(new_frame_tvalid),
        .s_axis_tready_x(y_d_mult_ready_1[j]),
        .s_axis_tlast_x(new_frame_tlast),
        .s_axis_tdata_y(del_gauss[j*PIXEL_SIZE+:PIXEL_SIZE]),
        .s_axis_tvalid_y(del_gauss_tvalid),
        .s_axis_tready_y(y_d_mult_ready_2[j]),
        .s_axis_tlast_y(del_gauss_tlast),
        .m_axis_tdata(y_d[j*2*PIXEL_SIZE+:2*PIXEL_SIZE]),
        .m_axis_tvalid(y_d_valid_1[j]),
        .m_axis_tready(adder_ready),
        .m_axis_tlast(y_d_last_1[j])
    );

end
endgenerate

genvar k;
generate 
    for(k=0; k<PIXELS_PER_BEAT; k=k+1) begin
        axis_adder #(.DATA_WIDTH(2*PIXEL_SIZE), .mode(0)) final_adder (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_axis_tdata_x(x_dbar[k*2*PIXEL_SIZE+:2*PIXEL_SIZE]),
            .s_axis_tvalid_x(x_dbar_valid),
            .s_axis_tready_x(final_adder_ready_1[k]),
            .s_axis_tlast_x(x_dbar_last),
            .s_axis_tdata_y(y_d[k*2*PIXEL_SIZE+:2*PIXEL_SIZE]),
            .s_axis_tvalid_y(y_d_valid),
            .s_axis_tready_y(final_adder_ready_2[k]),
            .s_axis_tlast_y(y_d_last),
            .s_axis_tdata_z(0),
            .s_axis_tvalid_z(1),
            .s_axis_tready_z(final_adder_ready_3[k]),
            .s_axis_tlast_z(1),
            .m_axis_tdata(int_value[k*((2*PIXEL_SIZE)+2)+:(2*PIXEL_SIZE)+2]),
            .m_axis_tvalid(int_value_valid[k]),
            .m_axis_tready(advance),
            .m_axis_tlast(int_value_last[k])
        );
    end
endgenerate

integer i;
always @(posedge aclk) begin
    if(~aresetn) begin
        fused_frame <= 0;
        fused_frame_tvalid <= 0;
        fused_frame_tlast <= 0;
    end
    else begin
        if(advance & final_valid) begin
            for(i=0; i<PIXELS_PER_BEAT; i=i+1) begin
                fused_frame[i*PIXEL_SIZE+:PIXEL_SIZE] <= (int_value[i*((2*PIXEL_SIZE)+2)+:(2*PIXEL_SIZE)+2]) >>8;
            end
            fused_frame_tvalid <= 1;
            fused_frame_tlast <= final_last;
        end
        else if(fused_frame_tvalid & fused_frame_tready) begin
            fused_frame_tvalid <= 0;
            fused_frame_tlast <= 0;
        end
    end
end

assign old_frame_tready = x_dbar_mult_ready_x & x_dbar_mult_ready_y & y_d_mult_ready_x & y_d_mult_ready_y & new_frame_tvalid & del_gauss_tvalid;
assign new_frame_tready = x_dbar_mult_ready_x & x_dbar_mult_ready_y & y_d_mult_ready_x & y_d_mult_ready_y & del_gauss_tvalid & old_frame_tvalid;
assign del_gauss_tready = x_dbar_mult_ready_x & x_dbar_mult_ready_y & y_d_mult_ready_x & y_d_mult_ready_y & new_frame_tvalid & old_frame_tvalid;

endmodule