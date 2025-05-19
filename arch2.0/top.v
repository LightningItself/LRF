module LRF #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter N_FUSE_COUNT = 4,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT,
    parameter OUT_DELAY = 10 //not correct
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

localparam FUSE_COUNT = 1<<N_FUSE_COUNT;
localparam N_IMAGE_DIM  = $clog2(IMAGE_DIM);

localparam STATE_START = 0; //add the incoming frame * 16 to average frame
localparam STATE_NEWFRAME = 1; //calculate new fused frame
localparam STATE_OLDFRAME = 2; //calculate new average frame
reg [1:0] state;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        state <= STATE_START;
    end
    else begin
        
    end
end

reg [N_FUSE_COUNT-1:0] fuse_counter;
reg [N_IMAGE_DIM+1:0] out_delay_counter;

wire step = s_axis_tvalid & s_axis_tready;

//START LOGIC
/***

we send f(n-16) and f(n) every cycle.
for first 15 frames we will send f(0) and f(n).

for first frame, we shall use f(0) as fused and add 16*f(0) to average.
for every next frames, we sub f(0) and add f(n) to average sum.

-> RECEIVE FIRST IMAGE -> store as curr fused image and average image
-> RECEIVE FIRST 16 IMAAGES -> keep updating 
***/


//HANDLE AVERAGE FRAME CALCULATION
reg avg_read_enable, avg_write_enable;
wire [DATA_WIDTH-1:0] avg_frame, avg_write;

// always @(posedge s_axis_aclk) begin
//     if(~stall) begin
//         avg_add <= (avg_frame<<N_FUSE_COUNT) + s_axis_tdata;
//         avg_write <= avg_add - 
//     end
// end

// always @(*) begin
//     if(state == STATE_START)
//         avg_read_enable = s_axis_tlast & step;
//     else 
//         avg_read_enable = step;
//     avg_write_enable = step;
//     if(state == STATE_START) 
//         avg_write = s_axis_tdata;
//     else if(state == STATE_OLDFRAME)
//         avg_write = (avg_frame<<N_FUSE_COUNT)-
// end
// //LSU for current average frame and curr fused frame
// LSU #(PIXELS_PER_BEAT,IMAGE_DIM) avg_frame (clk,aresetn,avg_read_enable,avg_frame,avg_write_enable,avg_write);



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
        if(out_delay_counter < OUT_DELAY-1)
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
