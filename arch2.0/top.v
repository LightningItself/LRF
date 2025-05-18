module LRF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter FUSE_COUNT = 16,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
) (
    input wire s_axis_aclk,
    input wire s_axis_aresetn,

    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output reg s_axis_tready,
    input wire s_axis_tlast,

    output reg [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast
);

localparam N_FUSE_COUNT = $clog2(FUSE_COUNT);
localparam N_IMAGE_DIM  = $clog2(IMAGE_DIM);

reg [N_FUSE_COUNT-1:0] fuse_counter;
reg [N_IMAGE_DIM+1:0] out_delay_counter;

wire step = s_axis_tvalid & s_axis_tready;

//LSU for current average frame and curr fused frame
wire avg_read_enable, avg_write_enable, fused_read_enable_
LSU #() avg_frame ();
LSU #() fused_frame ();






//FUSE COUNTER LOGIC
always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        fuse_counter <= 0;
    end
    else begin
        //increment fuse_counter;
    end
end

//OUT_DELAY LOGIC
always @(posedge s_axis_aclk) begin
    if(s_axis_aresetn) begin
        out_delay_counter <= 0;
    end
    else begin
        out_delay_counter <= out_delay_counter+1;
    end
end

//DATAPATH

//HSSIM(new, ref) -> D1
//HSSIM(curr, ref) -> D2

//FUSION(D1,D2, new)



always @(*) begin
    s_axis_tready = (fuse_counter==FUSE_COUNT-1) ? m_axis_tready : 1;
    m_axis_tvalid = (fuse_counter==FUSE_COUNT-1);
end

endmodule
