`timescale 1ns/10ps

module tb_LRF (); // Sliding window frame-based LRF testbench

// Parameters
parameter N_IMAGES = 300;  // Total number of frames
parameter IMAGE_DIM = 64;
parameter N_FUSE_COUNT = 4;
parameter WINDOW_SIZE = 1<<N_FUSE_COUNT;
parameter PIXEL_COUNT = IMAGE_DIM*IMAGE_DIM;
parameter PIXEL_WIDTH = 8;
parameter PIXELS_PER_BEAT = 16;
parameter WORD_WIDTH = PIXEL_WIDTH*PIXELS_PER_BEAT;
parameter WORDS_PER_IMAGE = PIXEL_COUNT / PIXELS_PER_BEAT;
parameter MEM_DEPTH = N_IMAGES * WORDS_PER_IMAGE;
parameter MEM_BITS = $clog2(MEM_DEPTH);
parameter PIPELINE_DELAY = 10;
// parameter INPUT_IMAGE_PATH = "C:/Users/Indrayudh/Research/LRF/sim/data/cropped_hex/";
// parameter OUTPUT_IMAGE_PATH = "C:/Users/Indrayudh/Research/LRF/sim/data/output_hex_data/";
parameter INPUT_IMAGE_PATH = "/home/rahul/Documents/LRF/sim/data/cropped_hex/";
parameter OUTPUT_IMAGE_PATH = "/home/rahul/Documents/LRF/sim/data/output_hex_data/";

// Clock and Reset
reg s_axis_aclk = 0;
reg s_axis_aresetn = 0;
always #1 s_axis_aclk = ~s_axis_aclk;

// AXI Interface Signals
reg [WORD_WIDTH-1:0] s_axis_tdata;
reg s_axis_tvalid;
reg s_axis_tlast;
wire s_axis_tready;

wire [WORD_WIDTH-1:0] m_axis_tdata;
wire m_axis_tvalid;
wire m_axis_tlast;
reg  m_axis_tready;

// Memory and File IO
reg [WORD_WIDTH-1:0] mem [0:MEM_DEPTH+PIPELINE_DELAY-1];
reg [PIXEL_WIDTH-1:0] pixel_array [0:PIXEL_COUNT-1];
reg [256*8:0] hex_filename;
integer i, j, img, mem_index = 0;

// Load Image Data
initial begin
    for (img = 1; img <= N_IMAGES; img = img + 1) begin
//       $sformat(hex_filename, "C:/Users/Indrayudh/Research/LRF/sim/data/hex_data/Door_%0d.hex", img);
         $sformat(hex_filename, "/home/rahul/Documents/LRF/sim/data/hex_data/Door_%0d.hex", img);
        $display("Loading image: %s", hex_filename);
        $readmemh(hex_filename, pixel_array);
        for (i = 0; i < WORDS_PER_IMAGE; i = i + 1) begin
            mem[mem_index] = 128'b0;
            for (j = 0; j < PIXELS_PER_BEAT; j = j + 1) begin
                mem[mem_index][j * PIXEL_WIDTH +: PIXEL_WIDTH] = pixel_array[(i * PIXELS_PER_BEAT) + (PIXELS_PER_BEAT - 1) - j];
            end
            mem_index = mem_index + 1;
        end
    end
end

// Sliding Window Controller
localparam IDLE = 0, SEND_NEW = 1, SEND_OLD = 2;
reg [1:0] transfer_state;
reg [31:0] win_start;
reg [31:0] win_offset;
reg [31:0] current_frame;
reg [31:0] beat_counter;
reg [31:0] mem_ptr;
reg [31:0] total_frames = N_IMAGES;

// Randomization
parameter RANDOMIZE = 1;
reg rand_valid;
reg rand_ready;
always @(posedge s_axis_aclk) begin
    rand_valid <= RANDOMIZE ? $random : 1;
    rand_ready <= RANDOMIZE ? $random : 1;
end

// State Machine
always @(posedge s_axis_aclk) begin
    if (~s_axis_aresetn) begin
        win_start <= 0;
        win_offset <= 0;
        beat_counter <= 0;
        transfer_state <= IDLE;
    end else begin
        case (transfer_state)
            IDLE: begin
                if (win_start + WINDOW_SIZE - 1 < N_IMAGES) begin
                    current_frame <= win_start;
                    beat_counter <= 0;
                    transfer_state <= SEND_NEW;
                end
            end

            SEND_NEW: begin
                if (s_axis_tready && s_axis_tvalid) begin
                    if (beat_counter == WORDS_PER_IMAGE - 1) begin
                        beat_counter <= 0;
                        transfer_state <= SEND_OLD;
                    end else begin
                        beat_counter <= beat_counter + 1;
                    end
                end
            end

            SEND_OLD: begin
                if (s_axis_tready && s_axis_tvalid) begin
                    if (beat_counter == WORDS_PER_IMAGE - 1) begin
                        beat_counter <= 0;
                        win_offset <= win_offset + 1;
                        if (win_offset == WINDOW_SIZE - 1) begin
                            win_start <= win_start + 1;
                            win_offset <= 0;
                            current_frame <= win_start;
                            beat_counter <= 0;
                            transfer_state <= SEND_NEW;
                        end else begin
                            current_frame <= win_start + win_offset + 1;
                            transfer_state <= SEND_NEW;
                        end
                    end else begin
                        beat_counter <= beat_counter + 1;
                    end
                end
            end
        endcase
    end
end

// AXI Input Signal Generation
always @(*) begin
    s_axis_tvalid = (transfer_state != IDLE) && rand_valid;
    s_axis_tlast = (beat_counter == WORDS_PER_IMAGE - 1);
    if (transfer_state == SEND_NEW) begin
        mem_ptr = current_frame * WORDS_PER_IMAGE + beat_counter;
    end else if (transfer_state == SEND_OLD) begin
        mem_ptr = (current_frame >= WINDOW_SIZE ? (current_frame - WINDOW_SIZE) : 0) * WORDS_PER_IMAGE + beat_counter;
    end else begin
        mem_ptr = 0;
    end
    s_axis_tdata = mem[mem_ptr];
end

// Output Capture
integer outfile;
integer frame_counter = 0;
reg [256*8:0] output_filename;
reg [64:0] output_counter = 0;

always @(posedge s_axis_aclk) begin
    if (m_axis_tvalid && m_axis_tready) begin
        if (output_counter == 0) begin
//            $sformat(output_filename, "C:/Users/Indrayudh/Research/LRF/sim/data/output_hex_data/conv_output_%0d.hex", frame_counter);
            $sformat(output_filename, "/home/rahul/Documents/LRF/sim/data/output_hex_data/conv_output_%0d.hex", frame_counter);
            outfile = $fopen(output_filename, "w");
        end
        for (i = 15; i >= 0; i = i - 1)
            $fdisplay(outfile, "%02x", m_axis_tdata[i*8 +: 8]);

        if (m_axis_tlast) begin
            $display("Frame %0d capture complete.", frame_counter);
            $fclose(outfile);
            frame_counter = frame_counter + 1;
        end

        output_counter <= (output_counter == WORDS_PER_IMAGE - 1) ? 0 : output_counter + 1;
    end
end

always @(*)
    m_axis_tready = rand_ready;

// DUT Instantiation
LRF #(
    PIXELS_PER_BEAT,
    IMAGE_DIM,
    N_FUSE_COUNT,
    PIPELINE_DELAY
) dut (
    .s_axis_aclk     (s_axis_aclk),
    .s_axis_aresetn  (s_axis_aresetn),
    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .s_axis_tlast    (s_axis_tlast),
    .m_axis_tdata    (m_axis_tdata),
    .m_axis_tvalid   (m_axis_tvalid),
    .m_axis_tready   (m_axis_tready),
    .m_axis_tlast    (m_axis_tlast)
);

// Reset Pulse
initial begin
    #3.1 s_axis_aresetn = 1;
end

endmodule
