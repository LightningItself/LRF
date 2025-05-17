`timescale 1ns / 1ps

module LRF_sim ();

// Parameters
parameter N_IMAGES = 2;  // Number of images (Door_1.hex to Door_N.hex)
parameter IMAGE_WIDTH = 512;
parameter IMAGE_HEIGHT = 512;
parameter PIXEL_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT;  // 262144
parameter PIXEL_WIDTH = 8;
parameter WORD_WIDTH = 128;
parameter PIXELS_PER_WORD = WORD_WIDTH / PIXEL_WIDTH;  // 16
parameter WORDS_PER_IMAGE = PIXEL_COUNT / PIXELS_PER_WORD;  // 16384
parameter MEM_DEPTH = N_IMAGES * WORDS_PER_IMAGE;

parameter MEM_BITS = $clog2(MEM_DEPTH);
parameter MAX_BEAT_PTR = WORDS_PER_IMAGE;

reg                         s_axis_aclk     = 0;
reg                         s_axis_aresetn  = 0;

//S_AXIS_INTERFACE SIGNALS
reg [WORD_WIDTH-1:0]        s_axis_tdata;
reg                         s_axis_tvalid;
reg                         s_axis_tlast;
wire                        s_axis_tready;

//M_AXIS_INTERFACE SIGNALS
wire [WORD_WIDTH-1:0]       m_axis_tdata;
wire                        m_axis_tvalid;
wire                        m_axis_tlast;
reg                         m_axis_tready;

//DDR MEM
reg [WORD_WIDTH-1:0]        mem [0:MEM_DEPTH-1];
reg [PIXEL_WIDTH-1:0]       pixel_array [0:PIXEL_COUNT-1];
reg [256*8:0]               hex_filename;

integer i, j, img;
integer mem_index = 0;


//CLOCKING
always #1 
    s_axis_aclk = ~s_axis_aclk;

//AXI INPUT CONTROLLER
reg [63:0]                  new_frame_ptr = 0;
wire [63:0]                 old_frame_ptr = (new_frame_ptr>16 ? new_frame_ptr-16 : 0);
reg [63:0]                  beat_ptr      = 0;

reg state = 0;

reg rand_valid;
reg rand_ready;

always @(posedge s_axis_aclk) begin
    if(~s_axis_aresetn) begin
        new_frame_ptr   <= 0;
        beat_ptr        <= 0;
    end
    else if(s_axis_tready & s_axis_tvalid) begin
        if(beat_ptr == MAX_BEAT_PTR & new_frame_ptr == N_IMAGES-1 & state) begin
            beat_ptr <= 0;
            new_frame_ptr <= 0;
            $finish;
        end
        else if(beat_ptr == MAX_BEAT_PTR-1) begin
            state <= ~state;
            beat_ptr <= 0;
            if(state == 1)
                new_frame_ptr <= new_frame_ptr + 1;
        end
        else begin
            beat_ptr <= beat_ptr + 1;
        end
    end
end

always @(posedge s_axis_aclk) begin
    rand_valid <= $random;
    rand_ready <= $random;
end

wire [63:0] mem_new_ptr = new_frame_ptr*WORDS_PER_IMAGE+beat_ptr;
wire [63:0] mem_old_ptr = old_frame_ptr*WORDS_PER_IMAGE+beat_ptr;

always @(*) begin
    if(~s_axis_aresetn) begin
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
    end
    else begin
        s_axis_tvalid = rand_valid;
        s_axis_tdata  = state ? mem[mem_new_ptr] : mem[mem_old_ptr];
        s_axis_tlast  = beat_ptr == MAX_BEAT_PTR & new_frame_ptr == N_IMAGES-1 & state;
    end
end

//OUTPUT AXI CONTROLLER
integer outfile;

always @(*) begin
    m_axis_tready = rand_ready;
end

always @(posedge s_axis_aclk) begin
    if (m_axis_tvalid && m_axis_tready) begin
        for (i = 0; i < 16; i = i + 1) begin
            $fdisplay(outfile, "%02x", m_axis_tdata[i*8 +: 8]);
        end

        if (m_axis_tlast) begin
            $display("Data capture complete.");
            $fclose(outfile);
            $finish;
        end
    end
end

wire step = m_axis_tready & s_axis_tvalid & s_axis_aresetn;

//DUMMY DUT MODEL
assign s_axis_tready = 1;
CONV_GAUSS dut(s_axis_aclk,s_axis_aresetn,~step,s_axis_tdata,m_axis_tdata);

initial begin

    //LOAD IMAGE FILES ONTO DDR MEM-------------------------------------

    for (img = 1; img <= N_IMAGES; img = img + 1) begin
        // Generate filename
        $sformat(hex_filename, "C:/Users/Indrayudh/Research/LRF/sim/hex_data/Door_%0d.hex", img);
        $display("Loading image: %s", hex_filename);

        // Read .hex file into temporary pixel array
        $readmemh(hex_filename, pixel_array);

        // Pack 16 pixels into each 128-bit word
        for (i = 0; i < WORDS_PER_IMAGE; i = i + 1) begin
            mem[mem_index] = 128'b0;
            for (j = 0; j < PIXELS_PER_WORD; j = j + 1) begin
                mem[mem_index][j * PIXEL_WIDTH +: PIXEL_WIDTH] = pixel_array[i * PIXELS_PER_WORD + j];
            end
            mem_index = mem_index + 1;
        end
    end
    // Display first few words (optional)
    for (i = 0; i < MEM_DEPTH; i = i + 1) begin
        $display("mem[%0d] = %032x", i, mem[i]);
    end

    //SETUP OUTFILE FOR WRITING OUTPUT
    outfile = $fopen("output.hex", "w");

    //-----------------------------------------------------------------
    //DISABLE ARESETN
    #3 s_axis_aresetn = 1;




end


endmodule

