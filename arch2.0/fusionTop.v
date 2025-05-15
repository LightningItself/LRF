`timescale 1ns / 1ps

/*
new image   -> fetched from DDR, I(n)
old image   -> fetched from DDR, I(n - 16)
avg of 16   -> stored in BRAM (updates after each fusion)
fused image -> stored in BRAM for 15 cycles and written to DDR in 16th cycle
*/

module fusionTop 
    #(parameter   
        IM_LEN              = 520, 
        IM_WID              = 520,  
        NO_IMAGES           = 16,
        INPUT_DATA_WIDTH    = 128,
        OUTPUT_DATA_WIDTH   = 128,
        NO_PARALLEL_UNITS   = 4,
        DATA_WIDTH          = 8,
        LOG2_NO_OF_IMAGES   = 4,
        PIPELINE_LATENCY    = 20
    )(  
    input wire                          axi_clk,
    input wire                          axi_aresetn,
    input wire                          s_axis_tvalid,
    input wire [INPUT_DATA_WIDTH-1:0]   s_axis_tdata,
    output reg                          s_axis_tready,
    output reg                          m_axis_tvalid,
    output reg [OUTPUT_DATA_WIDTH-1:0]  m_axis_tdata,
    input wire                          m_axis_tready,
    output reg                          m_axis_tlast
);

    reg [OUTPUT_DATA_WIDTH-1:0] m_axis_output_reg;

    // Input & computation pipeline
    wire [DATA_WIDTH-1:0] new_image [NO_PARALLEL_UNITS - 1 : 0];
    wire [DATA_WIDTH-1:0] old_image [NO_PARALLEL_UNITS - 1 : 0];
    wire [DATA_WIDTH-1:0] avg_image [NO_PARALLEL_UNITS - 1 : 0];    // from BRAM
    wire [DATA_WIDTH-1:0] fused_image [NO_PARALLEL_UNITS - 1 : 0];  // from BRAM
    wire [DATA_WIDTH-1:0] new_average_delayed_more20 [NO_PARALLEL_UNITS - 1 : 0];
    wire [DATA_WIDTH-1:0] new_fused_image [NO_PARALLEL_UNITS - 1 : 0];
    wire [OUTPUT_DATA_WIDTH-1:0] output_data;

    reg [DATA_WIDTH+LOG2_NO_OF_IMAGES+1:0] mult_result [NO_PARALLEL_UNITS - 1 : 0];
    reg [DATA_WIDTH-1:0] new_average_reg [NO_PARALLEL_UNITS - 1 : 0];

    // unpacking the new and old image
    always @* begin
        for (i = 0; i < NO_PARALLEL_UNITS; i++){
            new_image[i] = s_axis_tdata[(i+1)*DATA_WIDTH - 1 : i*DATA_WIDTH]
            old_image[i] = s_axis_tdata[(i+DATA_WIDTH*NO_PARALLEL_UNITS+1)*DATA_WIDTH - 1 : i+DATA_WIDTH*NO_PARALLEL_UNITS]
        }
    end

    wire ovalid, olast; //validity of value in last stage of the hfusion pipeline
    wire step = (s_axis_tvalid & m_axis_tready);

    //2 stage avg calculation
    always @(posedge gated_clk) begin
        if (~axi_reset_n) begin
            for (i = 0; i < NO_PARALLEL_UNITS; i++){
                mult_result[i] <= 0;
                new_average_reg[i] <= 0;
            }
        end
        else begin
            for (i = 0; i < NO_PARALLEL_UNITS; i++){
                mult_result[i] <= (avg_image[i] << LOG2_NO_OF_IMAGES) + new_image[i];
                new_average_reg[i] <= (mult_result[i] - old_image[i]) >> LOG2_NO_OF_IMAGES;
            }
        end
    end
    
    //18 more delay stages for avg calculation
    hmultipledelay #(DATA_WIDTH,8'd18) hod_fuse1 (axi_clk,~axi_reset_n,new_average_reg,new_average_delayed_more20);
    hfusion #(DATA_WIDTH,IM_LEN) hfusion_inst (axi_clk,~axi_reset_n,fused_image,new_image,avg_image,new_fused_image);

    always @(*) begin
        s_axis_tready = step;
        m_axis_tvalid = ovalid;
        m_axis_tdata = {(128 - 2*NO_PARALLEL_UNITS*DATA_WIDTH){1'b0}, new_average_delayed_more20, new_fused_image};
        m_axis_tlast = olast;
    end
    
endmodule