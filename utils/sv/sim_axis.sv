//physical AXI-Stream interface
interface axis_if #(parameter DATA_WIDTH = 128) (
    input logic clk,
    input logic rst_n
);
    logic [DATA_WIDTH-1:0] tdata;
    logic tvalid;
    logic tready;
    logic tlast;
endinterface

//AXI-Stream transaction object
class axis_transaction #(parameter DATA_WIDTH = 128);
    logic [DATA_WIDTH-1:0] tdata;
    logic tlast;

    function new(logic [DATA_WIDTH-1:0] tdata, logic tlast);
        this.tdata = tdata;
        this.tlast = tlast;
    endfunction
endclass

//AXI-Stream driver 
class axis_driver #(parameter DATA_WIDTH = 128);
    virtual axis_if #(DATA_WIDTH) vif;
    mailbox gen2drv;

    function new(virtual axis_if #(DATA_WIDTH) axis_vif, mailbox gen2drv);
        this.vif = axis_vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        axis_transaction #(DATA_WIDTH) transaction;
        vif.tvalid <= 0;
        vif.tlast <= 0;
        vif.tdata <= 0;

        forever begin
            @(posedge vif.clk);
            if(!vif.tvalid || vif.tready) begin
                if ($urandom_range(0, 9) < 7) begin
                    if(gen2drv.try_get(transaction)) begin
                        vif.tvalid <= 1;
                        vif.tdata <= transaction.tdata;
                        vif.tlast <= transaction.tlast;
                    end else begin
                        vif.tvalid <= 0;
                        vif.tlast <= 0;
                    end
                end else begin
                    vif.tvalid <= 0;
                    vif.tlast <= 0;
                end
            end
        end
    endtask
endclass

//AXI-Stream monitor
class axis_monitor #(parameter DATA_WIDTH = 128);
    virtual axis_if #(DATA_WIDTH) vif;
    mailbox mon2scb; 

    function new(virtual axis_if #(DATA_WIDTH) vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        axis_transaction #(DATA_WIDTH) transaction;
        forever begin
            @(posedge vif.clk);
            vif.tready <= ($urandom_range(0, 9) < 7);
            if (vif.tvalid && vif.tready) begin
                transaction = new(vif.tdata, vif.tlast);
                mon2scb.put(transaction); 
            end
        end
    endtask
endclass


class axis_sim #(parameter S_AXIS_DATA_WIDTH = 128, parameter M_AXIS_DATA_WIDTH = 128, parameter S_AXIS_TOTAL_BEATS = 32032, parameter M_AXIS_TOTAL_BEATS = 32032);
    axis_driver #(S_AXIS_DATA_WIDTH) drv;
    axis_monitor #(M_AXIS_DATA_WIDTH) mon;

    mailbox gen2drv;
    mailbox mon2scb;

    virtual axis_if #(S_AXIS_DATA_WIDTH) s_vif;
    virtual axis_if #(M_AXIS_DATA_WIDTH) m_vif;

    int errors = 0;

    function new(virtual axis_if #(S_AXIS_DATA_WIDTH) s_vif, virtual axis_if #(M_AXIS_DATA_WIDTH) m_vif);
        this.s_vif = s_vif;
        this.m_vif = m_vif;
        gen2drv = new();
        mon2scb = new();
        drv = new(s_vif, gen2drv);
        mon = new(m_vif, mon2scb);
    endfunction

    task stimulus();
        logic [S_AXIS_DATA_WIDTH-1:0] input_data [S_AXIS_TOTAL_BEATS-1:0];
        axis_transaction #(S_AXIS_DATA_WIDTH) transaction;
        string input_file = "inputs.hex";

        $value$plusargs("IN_FILE_NAME=%s", input_file);
        $display("[AXIS SIM] Loading input file: %s", input_file);
        $readmemh(input_file, input_data);

        for (int i = 0; i < S_AXIS_TOTAL_BEATS; i++) begin
            transaction = new(input_data[i], (i == S_AXIS_TOTAL_BEATS - 1));
            $display("[AXIS SIM] Sending data beat number: %0d", i);
            gen2drv.put(transaction);
        end
    endtask

    task check();
        logic [M_AXIS_DATA_WIDTH-1:0] expected_data [M_AXIS_TOTAL_BEATS-1:0];
        axis_transaction #(M_AXIS_DATA_WIDTH) transaction;
        string output_file = "outputs.hex";

        $value$plusargs("OUT_FILE_NAME=%s", output_file);
        $display("[AXIS SIM] Loading expected output file: %s", output_file);

        $readmemh(output_file, expected_data);

        for (int i = 0; i < M_AXIS_TOTAL_BEATS; i++) begin
            mon2scb.get(transaction);
            if (transaction.tdata !== expected_data[i]) begin
                $display("Mismatch at beat %0d: got %h, expected %h", i, transaction.tdata, expected_data[i]);
                errors++;
            end
            else begin
                $display("Match at beat %0d: got %h, expected %h", i, transaction.tdata, expected_data[i]);
            end
        end
    endtask

    task run();
        fork
            drv.run();
            mon.run();
        join_none
        fork
            stimulus();
            check();
        join
        $display("Errors Detected: %0d", errors);
    endtask
endclass