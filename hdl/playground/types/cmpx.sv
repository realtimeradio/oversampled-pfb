`timescale 1ns/1ps
`default_nettype none

interface axis_rfdc #(
  parameter WIDTH=16,
  parameter SAMP_PER_CLK=2
) (
);
  localparam samp_per_clk = SAMP_PER_CLK;
  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  // could probably switch this around for an unpacked type allowing the ram in the module to be
  // unpacked and better recognized as a memory, but there is bit ordering problems (need to fix
  // assignment out. See lines 73/74, they need to change to accomodate.
  //cx_t tdata [SAMP_PER_CLK];
  cx_t [SAMP_PER_CLK-1:0] tdata;
  logic tvalid, tready, tlast;

  modport MST (input tready, output tdata, tvalid, tlast);
  modport SLV (input tdata, tvalid, tlast, output tready);

endinterface

module impulse_generator #(
  parameter int FFT_LEN=16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,
  axis_rfdc.MST m_axis
);

typedef m_axis.cx_t cx_t;
localparam samp_per_clk = m_axis.samp_per_clk;

logic [$clog2(FFT_LEN)-1:0] rAddr;
// possiblilty with above tdata interface definition
//cx_t ram [FFT_LEN];
cx_t [FFT_LEN-1:0] ram;

initial begin
  for (int i=0; i<FFT_LEN; i++) begin
    // Had to create tmp variable to set and make assignment to avoid synthesis warning about
    // not being able to acess re/im elements directly.
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

//always_ff @(posedge clk)
//  if (rst)
//    m_axis.tdata <= '0;
//  else
//    m_axis.tdata <= ram[rAddr +: samp_per_clk];

always_comb begin
  m_axis.tdata = ram[rAddr +: samp_per_clk];
  //m_axis.tdata = ram[rAddr -: samp_per_clk];
  m_axis.tlast = (rAddr == (FFT_LEN-samp_per_clk)) ? 1'b1 : 1'b0;
  m_axis.tvalid = (~rst & m_axis.tready);
end

//assign m_axis.tdata = ram[rAddr +: samp_per_clk];
//assign m_axis.tvalid = (~rst & m_axis.tready);
//assign m_axis.tlast = (rAddr == (FFT_LEN-samp_per_clk)) ? 1'b1 : 1'b0;

endmodule

parameter int PERIOD = 10;

parameter int WIDTH=16;
parameter int SAMP_PER_CLK=4;

parameter int FFT_LEN = 16;
parameter int IMPULSE_PHA = 3;
parameter int IMPULSE_VAL = FFT_LEN;

module tb();

logic clk, rst;
axis_rfdc #(.WIDTH(WIDTH), .SAMP_PER_CLK(SAMP_PER_CLK)) m_axis();

clk_generator #(.PERIOD(PERIOD)) clk_gen (.*);

impulse_generator #(
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
  $display("Source ram contents");
  for (int i=0; i<FFT_LEN; i++) begin
    $display("(re: 0x%0X, im: 0x%0X", DUT.ram[i].re, DUT.ram[i].im);
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
