`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/*************************************************************
  parallel source generator (from parallel fft development)
**************************************************************/
module impulse_generator6 #(
  parameter int FFT_LEN=16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.MST m_axis
);

  typedef m_axis.data_pkt_t data_pkt_t;
  localparam SAMP_PER_CLK = m_axis.samp_per_clk;
  localparam MEM_DEPTH = FFT_LEN/SAMP_PER_CLK;

  // TODO: this still needs to be fixed for synthesis and does 'signed' make a difference?
  //logic signed [$bits(data_pkt_t)-1:0] ram [MEM_DEPTH];
  data_pkt_t ram [MEM_DEPTH];

  logic [$clog2(MEM_DEPTH)-1:0] rAddr;

  initial begin
    for (int i=0; i<MEM_DEPTH; i++) begin
      data_pkt_t pkt;
      for (int j=0; j<SAMP_PER_CLK; j++) begin
        cx_t tmp;
        // load counter in either real, imaginary or both
        //tmp.re = i*SAMP_PER_CLK+ j;
        //tmp.im = i*SAMP_PER_CLK+ j;
        // load impulse value
        tmp.re = (i*SAMP_PER_CLK+j == IMPULSE_PHA) ? IMPULSE_VAL : '0;
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
  assign m_axis.tuser = '0;

endmodule : impulse_generator6

////////////////////////////////////////

/*

  Single sample impulse generator from original ospfb and xmp_ospfb work

  Impulse generator module for creating a single pulse in a structured way that
  as the pulse propagates through the pfb as the pulse arrives at the fft each
  frame will receive only a single value at a single input location resulting in
  structured ospfb outputs based on the properties of the fft.

  Being that an impulse on the zero-th input to an fft will produce a constant dc value
  on the output of the fft. Then as you move this pulse up you get different complex
  sinusiodal outputs based on the fundamental of the fft. For exmple, moving the pulse
  to the next input gives the lowest frequency wave and so forth on up.

  While the above is true, in general that ordering (zeroth) is in the context of natural
  processing (e.g., what you would do in matlab/python to create an array of values) in
  which in hardware it is streaming processing.

  IMPULSE_PHASE - When thinking about the FFT as a parllel input/output device this is the
                  target input port for the impulse. Where the 0-th will correspond to a
                  constant (DC) output. An impulse in the 1st input position results in the
                  lowest frequency fundamental on the output of the FFT as a complex tone.
                  And so on up to port M-1 of your M-point FFT. 
  MAX_CNT       - The period length for which a sequence repeats. Meaning for a a MAX_CNT
                  value of M, the output sequence will produce an impulse at IMPULSE_PHASE
                  and repeat every M cycles. For PFBs/FFTs this is typically the same as
                  the FFT length. However, the module was made to be reusable.
  PULSE_VAL     - The weight (magnitude) of the impulse
*/

module impulse_generator #(
  parameter int WIDTH=16,
  parameter int IMPULSE_PHASE=0,
  parameter int PULSE_VAL=1,
  parameter int MAX_CNT=32
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

localparam logic [WIDTH-1:0] pulse_val = PULSE_VAL;

logic [WIDTH-1:0] dout;
logic [$clog2(MAX_CNT)-1:0] ctr;

always_ff @(posedge clk)
  if (rst)
    ctr <= '0;
  else if (m_axis.tready)
    ctr <= ctr + 1;
  else
    ctr <= ctr;

/*
  TODO: Note, that to get the timing to match what I think it should be based on the
  python simulation I switched to an always comb instead of a always_ff.
  This means that in hardware the cycle that ctr==IMPULSE_PHASE logic will propagate
  to change dout to be the PULSE_VAL. Which seems OK in that all it is hurting is
  the max speed of the circuit since we are not regisering the output.

  When trying to do always_ff and look ahead at IMPULSE_PHASE-1 I wasn't seeing any
  output and there is a bug there and so I went with always_comb

  The todo here is that I hope that this approach to sort of bend to conform to python
  isn't hurting the hardware design and that I should go back and think this through.
  I don't think it is but if anything I need to bend python to conform to hardware
  since that is what this needs to be at the end of day. So I just need to make sure I
  am not getting it backwards.
*/
always_comb begin
  dout = '0;
  if (ctr == IMPULSE_PHASE)
    dout = PULSE_VAL;
end

//always_ff @(posedge clk)
//  if (rst)
//    dout <= '0;
//  else if (ctr == IMPULSE_PHASE)
//    dout <= pulse_val;
//  else
//    dout <= '0;

assign m_axis.tvalid = m_axis.tready;
assign m_axis.tdata = dout;

endmodule

module top #(
  parameter int WIDTH=16,
  parameter int IMPULSE_PHASE=0,
  parameter int PULSE_VAL=1,
  parameter int MAX_CNT=32,
  parameter int START=23,
  parameter int PAUSE=24
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

  axis #(.WIDTH(WIDTH)) s_axis();

  impulse_generator #(
    .WIDTH(WIDTH),
    .IMPULSE_PHASE(IMPULSE_PHASE),
    .PULSE_VAL(PULSE_VAL),
    .MAX_CNT(MAX_CNT)
  ) impulse_gen_inst (
    .clk(clk),
    .rst(rst),
    .m_axis(s_axis)
  );

  pt_ctr #(
    .MAX_CNT(MAX_CNT),
    .START(START),
    .PAUSE(PAUSE)
  ) pt_ctr_inst (
    .clk(clk),
    .rst(rst),
    .s_axis(s_axis),
    .m_axis(m_axis)
  );

endmodule

/*
  Impulse generator test bench
*/

import alpaca_constants_pkg::*;
module test_impulse_generator;

// translating to ospfb parameters
parameter MAX_CNT = 64; // M, FFT_LEN, number polyphase branches
parameter PAUSE = 48;   // D, decimation rate
parameter START = PAUSE-1; // modtimer 

// Note: That the output from this testbench tracks the python impulse generator test
// results with the same impulse phase configurations.
parameter IMPULSE_PHASE = PAUSE+1; //matches D+1 in python
parameter PULSE_VAL = 1;

logic clk, rst;
axis #(.WIDTH(WIDTH)) m_axis();

top #(
  .WIDTH(WIDTH),
  .IMPULSE_PHASE(IMPULSE_PHASE),
  .PULSE_VAL(PULSE_VAL),
  .MAX_CNT(MAX_CNT),
  .START(START),
  .PAUSE(PAUSE)
) DUT (
  .clk(clk),
  .rst(rst),
  .m_axis(m_axis)
);

int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & ~rst;
  end
end

task wait_cycles(input int cycles);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0; m_axis.tready = 1;

  for (int k=0; k < 8; k++) begin

    for (int i=0; i < PAUSE; i++) begin
      wait_cycles(1);
      $display({"T=%0d ", m_axis.print()}, simcycles);
    end

    for (int i=0; i < (MAX_CNT-PAUSE); i++) begin
      wait_cycles(1);
      $display({"T=%0d ", m_axis.print()}, simcycles);
    end

    $display("");
  end

  $finish;
end

endmodule
