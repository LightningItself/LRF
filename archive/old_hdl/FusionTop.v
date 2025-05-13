`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2025 09:16:40 AM
// Design Name: 
// Module Name: FusionTop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FusionTop #(parameter HIM_LEN=520, 
                             HIM_WID=520,  
                             HNO_IMAGES=16,
                             INPUT_DATA_WIDTH = 32,
                             OUTPUT_DATA_WIDTH = 32,
                             DATA_WIDTH = 8,
                             LOG2_NO_OF_IMAGES = 4,
                             PIPELINE_LATENCY = 20
                           )
            (  input               axi_clk,
               input              axi_reset_n,
               input              s_axis_valid,
               input [INPUT_DATA_WIDTH-1:0] s_axis_input,
               output             s_axis_ready,
               output             m_axis_valid,
               output [OUTPUT_DATA_WIDTH-1:0] m_axis_output,
               input              m_axis_ready,
               output             m_axis_last
             );
 
    // FSM states
 localparam  IDLE    = 2'b00,
             PROCESS = 2'b01,
             FLUSH   = 2'b10;
  

    reg [2:0]  state, next_state;
    reg [31:0] pixel_count;
    reg [4:0] flush_counter;
    reg [OUTPUT_DATA_WIDTH-1:0] m_axis_output_reg;

    // FSM
    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (s_axis_valid)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end

            PROCESS: begin
                if (s_axis_valid && s_axis_ready && pixel_count == (HIM_LEN * HIM_WID - 1))
                    next_state = FLUSH;
                else
                    next_state = PROCESS;
            end

            FLUSH: begin
                if (flush_counter == PIPELINE_LATENCY - 1)
                    next_state = IDLE;
                else
                    next_state = FLUSH;
            end

            default: next_state = IDLE;
        endcase
    end

    // Input & computation pipeline
    wire [DATA_WIDTH-1:0] avg_image, new_image, fused_image, old_image, new_average_delayed_more20;
    wire [DATA_WIDTH-1:0] new_fused_image;
    wire [OUTPUT_DATA_WIDTH-1:0] output_data;
    wire done_pr2;

    reg [DATA_WIDTH+LOG2_NO_OF_IMAGES+1:0] mult_result;
    reg [DATA_WIDTH+LOG2_NO_OF_IMAGES+1:0] add_sub_result;
    reg [DATA_WIDTH-1:0] new_average_reg;

    reg [INPUT_DATA_WIDTH-1:0] last_input_data;
    wire input_valid = (state == PROCESS) && s_axis_valid;
    wire [INPUT_DATA_WIDTH-1:0] current_input = input_valid ? s_axis_input : last_input_data;

    assign avg_image   = current_input[7:0];
    assign new_image   = current_input[15:8];
    assign fused_image = current_input[23:16];
    assign old_image   = current_input[31:24];

    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            last_input_data <= 0;
        else if (s_axis_valid && s_axis_ready)
            last_input_data <= s_axis_input;
    end

    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            mult_result <= 0;
        else if (s_axis_ready && s_axis_valid)
            mult_result <= avg_image * HNO_IMAGES;
    end

    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            add_sub_result <= 0;
        else if (s_axis_ready && s_axis_valid)
            add_sub_result <= mult_result + new_image - old_image;
    end

    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            new_average_reg <= 0;
        else if (s_axis_ready && s_axis_valid)
            new_average_reg <= add_sub_result >> LOG2_NO_OF_IMAGES;
    end

    hmultipledelay #(DATA_WIDTH,8'd17) hod_fuse1 (axi_clk,~axi_reset_n,new_average_reg,new_average_delayed_more20);
    hfusion #(DATA_WIDTH,HIM_LEN) hfusion_inst (axi_clk,~axi_reset_n,fused_image,new_image,avg_image,new_fused_image,done_pr2);

    assign output_data = {16'h0000, new_average_delayed_more20, new_fused_image};

    // Pixel counter
   
    always @(posedge axi_clk) begin
        if (!axi_reset_n || state == IDLE)
            pixel_count <= 0;
        else if (s_axis_valid && s_axis_ready)
            pixel_count <= pixel_count + 1;
    end

    // Flush counter
    always @(posedge axi_clk) begin
        if (!axi_reset_n || state != FLUSH)
            flush_counter <= 0;
        else if (m_axis_valid && m_axis_ready)
            flush_counter <= flush_counter + 1;
    end

    // Output logic
    always @(posedge axi_clk) begin
        if (!axi_reset_n)
            m_axis_output_reg <= 0;
        else if (((state == PROCESS) && s_axis_valid && s_axis_ready) || (state == FLUSH && m_axis_ready))
            m_axis_output_reg <= output_data;
    end

    assign m_axis_output = m_axis_output_reg;
    assign m_axis_valid  = ((state == PROCESS) && (pixel_count >= PIPELINE_LATENCY - 1)) || (state == FLUSH);
    assign m_axis_last   = (state == FLUSH && flush_counter == PIPELINE_LATENCY - 2);

    assign s_axis_ready = (state == PROCESS);

endmodule
