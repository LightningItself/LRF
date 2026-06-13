module axis_buff_depth #(
    parameter S_AXIS_DATA_WIDTH = 8,
    parameter M_AXIS_DATA_WIDTH = 16,
    parameter DEPTH = 1  // latency = DEPTH+1
)(
    input wire aclk,
    input wire aresetn,

    input wire [S_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,

    output reg [M_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast
);

wire advance = ~m_axis_tvalid || m_axis_tready;

reg [S_AXIS_DATA_WIDTH-1:0] data_pipe[DEPTH-1:0];
reg valid_pipe[DEPTH-1:0];
reg last_pipe[DEPTH-1:0];

integer i;
always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;
        m_axis_tdata  <= 0;
        for(i=0; i<DEPTH; i=i+1) begin
            data_pipe[i]  <= 0;
            valid_pipe[i] <= 0;
            last_pipe[i]  <= 0;
        end
    end
    else if(advance) begin
        if(s_axis_tvalid) begin
            data_pipe[0] <= s_axis_tdata;
        end
        last_pipe[0] <= s_axis_tlast;
        valid_pipe[0] <= s_axis_tvalid;
        for(i=1; i<DEPTH; i=i+1) begin
            data_pipe[i]  <= data_pipe[i-1];
            valid_pipe[i] <= valid_pipe[i-1];
            last_pipe[i]  <= last_pipe[i-1];
        end
        m_axis_tdata  <= {M_AXIS_DATA_WIDTH{1'b0}} | data_pipe[DEPTH-1];
        m_axis_tvalid <= valid_pipe[DEPTH-1];
        m_axis_tlast  <= last_pipe[DEPTH-1];
    end
end

assign s_axis_tready = advance & s_axis_tvalid;

endmodule