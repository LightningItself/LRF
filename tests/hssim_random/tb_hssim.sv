`timescale 1ns/10ps
`include "tb_config.svh"

module tb_top;

parameter PIXELS_PER_BEAT = 16;
parameter PIXEL_SIZE       = 8;
parameter IMAGE_DIM        = 512;

logic clk   = 0;
logic rst_n = 0;

always #5 clk = ~clk;

axis_if #(`S_AXIS_DATA_WIDTH)    s_if [2]  (clk, rst_n);
axis_if #(`NUMR_DENR_DATA_WIDTH) numr_if   (clk, rst_n);
axis_if #(`NUMR_DENR_DATA_WIDTH) denr_if   (clk, rst_n);
axis_if #(`SIGN_DATA_WIDTH)      sign_if   (clk, rst_n);

virtual axis_if #(`S_AXIS_DATA_WIDTH)    v_s_if [2];
virtual axis_if #(`NUMR_DENR_DATA_WIDTH) v_denr_if;
virtual axis_if #(`NUMR_DENR_DATA_WIDTH) v_numr_if;
virtual axis_if #(`SIGN_DATA_WIDTH)      v_sign_if;

HSSIM #(
    .PIXELS_PER_BEAT(PIXELS_PER_BEAT),
    .PIXEL_SIZE(PIXEL_SIZE),
    .IMAGE_DIM(IMAGE_DIM)
) dut (
    .aclk(clk),
    .aresetn(rst_n),
    .map_x(s_if[0].tdata),
    .map_x_valid(s_if[0].tvalid),
    .map_x_ready(s_if[0].tready),
    .map_x_last(s_if[0].tlast),
    .map_y(s_if[1].tdata),
    .map_y_valid(s_if[1].tvalid),
    .map_y_ready(s_if[1].tready),
    .map_y_last(s_if[1].tlast),
    .numr(numr_if.tdata),
    .denr(denr_if.tdata),
    .numr_sign(sign_if.tdata),
    .out_valid(numr_if.tvalid),
    .out_ready(numr_if.tready),
    .out_last(numr_if.tlast)
);

// denr and sign share the same handshake as numr
assign denr_if.tvalid = numr_if.tvalid;
assign denr_if.tlast  = numr_if.tlast;
assign sign_if.tvalid = numr_if.tvalid;
assign sign_if.tlast  = numr_if.tlast;

// out_ready only asserts when all three receivers are ready
// denr_if.tready driven by axis_monitor (random backpressure) — that's the controlling ready
// sign_if.tready driven by axis_monitor (random backpressure)
// numr_if.tready is the AND — must not be driven by any monitor
assign numr_if.tready = denr_if.tready & sign_if.tready;

// sim_env drives inputs only — NUM_M_AXIS=0 not possible, so use 1 output for denr
// numr observed via axis_monitor_ro (no tready driving)
axis_sim_env #(
    .NUM_S_AXIS(2),
    .NUM_M_AXIS(1),
    .S_AXIS_DATA_WIDTH(`S_AXIS_DATA_WIDTH),
    .M_AXIS_DATA_WIDTH(`NUMR_DENR_DATA_WIDTH)
) sim;

virtual axis_if #(`NUMR_DENR_DATA_WIDTH) v_sim_m_if [1];

axis_monitor_ro #(`NUMR_DENR_DATA_WIDTH) numr_mon;
axis_monitor    #(`SIGN_DATA_WIDTH)      sign_mon;
mailbox numr_mon2scb;
mailbox sign_mon2scb;

string input_files        [2];
string denr_output_files  [1];
int    input_total_beats  [2];
int    denr_total_beats   [1];

