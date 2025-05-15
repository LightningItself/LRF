`timescale 1ns / 1ps

module rowend_sig_genr #(parameter IM_LEN=16'd520, KER_SIZE = 3, NO_PARALLEL_UNITS = 4) (
    input clk,
    input res,
    input clrbuffer,
    input stall,
    output reg [KER_SIZE-2:0] out [NO_PARALLEL_UNITS-1:0]
    );
   
    reg [10:0] cnt;
    integer i;
   
    always@( posedge clk) begin
        if(res | clrbuffer) begin    
            cnt <= (11'd0);      
        end
       
        else begin
            if(cnt + 1 == IM_LEN / NO_PARALLEL_UNITS) begin
                cnt <= 'd0;  
            end

            else begin
                if(!stall) begin
                    cnt <= cnt+1;
                end
            end
        end
    end
    
    always@(*) begin
        for(i = 0; i < KER_SIZE-1; i = i+1) begin
            out[i] = (cnt == (IM_LEN/NO_PARALLEL_UNITS - 1 - i)) ? 1'b0 : 1'b1;
        end                                                                                                                                                                                                                                                                                     
    end
endmodule