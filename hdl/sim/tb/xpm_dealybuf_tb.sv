`timescale 1ns/1ps
`default_nettype none

/********************************
  Simulation top modules
*********************************/
module impulse_xpm_delaybuf_top #(
  parameter int FFT_LEN=32
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.MST m_axis
);

localparam samp_per_clk = m_axis.samp_per_clk;
alpaca_data_pkt_axis #(.TUSER(1)) s_axis();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(0),
  .IMPULSE_VAL(256)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

xpm_delaybuf #(
  .FIFO_DEPTH(FFT_LEN/samp_per_clk),
  .TUSER(1)
) xpm_delay_buf_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis),
  .m_axis(m_axis)
);

endmodule : impulse_xpm_delaybuf_top

/*
  TODO:
  The original xpm_delaybuf was tested with a counter but the parallel version of
  the `src_ctr` module is not up and running yet as `xpm_delaybuf` needed to be
  changed to now use the `alpaca_data_pkt_axis` interface it has broken compatability
  with the `src_ctr` module as is. So I have deleted all of that code here.

  module ctr_xpm_delaybuf_top #(
    parameter int WIDTH
  ) (

  );

  parallel_src_ctr #(
  ) src (
  );

  );

  endmodule
*/

/****************************************************************************
  xpm_delaybuf testbench 

  Tests xpm_delaybuf by sending samples through a buffer, waits the length of
  the buffer then checks by stepping through the memory contants of the source
  that sent the data through the buffer

******************************************************************************/
import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;

module xpm_delaybuf_tb();

logic clk, rst;
alpaca_data_pkt_axis #(.TUSER(1)) m_axis();

typedef m_axis.data_pkt_t data_pkt_t;
localparam samp_per_clk = m_axis.samp_per_clk;
localparam mem_depth = FFT_LEN/samp_per_clk;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);
impulse_xpm_delaybuf_top #(.FFT_LEN(FFT_LEN)) DUT (.*);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  simcycles=0;
  forever @(posedge clk)
    simcycles += (1 & clk);// & ~rst;
end

initial begin
  int errors;
  data_pkt_t dout, expected;
  logic [$clog2(mem_depth)-1:0] expected_ctr;

  errors = 0;

  rst <= 1; dout <= '0; expected <= '0; expected_ctr <= '0;
  wait_cycles(20);
  @(posedge clk);
  @(negedge clk); rst = 1'b0; m_axis.tready = 1'b1;

  @(posedge DUT.s_axis.tready);

  // no output should come waiting for the fifo to fill
  for (int i=0; i<FFT_LEN; i++) begin
    wait_cycles();
    $display(m_axis.print());
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
    $display(m_axis.print());
    dout = (m_axis.tready & m_axis.tvalid) ? m_axis.tdata : '0;
    expected = DUT.impulse_gen_inst.ram[expected_ctr];
    if (dout != expected | dout === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", RED, simcycles, expected, dout, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s", GRN, simcycles, expected, dout, RST);
    end
    expected_ctr++;
  end

  //$display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end


endmodule
