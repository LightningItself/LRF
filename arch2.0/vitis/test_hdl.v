module LRF_DT #(
    parameter FRAME_WIDTH = 512,
    parameter FRAME_HEIGHT = 512,
    parameter PIXEL_WIDTH = 8
)(
    input wire aclk,
    input wire aresetn,

    // AXIS Slave Input
    input  wire [PIXEL_WIDTH-1:0] s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    // AXIS Master Output
    output reg  [PIXEL_WIDTH-1:0] m_axis_tdata,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,
    output reg                    m_axis_tlast
);

    // Constants
    localparam TOTAL_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;

    // Memory buffer (inferred BRAM)
    reg [PIXEL_WIDTH-1:0] buffer [0:TOTAL_PIXELS-1];

    // Write and read pointers
    reg [17:0] wr_addr;
    reg [17:0] rd_addr;

    // Frame count (up to 32)
    reg [5:0] frame_count;

    // State encoding
    localparam IDLE    = 2'd0;
    localparam WRITING = 2'd1;
    localparam READING = 2'd2;

    reg [1:0] state;

    // Assign ready signal
    assign s_axis_tready = (state == WRITING);

    // Sequential logic
    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            state          <= IDLE;
            wr_addr        <= 18'd0;
            rd_addr        <= 18'd0;
            frame_count    <= 6'd0;
            m_axis_tdata   <= {PIXEL_WIDTH{1'b0}};
            m_axis_tvalid  <= 1'b0;
            m_axis_tlast   <= 1'b0;
        end else begin
            case (state)
                // -------------------------------
                IDLE: begin
                    if (s_axis_tvalid) begin
                        wr_addr     <= 18'd0;
                        state       <= WRITING;
                    end
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                end

                // -------------------------------
                WRITING: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        buffer[wr_addr] <= s_axis_tdata;
                        wr_addr <= wr_addr + 1;

                        if (s_axis_tlast || wr_addr == (TOTAL_PIXELS - 1)) begin
                            frame_count <= frame_count + 1;
                            wr_addr <= 18'd0;

                            if (frame_count == 6'd31) begin
                                state    <= READING;
                                rd_addr  <= 18'd0;
                            end
                        end
                    end
                end

                // -------------------------------
                READING: begin
                    if (m_axis_tready) begin
                        m_axis_tdata  <= buffer[rd_addr];
                        m_axis_tvalid <= 1'b1;

                        if (rd_addr == (TOTAL_PIXELS - 1)) begin
                            m_axis_tlast  <= 1'b1;
                            state         <= IDLE;
                            frame_count   <= 6'd0;
                        end else begin
                            rd_addr <= rd_addr + 1;
                            m_axis_tlast <= 1'b0;
                        end
                    end else begin
                        m_axis_tvalid <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule