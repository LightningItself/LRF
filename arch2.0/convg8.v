`timescale 1ns / 1ps

module convg8 #(parameter IM_LEN = 16'd520, ker = 8'd3, NO_PARALLEL_UNITS = 4 ) (
    input clk,
    input res,
    input [NO_PARALLEL_UNITS*8 - 1:0] data_in,
    input clrbuffer,
    input [ker-2:0] rowend,
    output [NO_PARALLEL_UNITS*8 - 1:0] data_out,
    input stall
    );
    integer i,p;

    // parameter hbuffend=(IM_LEN+1)*(ker-1);
    reg [14:0] buff [0:(IM_LEN+1)*(ker-1)-1];

    reg [7:0] in [NO_PARALLEL_UNITS-1 : 0];
    wire [7:0] out [NO_PARALLEL_UNITS-1 : 0];
    reg [14:0] temp_out [NO_PARALLEL_UNITS-1 : 0];


    wire [8:0] temp_times2 [NO_PARALLEL_UNITS-1 : 0];
    wire [11:0] temp_times16 [NO_PARALLEL_UNITS-1 : 0];
    wire [9:0] temp_times3 [NO_PARALLEL_UNITS-1 : 0];
    wire [11:0] temp_times14 [NO_PARALLEL_UNITS-1 : 0];
    wire [13:0] temp_times60 [NO_PARALLEL_UNITS-1 : 0];

    wire clrbuffer_delayedbyone;

    wire [1:0] rowend_new [NO_PARALLEL_UNITS - 1 : 0];

    genvar k;
    generate
        for (k = 0; k < NO_PARALLEL_UNITS; k = k+1) begin
            in[k] = data_in[8*k-1 +: 8]
        end
    endgenerate

    generate
        for (k = 0; k < NO_PARALLEL_UNITS; k = k+1) begin
            data_out[8*k-1 +: 8] = out[k]
        end
    endgenerate

    generate
        for (k = 0; k < NO_PARALLEL_UNITS; k = k+1) begin
            if (k == 0) begin
                assign rowend_new[k] = rowend; // use actual rowend values
            end else begin
                assign rowend_new[k] = 2'b00;     // append zeros in the last 2
            end
        end
    endgenerate

    //honedelay #(1'b1) hod_hclrbffr (clk,res,clrbuffer,clrbuffer_delayedbyone);

    always@(posedge clk) begin
        if(res | clrbuffer) begin
            for(i = 0; i < (IM_LEN+1)*(ker-1); i = i+1) begin
                buff[i] <= 'd0;
                temp_out[i] <= 'd0;     
            end
        end
       
        else begin
            for(p = 0; p < ker-1; p = p+1) begin   // KEEP ON PASSING VALUES
                for(i = 3; i < IM_LEN; i = i+1) begin
                    buff[p*IM_LEN+i] <= buff[p*IM_LEN+i-1];
                end
            end
 
            for (i = 0; i < NO_PARALLEL_UNITS; i = i+1) begin
                buff[0 + i] <= (rowend[i][0] & rowend[i][1]) ? temp_times3[i] : 15'd0;
                buff[1 + i] <= (rowend[i][0]) ? (buff[0 + i] + temp_times14[i]) : buff[0 + i];
                buff[2 + i] <= (buff[1 + i] + temp_times3[i]);

                buff[IM_LEN + i] <= (rowend[i][0] & rowend[i][1]) ? (buff[IM_LEN-1 + i] + temp_times14[i]) : buff[IM_LEN-1 + i];
                buff[IM_LEN + 1 + i] <= (rowend[i][0]) ? (buff[IM_LEN] + temp_times60[i]) : buff[IM_LEN + i];
                buff[IM_LEN + 2 + i] <= (buff[IM_LEN+1 + i] + temp_times14[i]);

                buff[(IM_LEN+1)*(ker-1)-1 + i] <= (rowend[i][0]) ? (buff[(IM_LEN+1)*(ker-1)-2 + i] + temp_times14[i]) : buff[(IM_LEN+1)*(ker-1)-2 + i];
                buff[(IM_LEN+1)*(ker-1)-2 + i] <= (rowend[i][0] & rowend[i][1]) ? (buff[(IM_LEN+1)*(ker-1)-3 + i] + temp_times3[i]) : buff[(IM_LEN+1)*(ker-1)-3 + i];
                temp_out[i] <= (buff[(IM_LEN+1)*(ker-1)-1 + i] + temp_times3[i]);    
            end           
        end
    end

    // ASYNCHRONOUS PART OF OPERATION BLOCK---------------------------------------------------
    genvar z;
    generate
        for (z = 0; z < NO_PARALLEL_UNITS; z = z+1) begin
            assign temp_times2[z] = (in[z] << 1); // times 2
            assign temp_times16[z] = (in[z] << 4); // times 16
            assign temp_times3[z] = (temp_times2[z] + in[z]);    // times 3
            assign temp_times14[z] = (temp_times16[z] - temp_times2[z]);  // times 14
            assign temp_times60[z] = {(temp_times16[z] - in[z]), 2'b00}; // times 60                     
            assign out[z] = temp_out[z][14:7];
        end
    endgenerate

    always@* begin
        if(rowend[0] & rowend[1]) begin
            out[0] = 8'b0;
            out[1] = 8'b0;
        end
    end
                    
endmodule