`timescale 1ns / 1ps

module tb_top;
 
// ─── Parameters ──────────────────────────────────────────────────────────────
localparam PIXELS_PER_BEAT  = 16;
localparam IMAGE_DIM        = 512;
localparam PIXEL_SIZE       = 8;
localparam N_FUSE_COUNT     = 4;
localparam DATA_WIDTH       = PIXEL_SIZE * PIXELS_PER_BEAT;   // 128
localparam BEATS_PER_FRAME  = IMAGE_DIM * IMAGE_DIM / PIXELS_PER_BEAT;
localparam FUSE_DEPTH       = 1 << N_FUSE_COUNT;              // 16
localparam OUTPUT_TIMEOUT_CYCLES = BEATS_PER_FRAME * 200;
 
// ─── Clock / Reset ───────────────────────────────────────────────────────────
logic clk = 0;
logic rst_n;
 
always #5 clk = ~clk;   // 100 MHz
 
initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
end
 
// ─── AXI-Stream interfaces ────────────────────────────────────────────────────
axis_if #(DATA_WIDTH) s_axis(.clk(clk), .rst_n(rst_n));
axis_if #(DATA_WIDTH) m_axis(.clk(clk), .rst_n(rst_n));
 
// ─── DUT ─────────────────────────────────────────────────────────────────────
LRF #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .IMAGE_DIM      (IMAGE_DIM),
    .PIXEL_SIZE     (PIXEL_SIZE),
    .N_FUSE_COUNT   (N_FUSE_COUNT)
) dut (
    .s_axis_aclk   (clk),
    .s_axis_aresetn(rst_n),
    .s_axis_tdata  (s_axis.tdata),
    .s_axis_tvalid (s_axis.tvalid),
    .s_axis_tready (s_axis.tready),
    .s_axis_tlast  (s_axis.tlast),
    .m_axis_tdata  (m_axis.tdata),
    .m_axis_tvalid (m_axis.tvalid),
    .m_axis_tready (m_axis.tready),
    .m_axis_tlast  (m_axis.tlast)
);
 
// ─── Environment (single S-axis, single M-axis) ───────────────────────────────
typedef axis_sim_env #(
    .NUM_S_AXIS      (1),
    .NUM_M_AXIS      (1),
    .S_AXIS_DATA_WIDTH(DATA_WIDTH),
    .M_AXIS_DATA_WIDTH(DATA_WIDTH)
) env_t;
 
env_t env;
 
// Packed arrays required by the generic env interface
virtual axis_if #(DATA_WIDTH) s_vif_arr[1];
virtual axis_if #(DATA_WIDTH) m_vif_arr[1];
 
// ─── Helper: resolve frame index (clamp negative to 0) ───────────────────────
function automatic int frame_idx(int i);
    return (i < 0) ? 0 : i;
endfunction
 
// ─── Input / output folder paths ─────────────────────────────────────────────
string input_folder  = "../data/hex_data";    // folder containing hex_img_xxx.hex
string output_folder = ".";   // folder for output hex files (must exist)
string file_prefix   = "hex_img_";
int total_frames = 300;
int errors = 0;

task automatic tb_fail(input string message);
    $display("[TB] ERROR: %s", message);
    errors++;
    $finish;
endtask

function automatic string frame_file_name(input int index);
    return $sformatf("%s/%s%03d", input_folder, file_prefix, index);
endfunction

task automatic require_readable(input string file_name);
    int fd;
    fd = $fopen(file_name, "r");
    if (fd == 0)
        tb_fail($sformatf("Cannot open input file %s", file_name));
    $fclose(fd);
endtask
 
// ─── Main test ────────────────────────────────────────────────────────────────
initial begin
    // Wire virtual interfaces into packed arrays
    s_vif_arr[0] = s_axis;
    m_vif_arr[0] = m_axis;
 
    // Optional: override paths via plusargs
    $value$plusargs("INPUT_FOLDER=%s",  input_folder);
    $value$plusargs("OUTPUT_FOLDER=%s", output_folder);
    $value$plusargs("FILE_PREFIX=%s",   file_prefix);
    $value$plusargs("TOTAL_FRAMES=%d",  total_frames);

    if ((IMAGE_DIM * IMAGE_DIM) % PIXELS_PER_BEAT != 0)
        tb_fail("IMAGE_DIM*IMAGE_DIM must be divisible by PIXELS_PER_BEAT");
    if (total_frames <= 0)
        tb_fail($sformatf("TOTAL_FRAMES must be positive, got %0d", total_frames));
 
    // Wait for de-assertion of reset
    @(posedge rst_n);
    repeat(5) @(posedge clk);
 
    // Build environment and start drivers / monitors
    env = new(s_vif_arr, m_vif_arr);
    env.run_agents();
 
    // ── Feed frames and collect outputs in parallel ───────────────────────────
    fork
        // Producer: send (frame_i, frame_i-16) pairs
        begin : stimulus
            for (int i = 0; i <= total_frames - FUSE_DEPTH; i++) begin
                int idx_new, idx_old;
                string fname_new, fname_old;
    
                // Send the NEW frames
                for (int j = 0; j < FUSE_DEPTH; j++) begin
                    idx_new = frame_idx(i + j);
                    fname_new = frame_file_name(idx_new);
    
                    $display("[TB] Sending NEW frame %0d", idx_new);
    
                    require_readable(fname_new);
                    env.input_agent.load_file(0, fname_new, BEATS_PER_FRAME);
                end
    
                // Send the OLD frame
                if (i >= FUSE_DEPTH)
                    idx_old = frame_idx(i - FUSE_DEPTH);
                else
                    idx_old = frame_idx(0);
    
                fname_old = frame_file_name(idx_old);
    
                $display("[TB] Sending OLD frame %0d", idx_old);
    
                require_readable(fname_old);
                env.input_agent.load_file(0, fname_old, BEATS_PER_FRAME);
            end
            $display("[TB] All %0d pairs enqueued.", total_frames);
        end
 
        // Consumer: write each output frame to its own hex file
        begin : capture
            for (int i = 0; i < total_frames; i++) begin
                string fname_out;
                axis_transaction #(DATA_WIDTH) txn;
 
                fname_out = $sformatf("%s/out_%s%0d.hex", output_folder, file_prefix, i);
 
                begin : write_frame
                    int fd;
                    fd = $fopen(fname_out, "w");
                    if (fd == 0) begin
                        $display("[TB] ERROR: Cannot open output file %s", fname_out);
                        $finish;
                    end
 
                    // Collect exactly BEATS_PER_FRAME beats from the monitor mailbox
                    for (int b = 0; b < BEATS_PER_FRAME; b++) begin
                        bit got_txn;
                        got_txn = 0;
                        fork
                            begin : wait_output
                                env.output_agent.mon2scb[0].get(txn);
                                got_txn = 1;
                            end
                            begin : output_timeout
                                repeat (OUTPUT_TIMEOUT_CYCLES) @(posedge clk);
                            end
                        join_any
                        disable fork;

                        if (!got_txn)
                            tb_fail($sformatf("Timed out waiting for output frame %0d beat %0d", i, b));

                        $fdisplay(fd, "%h", txn.tdata);
 
                        // Sanity-check tlast on final beat
                        if (b == BEATS_PER_FRAME - 1 && txn.tlast !== 1'b1)
                            tb_fail($sformatf("tlast not asserted at end of output frame %0d", i));
                        if (b < BEATS_PER_FRAME - 1 && txn.tlast === 1'b1)
                            tb_fail($sformatf("premature tlast at beat %0d of output frame %0d", b, i));
                    end
 
                    $fclose(fd);
                    $display("[TB] Written output frame %0d → %s", i, fname_out);
                end
            end
            $display("[TB] All %0d output frames written.", total_frames);
        end
    join
 
    if (errors == 0)
        $display("[TB] Simulation complete.");
    $finish;
end
 
endmodule
 

