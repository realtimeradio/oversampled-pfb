`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/*
  The RFDC on the XCZU49DR part is the quad ADC part configured to sample in I/Q
  mode the data will be presented on the bus packed as
    {Q1, I1, Q0, I0}
  which is a set of two `cx_t` samples per clk: [{Q1, I1}, {Q0, I0}]. Letting x[n]
  represent a complex time sample (e.g., x[n] = {Qn,In}) we can again write the data
  presented on the output of the RFDC to advance in time as
    [{x1, x0}, {x3, x2}, {x5, x4}, ...]

  However, the first time decimated output of the oversampled pfb relies on only
  time sample x0. To pass {x1, x0} first into the OSPFB would require grouping the
  coefficients in a none intutive way and the outputs from the processing elements
  which represent sequential branch outputs of the polyphase fir would come out of
  order making the phase rotation step more complicated.

  The solution I have here is to then insert a single sample time delay into the
  data stream such that the first sample into the ospfb can be {x0, x-1}. The
  sample `x-1` is a non-causal sample and does not physically exist however it
  just represents junk data. The more important aspect is that the 0th sample,
  and all other samples, are in the correct position in the memory of the filter
  relative to eachother and the filter coefficients.

  The data coming out of here are then:
    [{x0, x-1}, {x2, x1}, {x4, x3}, ...]

  example operation:

  output        |        --------> {x-2, x-2}       --------> {x0, x-1}       -------> {x2, x1}
  shift register| {x-1, x-2, x-3},             {x1, x0, x-1},            {x3, x2, x1},
                |   ^    ^                      ^   ^                     ^   ^
                |   |    |                      |   |                     |   |
  input         |  x1   x0                      x3  x2                    x5  x4

  Now that I am thinking about it, I wonder if another thing I could have done is to
  just ignore the first decimated time step and instead time the operation of the
  filter coefficients such that {x1, x0} are a valid first input and just consider
  the first decimated output as a bogus garbage value? Or in otherwords, choose
  a time value `n` such that the first samples of the rfdc map to {xn, xn-1} such
  that the timing works out conveniently for the ospfb.
*/

module sample_delay
(
  input wire logic clk,

  alpaca_data_pkt_axis.SLV s_axis,
  alpaca_data_pkt_axis.MST m_axis
);

  localparam samp_per_clk = s_axis.samp_per_clk;
  localparam DELAY = 1;
  localparam SAMPLES = samp_per_clk + DELAY;

  cx_t [SAMPLES-1:0] data_delay;
  logic [1:0] axis_delay;

  always_ff @(posedge clk) begin
    if (s_axis.tvalid & m_axis.tready)
      data_delay <= {s_axis.tdata, data_delay[SAMPLES-1]};
    else
      data_delay <= {s_axis.tdata, '0};

    axis_delay <= {s_axis.tvalid, s_axis.tlast};

    m_axis.tdata <= data_delay[SAMPLES-2:0];

    m_axis.tvalid <= axis_delay[1];
    m_axis.tlast  <= axis_delay[0];
  end

  assign s_axis.tready = m_axis.tready;

  assign m_axis.tuser = '0;

endmodule : sample_delay

/*************************
  TOP FOR TESTBENCH
*************************/
module sample_delay_top #(
  parameter int FFT_LEN=16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int SAMP_PER_CLK=2,
  parameter int FRAMES=1
) (
  input wire logic clk,
  input wire logic rst,
  output logic full
);

alpaca_data_pkt_axis s_axis(), m_axis();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

sample_delay sample_delay_inst (
  .clk(clk),
  .s_axis(s_axis),
  .m_axis(m_axis)
);


parallel_axis_vip #(
  //.dtype(arith_pkt_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis),
  .full(full)
);

endmodule : sample_delay_top

/*************************
  TESTBENCH
*************************/
import alpaca_constants_pkg::*;

parameter int PERIOD = 10;
parameter int FRAMES = 2;
parameter int IMPULSE_PHA = 0;
parameter int IMPULSE_VAL = 256;

module sample_delay_tb();

logic clk, rst;
logic full;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

sample_delay_top #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .FRAMES(FRAMES)
) DUT (.*);

task wait_cycles(input int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin

  int fp;
  int ram_frame_offset;

  $display("Source ram contents");
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: %0p", DUT.impulse_gen_inst.ram[i]);
  end
  $display("");

  rst <= 1;
  wait_cycles(5);
  @(negedge clk); rst = 0;

  // wait for capture to fill up
  while (~full)
   wait_cycles(1);

  // display capture contents
  for (int i=0; i<FRAMES; i++) begin
    $display("Frame: %0d", i);
    ram_frame_offset = i*FFT_LEN/SAMP_PER_CLK;
    for (int j=0; j<FFT_LEN/SAMP_PER_CLK; j++) begin
      $display("%0p", DUT.vip.ram[ram_frame_offset + j]);
      //for (int k=0; k<SAMP_PER_CLK; k++) begin
      //  $display("X[%0d]: (re: 0x%0X, im: 0x%0X)",
      //      k,
      //      DUT.vip.ram[ram_frame_offset+j][k].re,
      //      DUT.vip.ram[ram_frame_offset+j][k].im);
      //end
    end
    $display("");
  end

  // write capture contents for processing
  //$writememh("sample_delay_output.hex", DUT.vip.ram);
  //$writememb("sample_delay_output.bin", DUT.vip.ram);

  $finish;
end

endmodule : sample_delay_tb

