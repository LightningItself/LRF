`timescale 1ns/10ps

module CONV_GAUSS #(
    parameter PIXELS_PER_BEAT = 16,
    parameter INPUT_WIDTH = 8,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = INPUT_WIDTH*PIXELS_PER_BEAT
)(
    input wire clk,
    input wire aresetn,
    input wire stall,
    input wire [DATA_WIDTH-1:0] inp_frame,
    output reg [DATA_WIDTH-1:0] out_frame
);

localparam COUNTER_MAX = IMAGE_DIM/PIXELS_PER_BEAT;
localparam COUNTER_WIDTH = $clog2(COUNTER_MAX);
localparam ROW_COUNTER_WIDTH = $clog2(IMAGE_DIM);

reg [1:0] buff_counter;

//use column and row counters a write pointers
reg [COUNTER_WIDTH-1:0] col_counter;
reg [ROW_COUNTER_WIDTH-1:0] row_counter;
 
reg buff_a_write_en, buff_b_write_en, buff_c_write_en;
reg buff_a_read_en, buff_b_read_en, buff_c_read_en;

//BUFFER WRITE LOGIC
always @(*) begin
    buff_a_write_en = (buff_counter == 0) & ~stall;
    buff_b_write_en = (buff_counter == 1) & ~stall;
    buff_c_write_en = (buff_counter == 2) & ~stall;
end

//BUFFER READ LOGIC
always @(posedge clk) begin
    if(~aresetn) begin
        buff_a_read_en <= 0;
        buff_b_read_en <= 0;
        buff_c_read_en <= 0;
    end
    else if(~stall) begin
        if(col_counter==COUNTER_MAX-2) begin
            buff_a_read_en <= ~(buff_counter==2);
            buff_b_read_en <= ~(buff_counter==0);
            buff_c_read_en <= ~(buff_counter==1);    
        end
    end
end

wire [DATA_WIDTH-1:0] buff_a_out_frame, buff_b_out_frame, buff_c_out_frame;

ROW_BUFF #(PIXELS_PER_BEAT,INPUT_WIDTH,IMAGE_DIM) buff_a (clk,aresetn,buff_a_read_en&~stall,buff_a_write_en,inp_frame,buff_a_out_frame);
ROW_BUFF #(PIXELS_PER_BEAT,INPUT_WIDTH,IMAGE_DIM) buff_b (clk,aresetn,buff_b_read_en&~stall,buff_b_write_en,inp_frame,buff_b_out_frame);
ROW_BUFF #(PIXELS_PER_BEAT,INPUT_WIDTH,IMAGE_DIM) buff_c (clk,aresetn,buff_c_read_en&~stall,buff_c_write_en,inp_frame,buff_c_out_frame);

//DATAPATH

reg [INPUT_WIDTH+4-1:0] conv_sum[PIXELS_PER_BEAT-1:0];
reg [INPUT_WIDTH+4-1:0] conv_sum_part1, conv_sum_part2; //part1 -> sum of 1 row, part2 -> sum of 2 rows

reg [DATA_WIDTH-1:0] d_top, d_mid, d_bot;

always @(*) begin
    case(buff_counter)
        0: begin
            d_top = (row_counter < 2) ? 0 : buff_b_out_frame;
            d_mid = (row_counter < 2) ? 0 : buff_c_out_frame;
        end
        1: begin
            d_top = (row_counter < 2) ? 0 : buff_c_out_frame;
            d_mid = (row_counter < 2) ? 0 : buff_a_out_frame;
        end
        2: begin
            d_top = (row_counter < 2) ? 0 : buff_a_out_frame;
            d_mid = (row_counter < 2) ? 0 : buff_b_out_frame;
        end
        default: begin
            d_top = (row_counter < 2) ? 0 : buff_b_out_frame;
            d_mid = (row_counter < 2) ? 0 : buff_c_out_frame;
        end
    endcase
    d_bot = (row_counter < 2) ? 0 : inp_frame;
end

//calculate N-2 complete output and 2 partial output
always @(posedge clk) begin
    if(~aresetn) begin
        conv_sum_part1 <= 0;
        conv_sum_part2 <= 0;
    end
    else if(~stall) begin
        //first two outputs use previous partial results
        conv_sum[0] <=      conv_sum_part2 + d_top[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH]    + (d_mid[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH]<<1) + d_bot[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH];
        conv_sum[1] <=      conv_sum_part1 + (d_top[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH]<<1) + (d_mid[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH]<<2) + (d_bot[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH]<<1) +
                                             d_top[(DATA_WIDTH-2*INPUT_WIDTH)+:INPUT_WIDTH]    + (d_mid[(DATA_WIDTH-2*INPUT_WIDTH)+:INPUT_WIDTH]<<1) + d_bot[(DATA_WIDTH-2*INPUT_WIDTH)+:INPUT_WIDTH];
        //store last two partial results for calculation in next cycle
       
        conv_sum_part1 <=   d_top[0+:INPUT_WIDTH]        + (d_mid[0+:INPUT_WIDTH]<<1)     +   d_bot[0+:INPUT_WIDTH];
        conv_sum_part2 <=   d_top[INPUT_WIDTH+:INPUT_WIDTH]       + (d_mid[INPUT_WIDTH+:INPUT_WIDTH]<<1)    +   d_bot[INPUT_WIDTH+:INPUT_WIDTH] 
                            + (d_top[0+:INPUT_WIDTH]<<1)          + (d_mid[0+:INPUT_WIDTH]<<2)              +  (d_bot[0+:INPUT_WIDTH]<<1); 
    
    end
end

//calculate N-2 complete output and 2 partial output
genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT-2; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            //next N-2 outputs are directly generated
            conv_sum[PIXELS_PER_BEAT-1-j] <=     d_top[(INPUT_WIDTH*j)+:INPUT_WIDTH]     + (d_top[(INPUT_WIDTH*j+INPUT_WIDTH)+:INPUT_WIDTH]<<1) +  d_top[(INPUT_WIDTH*j+2*INPUT_WIDTH)+:INPUT_WIDTH] + 
                                                (d_mid[(INPUT_WIDTH*j)+:INPUT_WIDTH]<<1) + (d_mid[(INPUT_WIDTH*j+INPUT_WIDTH)+:INPUT_WIDTH]<<2) + (d_mid[(INPUT_WIDTH*j+2*INPUT_WIDTH)+:INPUT_WIDTH]<<1) + 
                                                 d_bot[(INPUT_WIDTH*j)+:INPUT_WIDTH]     + (d_bot[(INPUT_WIDTH*j+INPUT_WIDTH)+:INPUT_WIDTH]<<1) +  d_bot[(INPUT_WIDTH*j+2*INPUT_WIDTH)+:INPUT_WIDTH]; 
        end
    end      
end
endgenerate

//send final output
generate
for(j=2; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            out_frame[(DATA_WIDTH-INPUT_WIDTH*(j+1))+:INPUT_WIDTH] <= conv_sum[j][4+INPUT_WIDTH-1:4];
        end
    end
end
endgenerate
always @(posedge clk) begin
    if(~stall) begin
        out_frame[(DATA_WIDTH-INPUT_WIDTH)+:INPUT_WIDTH] <= (col_counter==1) ? 0 : conv_sum[0][4+INPUT_WIDTH-1:4];
        out_frame[(DATA_WIDTH-2*INPUT_WIDTH)+:INPUT_WIDTH] <= (col_counter==1) ? 0 : conv_sum[1][4+INPUT_WIDTH-1:4];
    end
end

//CONTROL LOGIC
always @(posedge clk) begin
    if(~aresetn) begin
        buff_counter <= 0;
        col_counter  <= 0;
        row_counter  <= 0;
    end
    else if(~stall) begin
        //update counters at end of line
        if(col_counter==COUNTER_MAX-1) begin
            col_counter <= 0;
            row_counter <= row_counter+1;
            if(buff_counter == 2) 
                buff_counter <= 0;
            else 
                buff_counter <= buff_counter+1;
        end
        else begin
            col_counter <= col_counter+1;
        end
    end
end


endmodule