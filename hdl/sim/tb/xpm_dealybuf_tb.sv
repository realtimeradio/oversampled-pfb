`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_constants_pkg::*;

parameter int FIFO_DEPTH=FFT_LEN;

module xpm_delaybuf_tb();

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
  .TUSER_WIDTH(1)
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
