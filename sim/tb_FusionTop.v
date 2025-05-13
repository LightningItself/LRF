`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2025 04:30:13 PM
// Design Name: 
// Module Name: tb_FusionTop
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


module tb_FusionTop;

// Parameters
parameter IMAGE_WIDTH  = 520;
parameter IMAGE_HEIGHT = 520;
parameter IMAGE_SIZE   = IMAGE_WIDTH * IMAGE_HEIGHT;
parameter HNO_IMAGES   = 4;
parameter TOTAL_SLOTS  = HNO_IMAGES + 1;  // 5 slots for 4 previous and 1 new image
parameter INPUT_DATA_WIDTH = 32;
parameter OUTPUT_DATA_WIDTH = 16;
parameter TOTAL_FRAMES = 8;  // change as needed

// Clock and reset
reg axi_clk;
reg axi_reset_n;

// AXI Stream Slave Interface
reg s_axis_valid;
reg [31:0] s_axis_input;
wire s_axis_ready;
reg [7:0] avg_array [0:IMAGE_SIZE-1];
reg [7:0] fused_array [0:IMAGE_SIZE-1];


// AXI Stream Master Interface
wire m_axis_valid;
wire [15:0] m_axis_output;
reg m_axis_ready;
wire m_axis_last;

    // Memory
reg [7:0] ddr_mem [0:(TOTAL_SLOTS +2) * IMAGE_SIZE - 1];  // 6 slots 
integer new_index = 4;
integer old_index = 0;
integer write_index = 0;

integer i;
integer frame_count = 4;
reg [256*8:1] filename;  // for dynamic filenames

localparam AVG_IMAGE_ADDR   = TOTAL_SLOTS * IMAGE_SIZE;
localparam FUSED_IMAGE_ADDR = (TOTAL_SLOTS + 1) * IMAGE_SIZE;

// Instantiate the design
FusionTop dut (
    .axi_clk(axi_clk),
    .axi_reset_n(axi_reset_n),
    .s_axis_valid(s_axis_valid),
    .s_axis_input(s_axis_input),
    .s_axis_ready(s_axis_ready),
    .m_axis_valid(m_axis_valid),
    .m_axis_output(m_axis_output),
    .m_axis_ready(m_axis_ready),
    .m_axis_last(m_axis_last)
);

// Clock generation
always #5 axi_clk = ~axi_clk;

initial begin
    axi_clk = 1;
    axi_reset_n = 0;
    s_axis_input=0;
    s_axis_valid = 0;
    m_axis_ready = 1;  // Master is always ready to accept data
end

// Load initial images (image0.hex to image3.hex, avg.hex, fused.hex)
initial begin
for (i = 0; i < (TOTAL_SLOTS); i = i + 1) begin
    $sformat(filename, "C:/Users/Indrayudh/Research/LRF/sim/door_hex16/Door%0d.hex", i);
    $readmemh(filename, ddr_mem, i * IMAGE_SIZE, (i + 1) * IMAGE_SIZE - 1);
    end

$readmemh("C:/Users/Indrayudh/Research/LRF/sim/avg_image4.hex", ddr_mem, AVG_IMAGE_ADDR, AVG_IMAGE_ADDR + IMAGE_SIZE - 1);
$readmemh("C:/Users/Indrayudh/Research/LRF/sim/fused.hex", ddr_mem, FUSED_IMAGE_ADDR, FUSED_IMAGE_ADDR + IMAGE_SIZE - 1);
end  

// Reset logic
initial begin
#100 axi_reset_n = 1;
end

// INPUT feeding
initial begin
#110;

while (frame_count < TOTAL_FRAMES) begin
s_axis_valid = 1;
$sformat(filename, "C:/Users/Indrayudh/Research/LRF/sim/door_hex16/Door%0d.hex", frame_count);
$readmemh(filename, ddr_mem, new_index * IMAGE_SIZE, (new_index + 1) * IMAGE_SIZE - 1);

for (i = 0; i < IMAGE_SIZE; i = i + 1) begin
    s_axis_input = {
    ddr_mem[old_index * IMAGE_SIZE + i],
    ddr_mem[FUSED_IMAGE_ADDR + i],
    ddr_mem[new_index * IMAGE_SIZE + i],
    ddr_mem[AVG_IMAGE_ADDR + i]
    };
    while (!s_axis_ready) @(posedge axi_clk);
    @(posedge axi_clk);
end

    new_index  = (new_index + 1) % TOTAL_SLOTS;
    old_index  = (old_index + 1) % TOTAL_SLOTS;
    frame_count = frame_count + 1;

    $display("Frame %0d sent.", frame_count - 1);
end
end
// OUTPUT capturing
always @(posedge axi_clk) begin
if (m_axis_valid && write_index < IMAGE_SIZE) begin
ddr_mem[AVG_IMAGE_ADDR   + write_index] = m_axis_output[15:8];
ddr_mem[FUSED_IMAGE_ADDR + write_index] = m_axis_output[7:0];
write_index = write_index + 1;

if (write_index == IMAGE_SIZE) begin
    write_index = 0;
    $display("Frame write complete.");
end
end
end

initial begin
    wait (frame_count == TOTAL_FRAMES);
    #230;

    for (i = 0; i < IMAGE_SIZE; i = i + 1) begin
        avg_array[i]   = ddr_mem[AVG_IMAGE_ADDR + i];
        fused_array[i] = ddr_mem[FUSED_IMAGE_ADDR + i];
    end

    $writememh("C:/Users/Indrayudh/Research/LRF/sim/runs/avg_output.hex", avg_array);
    $writememh("C:/Users/Indrayudh/Research/LRF/sim/runs/fused_output.hex", fused_array);

    $display("Written both avg and fused outputs from separate arrays.");
    $finish;
end

endmodule
