module axis_buff #(
    parameter S_AXIS_DATA_WIDTH = 8,
    parameter M_AXIS_DATA_WIDTH = 16,
    parameter DEPTH = 1 // latency = DEPTH+1
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

reg [S_AXIS_DATA_WIDTH-1:0] data_buff[DEPTH-1:0];
reg valid_buff[DEPTH-1:0];
reg last_buff[DEPTH-1:0];

integer i;
always @(posedge aclk) begin
    if(~aresetn) begin
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
        m_axis_tdata <= 0;
        for(i=0; i<DEPTH; i=i+1) begin
            data_buff[i] <= 0; 
            valid_buff[i] <= 0; 
            last_buff[i] <= 0;
        end
    end
    else begin
        if(advance) begin
            data_buff[0] <= s_axis_tdata;
            valid_buff[0] <= s_axis_tvalid;
            last_buff[0] <= s_axis_tlast;
            for(i=1; i<DEPTH; i=i+1) begin
                data_buff[i] <= data_buff[i-1];
                valid_buff[i] <= valid_buff[i-1];
                last_buff[i] <= last_buff[i-1];
            end
        m_axis_tdata <= {M_AXIS_DATA_WIDTH{1'b0}} | data_buff[DEPTH-1];
        m_axis_tvalid <= valid_buff[DEPTH-1];
        m_axis_tlast <= last_buff[DEPTH-1];
        end
    end
end 

assign s_axis_tready = advance;

endmodule