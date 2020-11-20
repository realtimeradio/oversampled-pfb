`timescale 1ns/1ps
`default_nettype none

module xpm_delaybuf #(
  parameter FIFO_DEPTH=64,
  parameter TUSER=1,
  parameter MEM_TYPE="auto"
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis,
  alpaca_data_pkt_axis.MST m_axis
);

typedef s_axis.data_pkt_t data_pkt_t;
typedef s_axis.data_t data_t;
localparam samp_per_clk = s_axis.samp_per_clk;
localparam width = s_axis.width;

alpaca_data_pkt_axis #(
  .dtype(data_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(TUSER)
) s_axis_delaybuf(), m_axis_delaybuf();

logic [$clog2(FIFO_DEPTH):0] rd_data_count;
logic almost_full;

typedef enum logic [1:0] {WAIT_START, WAIT_FILLED, FILLED, ERR='X} delaybuf_state_t;
delaybuf_state_t cs, ns;

always_ff @(posedge clk)
  cs <= ns;

logic new_sample;
always_comb begin
  ns = ERR;
  // module m_axis bus
  m_axis.tdata = '0;//32'hda7a_f1f0; // data_fifo - garbage
  m_axis.tvalid = 1'b0;
  m_axis.tuser = 1'b0;

  // module s_axis bus to delaybuf fifo
  s_axis.tready = s_axis_delaybuf.tready;
  new_sample = (s_axis.tready & s_axis.tvalid);

  s_axis_delaybuf.tvalid = s_axis.tvalid;
  s_axis_delaybuf.tdata = new_sample ? s_axis.tdata : '0;//32'hf1f0_da7a;
  s_axis_delaybuf.tuser = new_sample ? s_axis.tuser : 1'bx;

  // m_axis bus to delaybuf fifo
  m_axis_delaybuf.tready = 1'b0;

  if (rst) begin
    ns = WAIT_START;
  end else begin
    case (cs)
      // do not accept data until upstream indicates ready and it is assumed that the slave will
      // wait to fill the fifo up (I AMBA standard says upstream has to wait after asserted)
      WAIT_START: begin
        if (s_axis_delaybuf.tready & m_axis.tready)
          ns = WAIT_FILLED;
        else
          ns = WAIT_START;
      end
      // when the upstream is ready begin to accept data
      WAIT_FILLED: begin
        if (rd_data_count == FIFO_DEPTH-1) begin
          ns = FILLED;
          m_axis_delaybuf.tready = m_axis.tready;
          m_axis.tvalid = m_axis_delaybuf.tvalid;
          m_axis.tdata = m_axis_delaybuf.tdata;
          m_axis.tuser = m_axis_delaybuf.tuser;
        end else begin
          ns = WAIT_FILLED;
        end
      end

      FILLED: begin
        ns = FILLED;
        m_axis_delaybuf.tready = m_axis.tready;
        m_axis.tvalid = m_axis_delaybuf.tvalid;
        m_axis.tdata = m_axis_delaybuf.tdata;
        m_axis.tuser = m_axis_delaybuf.tuser;
      end
    endcase
  end
end

xpm_fifo_axis #(
  .CLOCKING_MODE("common_clock"),
  .FIFO_DEPTH(FIFO_DEPTH),
  .FIFO_MEMORY_TYPE(MEM_TYPE),
  .RD_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1),
  .SIM_ASSERT_CHK(0),
  .TDATA_WIDTH(width),
  .TUSER_WIDTH(TUSER),
  .USE_ADV_FEATURES("140C"),
  .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1)
) delaybuf (
  // TODO: hopefully ports are removed in synthesis if not connected or driven
  .almost_empty_axis(),
  .almost_full_axis(almost_full),

  .dbiterr_axis(),

  .m_axis_tdata(m_axis_delaybuf.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(),
  .m_axis_tstrb(),
  .m_axis_tuser(m_axis_delaybuf.tuser), // vout
  .m_axis_tvalid(m_axis_delaybuf.tvalid),

  .prog_empty_axis(),
  .prog_full_axis(),

  .rd_data_count_axis(rd_data_count),

  .s_axis_tready(s_axis_delaybuf.tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(clk),
  .m_axis_tready(m_axis_delaybuf.tready),

  .s_aclk(clk),
  .s_aresetn(~rst),

  .s_axis_tdata(s_axis_delaybuf.tdata),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(1'b0),
  .s_axis_tstrb('0),
  .s_axis_tuser(s_axis_delaybuf.tuser), // vin
  .s_axis_tvalid(s_axis_delaybuf.tvalid)
);

endmodule
