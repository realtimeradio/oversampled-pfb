parameter MEM_TYPE="auto"
) (
  input wire logic clk,
  input wire logic rst,

  axis.SLV s_axis,
  input wire logic s_axis_tuser,

  axis.MST m_axis,
  output logic m_axis_tuser
);

axis #(.WIDTH(WIDTH)) s_axis_delaybuf(), m_axis_delaybuf();
logic s_axis_delaybuf_tuser, m_axis_delaybuf_tuser;

logic [$clog2(FIFO_DEPTH):0] rd_data_count, wr_data_count;
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
  m_axis_tuser = 1'b0;

  // module s_axis bus to delaybuf fifo
  s_axis.tready = s_axis_delaybuf.tready;
  new_sample = (s_axis.tready & s_axis.tvalid);

  s_axis_delaybuf.tvalid = s_axis.tvalid;
  s_axis_delaybuf.tdata = new_sample ? s_axis.tdata : '0;//32'hf1f0_da7a;
  s_axis_delaybuf_tuser = new_sample ? s_axis_tuser : 1'bx;

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
          m_axis_tuser = m_axis_delaybuf_tuser;
        end else begin
          ns = WAIT_FILLED;
        end
      end

      FILLED: begin
        ns = FILLED;
        m_axis_delaybuf.tready = m_axis.tready;
        m_axis.tvalid = m_axis_delaybuf.tvalid;
        m_axis.tdata = m_axis_delaybuf.tdata;
        m_axis_tuser = m_axis_delaybuf_tuser;
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
  .TDATA_WIDTH(WIDTH),
  .TUSER_WIDTH(TUSER_WIDTH),
  .USE_ADV_FEATURES("140C"),
  .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1)
) delaybuf (
  .almost_full_axis(almost_full),
  .m_axis_tdata(m_axis_delaybuf.tdata),
  .m_axis_tlast(),                      // TODO: hopefully removed in synthesis not driven
  .m_axis_tuser(m_axis_delaybuf_tuser), // vout
  .m_axis_tvalid(m_axis_delaybuf.tvalid),
  .rd_data_count_axis(rd_data_count),
  .s_axis_tready(s_axis_delaybuf.tready),
  .wr_data_count_axis(wr_data_count),
  .m_aclk(clk),
  .m_axis_tready(m_axis_delaybuf.tready),
  .s_aclk(clk),
  .s_aresetn(~rst),
  .s_axis_tdata(s_axis_delaybuf.tdata),
  .s_axis_tlast(1'b0),                  // hoepfully removed in synthesis
  .s_axis_tuser(s_axis_delaybuf_tuser), // vin
  .s_axis_tvalid(s_axis_delaybuf.tvalid)
);

endmodule
/*

*/

import alpaca_ospfb_constants_pkg::*;
parameter int PERIOD = 10;
parameter int WIDTH = 16;
parameter int FFT_LEN=16;
parameter int DEC_FAC=12;

parameter int FIFO_DEPTH=FFT_LEN;
parameter int TUSER_WIDTH=1;

module xpm_delaybuf_test();

logic clk, rst;
axis #(.WIDTH(WIDTH)) m_axis(), s_axis();
logic m_axis_tuser, s_axis_tuser;

src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(FFT_LEN),
  .ORDER("natural")
) src (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

xpm_delaybuf #(
  .WIDTH(WIDTH),
  .FIFO_DEPTH(FIFO_DEPTH),
  .TUSER_WIDTH(TUSER_WIDTH)
) DUT (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis),
  .s_axis_tuser(s_axis_tuser),
  .m_axis(m_axis),
  .m_axis_tuser(m_axis_tuser)
);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
clk <= 0; simcycles = 0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & (~rst & s_axis.tready);
  end
end

initial begin
  logic [WIDTH-1:0] expected;
  logic [WIDTH-1:0] dout;
  int errors;
  rst <= 1; expected <= '0;
  wait_cycles(20);
  @(posedge clk);
  @(negedge clk); rst = 1'b0; m_axis.tready = 1'b1; s_axis_tuser = 1'b1;

  @(posedge s_axis.tready);

  $display("Cycle=%4d: Finished init...", simcycles);
  // no output should come waiting for the fifo to fill
  for (int i=0; i<FFT_LEN; i++) begin
    wait_cycles();
    dout = (m_axis.tready & m_axis.tvalid) ? m_axis.tdata : '0;
    if (dout != expected | dout === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", RED, simcycles, expected, dout, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", GRN, simcycles, expected, dout, RST);
    end
  end

  // start checking output
  $display("Waited length of FIFO...");
  for (int i=0; i<2*FFT_LEN; i++) begin
    wait_cycles();
    dout = (m_axis.tready & m_axis.tvalid) ? m_axis.tdata : '0;
    if (dout != expected | dout === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", RED, simcycles, expected, dout, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", GRN, simcycles, expected, dout, RST);
    end
    expected++;
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end


endmodule

