`timescale 1ns/1ps
`default_nettype none

package alpaca_dtypes_pkg;

parameter WIDTH = 16;
parameter SAMP_PER_CLK = 4;

// A single 16-bit 
typedef logic signed [WIDTH-1:0] sample_t;

typedef struct packed {
  logic signed [WIDTH-1:0] im;
  logic signed [WIDTH-1:0] re;
} cx_t;

typedef cx_t [SAMP_PER_CLK-1:0] cx_pkt_t;

typedef sample_t [SAMP_PER_CLK-1:0] fir_t;

endpackage

import alpaca_dtypes_pkg::*;

// If tuser width is a function of the number of bytes then I have the same problem
// of needing to pass in the width because `dtype` won't give it to me
interface alpaca_axis #(parameter type dtype=cx_pkt_t, parameter TUSER=8) ();

  localparam bits = $bits(dtype); // this makes it through synthesis

  dtype tdata;
  logic tvalid, tready;
  logic tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface

module impulse_generator6 #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=SAMP_PER_CLK,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.MST m_axis
);

localparam MEM_DEPTH = FFT_LEN/SAMP_PER_CLK;

logic [$clog2(MEM_DEPTH)-1:0] rAddr;

cx_pkt_t ram [MEM_DEPTH];

initial begin
  for (int i=0; i<MEM_DEPTH; i++) begin
    cx_pkt_t pkt;
    for (int j=0; j<SAMP_PER_CLK; j++) begin
      cx_t tmp;
      tmp.re = i*SAMP_PER_CLK+ j;
      tmp.im = '0;

      pkt[j] = tmp;
    end
  ram[i] = pkt;
  end
end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (m_axis.tready)
    rAddr <= rAddr + 1; //+ samp_per_clk;
  else
    rAddr <= rAddr;

assign m_axis.tdata = { >> {ram[rAddr]}};
assign m_axis.tvalid = (~rst & m_axis.tready);
assign m_axis.tlast = (rAddr == MEM_DEPTH-1) ? 1'b1 : 1'b0;

endmodule

parameter int PERIOD = 10;

parameter int FFT_LEN = 16;
parameter int IMPULSE_PHA = 3;
parameter int IMPULSE_VAL = FFT_LEN;

module tb6();

logic clk, rst;
alpaca_axis #(.dtype(cx_pkt_t), .TUSER(8)) m_axis();

clk_generator #(.PERIOD(PERIOD)) clk_gen (.*);

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) DUT (
  .clk(clk),
  .rst(rst),
  .m_axis(m_axis)
);

task wait_cycles(int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin
  $display("Source ram contents");
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.ram[i]);
  end
  $display("");

  rst <= 1; m_axis.tready <= 0;
  @(posedge clk);
  @(negedge clk); rst = 0;

  wait_cycles(20);
  @(negedge clk); m_axis.tready = 1;
  @(posedge clk);
  for (int i=0; i<2*FFT_LEN; i++) begin
    $display("(m_axis.tdata: 0x%0p)", m_axis.tdata); // could be %p or %X here as a packed type
    wait_cycles(1);
  end

  $finish;
end

endmodule
