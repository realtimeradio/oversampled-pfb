`timescale 1ns/1ps
`default_nettype none

package alpaca_types_unpacked_pkg;

  parameter WIDTH = 16;
  parameter SAMP_PER_CLK = 4; // could get in trouble if this doesn't propagate to module
 
  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  typedef cx_t pkt_unpacked_t[SAMP_PER_CLK]; // unpacked type declaration
 
endpackage

import alpaca_types_unpacked_pkg::*;

module impulse_generator3 #(
  parameter type pkt_t = pkt_unpacked_t,
  // the whole point of the pkt_t was to not need this
  // but how else do I know when to assert tlast
  parameter int SAMP_PER_CLK=SAMP_PER_CLK,//have to set as to make sure package parameter trickle
  parameter int FFT_LEN = 16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,

  input wire logic m_axis_tready,
  output pkt_t m_axis_tdata,
  output logic m_axis_tvalid,
  output logic m_axis_tlast
);

localparam mem_depth = FFT_LEN/SAMP_PER_CLK;

logic [$clog2(mem_depth)-1:0] rAddr;
pkt_t ram [mem_depth]; // unpacked type

initial begin
  for (int i=0; i<mem_depth; i++) begin
    pkt_t pkt;
    for (int j=0; j<SAMP_PER_CLK; j++) begin
      cx_t tmp;
      tmp.re = i*SAMP_PER_CLK + (SAMP_PER_CLK-1-j);
      tmp.im = '0;

      pkt[j] = tmp;
    end
  ram[i] = pkt;
  end
end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (m_axis_tready)
    rAddr <= rAddr + 1;
  else
    rAddr <= rAddr;

assign m_axis_tdata = ram[rAddr];
assign m_axis_tvalid = (~rst & m_axis_tready);
assign m_axis_tlast = (rAddr == (FFT_LEN-SAMP_PER_CLK)) ? 1'b1 : 1'b0;

endmodule

/*********************************
  Testbench
**********************************/
parameter int PERIOD = 10;

parameter int FFT_LEN = 16;
parameter int IMPULSE_PHA = 3;
parameter int IMPULSE_VAL = FFT_LEN;

module tb3();

logic clk, rst;

pkt_unpacked_t m_axis_tdata;
logic m_axis_tvalid, m_axis_tready, m_axis_tlast;

clk_generator #(.PERIOD(PERIOD)) clk_gen (.*);

impulse_generator3 #(
  .pkt_t(pkt_unpacked_t),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) DUT (.*);

task wait_cycles(int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.ram[i]);
  end

  rst <= 1; m_axis_tready <= 0;
  @(posedge clk);
  @(negedge clk); rst = 0;

  wait_cycles(20);
  @(negedge clk); m_axis_tready = 1;
  @(posedge clk);
  for (int i=0; i<2*FFT_LEN; i++) begin
    $display("(m_axis.tdata: 0x%0p)", m_axis_tdata);
    wait_cycles(1);
  end

  $finish;
end

endmodule
