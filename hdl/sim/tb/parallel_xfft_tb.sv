`timescale 1ns/1ps
`default_nettype none

/******************************************************
  Top module: impulse -> parallel fft -> axis capture
*******************************************************/

module parallel_xfft_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int TUSER=8,
  // capture parameters
  parameter int FRAMES = 2,
  parameter TWIDDLE_FILE=""
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_xfft_config_axis.SLV s_axis_fft_config_x2,
  alpaca_xfft_config_axis.SLV s_axis_fft_config_x1,

  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,

  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt,

  output logic full
);

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(TUSER)) s_axis();
alpaca_data_pkt_axis #(.dtype(arith_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) m_axis_Xk();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

parallel_xfft #(
  .FFT_LEN(FFT_LEN),
  .TUSER(TUSER),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) p_xfft_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis),
  .s_axis_config_x2(s_axis_fft_config_x2),
  .s_axis_config_x1(s_axis_fft_config_x1),

  .m_axis_Xk(m_axis_Xk),

  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt) 
);

axis_vip #(
  //.dtype(arith_pkt_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) Xk_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_Xk),
  .full(full)
);

endmodule : parallel_xfft_top

/*************************
  TESTBENCH
*************************/
parameter int PERIOD = 10;

parameter TWIDDLE_FILE = "../cmpx_mult/twiddle_n32_b23.bin";

parameter int FFT_LEN = 32;
parameter int FRAMES = 1;

parameter int IMPULSE_PHA = 2;
parameter int IMPULSE_VAL = 256;

parameter int TUSER = 8;

module tb();

logic clk, rst;

// xfft defaults to forward transform and a default scaling for selected architecture
alpaca_xfft_config_axis s_axis_fft_config_x1(), s_axis_fft_config_x2();
alpaca_xfft_status_axis m_axis_fft_status_x1(), m_axis_fft_status_x2();

logic [1:0] event_frame_started;
logic [1:0] event_tlast_unexpected;
logic [1:0] event_tlast_missing;
logic [1:0] event_fft_overflow;
logic [1:0] event_data_in_channel_halt;

logic full;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

parallel_xfft_top #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL),
  .TUSER(TUSER),
  .FRAMES(FRAMES),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) DUT (.*);

task wait_cycles(input int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin

  int fp;

  $display("Source ram contents");
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.impulse_gen_inst.ram[i]);
  end
  $display("");

  rst <= 1;
  wait_cycles(5); // xfft needs reset applied for at least 2 cycles.
  @(negedge clk); rst = 0;

  // wait for capture to fill up
  while (~full)
   wait_cycles(1);

  // display capture contents
  for (int i=0; i<FRAMES; i++) begin
    $display("Frame: %0d", i);
    for (int j=0; j<FFT_LEN/SAMP_PER_CLK; j++) begin
      for (int k=0; k<SAMP_PER_CLK; k++) begin
        $display("Xk[%0d]: (re: 0x%0X, im: 0x%0X)", k, DUT.Xk_vip.ram[j][k].re, DUT.Xk_vip.ram[j][k].im);
      end
    end
    $display("");
  end

  // write capture contents for processing
  $writememh("parallel_fft_wbutterfly.hex", DUT.Xk_vip.ram);
  $writememb("parallel_fft_wbutterfly.bin", DUT.Xk_vip.ram);

  $finish;
end

endmodule : tb