initial begin
    v_s_if[0]    = s_if[0];
    v_s_if[1]    = s_if[1];
    v_denr_if    = denr_if;
    v_numr_if    = numr_if;
    v_sign_if    = sign_if;
    v_sim_m_if[0] = denr_if;

    input_files[0]       = "inputs_x.hex";
    input_files[1]       = "inputs_y.hex";
    denr_output_files[0] = "outputs_denr.hex";

    input_total_beats[0] = `S_AXIS_TOTAL_BEATS_0;
    input_total_beats[1] = `S_AXIS_TOTAL_BEATS_1;
    denr_total_beats[0]  = `M_AXIS_TOTAL_BEATS_1;

    if (!$value$plusargs("IN_FILE_NAME_X=%s",     input_files[0]))       $fatal(1, "Missing IN_FILE_NAME_X");
    if (!$value$plusargs("IN_FILE_NAME_Y=%s",     input_files[1]))       $fatal(1, "Missing IN_FILE_NAME_Y");
    if (!$value$plusargs("OUT_FILE_NAME_DENR=%s", denr_output_files[0])) $fatal(1, "Missing OUT_FILE_NAME_DENR");

    numr_mon2scb = new();
    sign_mon2scb = new();
    numr_mon     = new(v_numr_if, numr_mon2scb);
    sign_mon     = new(v_sign_if, sign_mon2scb);
    sim          = new(v_s_if, v_sim_m_if);

    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;

    fork
        numr_mon.run();
        sign_mon.run();
    join_none

    fork
        sim.run(input_files, input_total_beats, denr_output_files, denr_total_beats);
        check_numr();
        check_sign();
    join

    $finish;
end

task automatic check_numr();
    automatic string numr_file = "outputs_numr.hex";
    automatic int    errors    = 0;
    automatic logic [`NUMR_DENR_DATA_WIDTH-1:0] expected_data [];
    automatic axis_transaction #(`NUMR_DENR_DATA_WIDTH) transaction;

    if (!$value$plusargs("OUT_FILE_NAME_NUMR=%s", numr_file)) $fatal(1, "Missing OUT_FILE_NAME_NUMR");

    expected_data = new[`M_AXIS_TOTAL_BEATS_0];
    $display("[NUMR CHECK] Loading: %s", numr_file);
    $readmemh(numr_file, expected_data);

    for (int i = 0; i < `M_AXIS_TOTAL_BEATS_0; i++) begin
        numr_mon2scb.get(transaction);
        if (transaction.tdata !== expected_data[i]) begin
            $display("[NUMR CHECK] Mismatch beat %0d: got %h, expected %h",
                     i, transaction.tdata, expected_data[i]);
            errors++;
        end else
            $display("[NUMR CHECK] Match beat %0d: got %h, expected %h",
                     i, transaction.tdata, expected_data[i]);
        if (transaction.tlast !== (i == `M_AXIS_TOTAL_BEATS_0 - 1)) begin
            $display("[NUMR CHECK] TLAST mismatch beat %0d: got %b, expected %b",
                     i, transaction.tlast, (i == `M_AXIS_TOTAL_BEATS_0 - 1));
            errors++;
        end
    end
    $display("[NUMR CHECK] Errors: %0d", errors);
endtask

task automatic check_sign();
    automatic string sign_file = "outputs_sign.hex";
    automatic int    errors    = 0;
    automatic logic [`SIGN_DATA_WIDTH-1:0] expected_data [];
    automatic axis_transaction #(`SIGN_DATA_WIDTH) transaction;

    if (!$value$plusargs("OUT_FILE_NAME_SIGN=%s", sign_file)) $fatal(1, "Missing OUT_FILE_NAME_SIGN");

    expected_data = new[`M_AXIS_TOTAL_BEATS_2];
    $display("[SIGN CHECK] Loading: %s", sign_file);
    $readmemh(sign_file, expected_data);

    for (int i = 0; i < `M_AXIS_TOTAL_BEATS_2; i++) begin
        sign_mon2scb.get(transaction);
        if (transaction.tdata !== expected_data[i]) begin
            $display("[SIGN CHECK] Mismatch beat %0d: got %h, expected %h",
                     i, transaction.tdata, expected_data[i]);
            errors++;
        end else
            $display("[SIGN CHECK] Match beat %0d: got %h, expected %h",
                     i, transaction.tdata, expected_data[i]);
        if (transaction.tlast !== (i == `M_AXIS_TOTAL_BEATS_2 - 1)) begin
            $display("[SIGN CHECK] TLAST mismatch beat %0d: got %b, expected %b",
                     i, transaction.tlast, (i == `M_AXIS_TOTAL_BEATS_2 - 1));
            errors++;
        end
    end
    $display("[SIGN CHECK] Errors: %0d", errors);
endtask

endmodule