`timescale 1ns/1ps
`default_nettype none

interface axis #(parameter WIDTH=16, parameter SAMP_PER_CLK=2) ();

  localparam TWID = 2*SAMP_PER_CLK*WIDTH;

  wire logic [2*WIDTH-1:0] tdata [SAMP_PER_CLK];
  logic tvalid, tlast, tready;

  localparam samp_per_clk = SAMP_PER_CLK;

  modport MST (input tready, output tdata, tvalid, tlast);
  modport SLV (input tdata, tvalid, tlast, output tready);

endinterface

module impulse_generator2 #(
  parameter int FFT_LEN=16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

localparam twid = m_axis.TWID;
localparam samp_per_clk = m_axis.samp_per_clk;
localparam width = twid/(2*samp_per_clk);

typedef struct packed {
  logic signed [width-1:0] im;
  logic signed [width-1:0] re;
} cx_t;

logic [$clog2(FFT_LEN)-1:0] rAddr;
cx_t ram [FFT_LEN];

initial begin
  for (int i=0; i<FFT_LEN; i++) begin
    cx_t tmp;
    tmp.re = i;
    tmp.im = '0;
    ram[i] = tmp;
    //ram[i].re = i;//(i==IMPULSE_PHA) ? IMPULSE_VAL : '0;
    //ram[i].im = '0;
  end
end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (m_axis.tready)
    rAddr <= rAddr + samp_per_clk;
  else
    rAddr <= rAddr;

assign m_axis.tdata = ram[rAddr +: samp_per_clk];
assign m_axis.tvalid = (~rst & m_axis.tready);
assign m_axis.tlast = (rAddr == (FFT_LEN-samp_per_clk)) ? 1'b1 : 1'b0;

endmodule

parameter int PERIOD = 10;

parameter int WIDTH=16;
parameter int SAMP_PER_CLK=4;

parameter int FFT_LEN = 16;
parameter int IMPULSE_PHA = 3;
parameter int IMPULSE_VAL = FFT_LEN;

module tb2();

logic clk, rst;
axis #(.WIDTH(WIDTH), .SAMP_PER_CLK(SAMP_PER_CLK)) m_axis();

clk_generator #(.PERIOD(PERIOD)) clk_gen (.*);

impulse_generator2 #(
  .FFT_LEN(FFT_LEN),
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
  for (int i=0; i<FFT_LEN; i++) begin
    $display("(re: 0x%0X, im: 0x%0X", DUT.ram[i].re, DUT.ram[i].im);
  end

  rst <= 1; m_axis.tready <= 0;
  @(posedge clk);
  @(negedge clk); rst = 0;

  wait_cycles(20);
  @(negedge clk); m_axis.tready = 1;
  @(posedge clk);
  for (int i=0; i<2*FFT_LEN; i++) begin
    $display("(m_axis.tdata: 0x%0p)", m_axis.tdata); // %p packed
    wait_cycles(1);
  end

  $finish;
end

endmodule
