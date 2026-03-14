`timescale 1ns/10ps

module CONV_SOBEL #(
    parameter PIXELS_PER_BEAT = 16,
    parameter IMAGE_DIM = 512,
    parameter DATA_WIDTH = 8*PIXELS_PER_BEAT
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

ROW_BUFF #(PIXELS_PER_BEAT,8,IMAGE_DIM) buff_a (clk,aresetn,buff_a_read_en&~stall,buff_a_write_en,inp_frame,buff_a_out_frame);
ROW_BUFF #(PIXELS_PER_BEAT,8,IMAGE_DIM) buff_b (clk,aresetn,buff_b_read_en&~stall,buff_b_write_en,inp_frame,buff_b_out_frame);
ROW_BUFF #(PIXELS_PER_BEAT,8,IMAGE_DIM) buff_c (clk,aresetn,buff_c_read_en&~stall,buff_c_write_en,inp_frame,buff_c_out_frame);

//DATAPATH
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

reg signed [10:0] conv_sum_x[PIXELS_PER_BEAT-1:0];
reg signed [10:0] conv_sum_y[PIXELS_PER_BEAT-1:0];

reg signed [21:0] conv_sum_x2[PIXELS_PER_BEAT-1:0];
reg signed [21:0] conv_sum_y2[PIXELS_PER_BEAT-1:0];

reg signed [20:0] conv_sum[PIXELS_PER_BEAT-1:0];


wire [10:0] sobel_out[PIXELS_PER_BEAT-1:0];

reg signed [10:0] conv_sum_part1_x, conv_sum_part2_x; //part1 -> sum of 1 row, part2 -> sum of 2 rows
reg signed [10:0] conv_sum_part1_y, conv_sum_part2_y; //part1 -> sum of 1 row, part2 -> sum of 2 rows



//calculate N-2 complete output and 2 partial output
always @(posedge clk) begin
    if(~aresetn) begin
        conv_sum_part1_x <= 0;
        conv_sum_part2_x <= 0;
        conv_sum_part1_y <= 0;
        conv_sum_part2_y <= 0;
    end
    else if(~stall) begin

        //FOR SOBEL_X
        conv_sum_x[0] <= (col_counter==0) ? 0 : conv_sum_part2_x + d_top[(DATA_WIDTH-8)+:8]   + (d_mid[(DATA_WIDTH-8)+:8]<<1)  + d_bot[(DATA_WIDTH-8)+:8];
        conv_sum_x[1] <= (col_counter==0) ? 0 : conv_sum_part1_x + d_top[(DATA_WIDTH-16)+:8]  + (d_mid[(DATA_WIDTH-16)+:8]<<1) + d_bot[(DATA_WIDTH-16)+:8];
        conv_sum_part1_x <= -d_top[0+:8] - (d_mid[0+:8]<<1) - d_bot[0+:8];
        conv_sum_part2_x <= -d_top[8+:8] - (d_mid[8+:8]<<1) - d_bot[8+:8];

        //FOR SOBEL_Y
        conv_sum_y[0] <= (col_counter==0) ? 0 : conv_sum_part2_y - d_top[(DATA_WIDTH-8)+:8]       + d_bot[(DATA_WIDTH-8)+:8];
        conv_sum_y[1] <= (col_counter==0) ? 0 : conv_sum_part1_y - d_top[(DATA_WIDTH-16)+:8]      + d_bot[(DATA_WIDTH-16)+:8]
                                                                - (d_top[(DATA_WIDTH-8)+:8]<<1)  + (d_bot[(DATA_WIDTH-8)+:8]<<1);
                                          
        conv_sum_part1_y <= -d_top[0+:8] + d_bot[0+:8];
        conv_sum_part2_y <= -d_top[8+:8] + d_bot[8+:8]
                            -(d_top[0+:8]<<1) + (d_bot[0+:8]<<1);
    
    end
end

//calculate N-2 complete output and 2 partial output
genvar j;
generate
for(j=0; j<PIXELS_PER_BEAT-2; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            //next N-2 outputs are directly generated

            //FOR SOBEL_X
            conv_sum_x[PIXELS_PER_BEAT-1-j] <=   d_top[(8*j)+:8]      -  d_top[(8*j+16)+:8]     + 
                                                (d_mid[(8*j)+:8]<<1)  - (d_mid[(8*j+16)+:8]<<1) + 
                                                 d_bot[(8*j)+:8]      -  d_bot[(8*j+16)+:8]; 

            //FOR SOBEL_Y
            conv_sum_y[PIXELS_PER_BEAT-1-j] <=  -d_top[(8*j)+:8]     - (d_top[(8*j+8)+:8]<<1) -  d_top[(8*j+16)+:8] + 
                                                 d_bot[(8*j)+:8]     + (d_bot[(8*j+8)+:8]<<1) +  d_bot[(8*j+16)+:8]; 
        end
    end      
end
endgenerate

//calculate squared values of X and Y
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    cordic_0 sqrt(clk,~stall,1,conv_sum[j]>>1,,sobel_out[j]);
    always @(posedge clk) begin
        if(~stall) begin
            conv_sum_x2[j] <= conv_sum_x[j]*conv_sum_x[j];
            conv_sum_y2[j] <= conv_sum_y[j]*conv_sum_y[j];
            conv_sum[j] <= conv_sum_x2[j]+conv_sum_y2[j];
        end
    end      
end
endgenerate

//send final output
generate
for(j=0; j<PIXELS_PER_BEAT; j=j+1) begin
    always @(posedge clk) begin
        if(~stall) begin
            out_frame[(DATA_WIDTH-8*(j+1))+:8] <= (sobel_out[j] > 8'hff) ? 8'hff : sobel_out[j][7:0];
        end
    end
end
endgenerate

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

// 0 1 2
// 40 41 42
//80 81 82