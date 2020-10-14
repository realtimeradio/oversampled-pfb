`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/************************************************************
  Top module: adc_model -> parallel fft -> axis capture
*************************************************************/

module adc_parallel_xfft_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter TWIDDLE_FILE="",
  parameter int TUSER=8,
  // adc model parameters
  parameter real ADC_PERIOD=10,
  parameter int ADC_BITS=12,
  parameter real ADC_GAIN=1.0,
  parameter real F_SOI_NORM=0.27,
  // capture parameters
  parameter int FRAMES = 2
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

  output logic full,
  output logic adc_full
);

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(TUSER)) s_axis();
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(TUSER)) s_axis_fft();
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) s_axis_adc();
alpaca_data_pkt_axis #(.dtype(cx_phase_mac_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) m_axis_Xk();
//alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) m_axis_Xk();

typedef s_axis.data_pkt_t data_pkt_t;
localparam width = $bits(data_pkt_t);

adc_model #(
  .PERIOD(ADC_PERIOD),
  .GAIN(ADC_GAIN),
  .BITS(ADC_BITS),
  .F_SOI_NORM(F_SOI_NORM)
) adc_inst (
  .clk(clk),
  .rst(rst),
  .en(1'b1),
  .m_axis(s_axis)
);

xpm_fifo_axis #(
  .CLOCKING_MODE("common_clock"),
  .FIFO_DEPTH(16),
  .FIFO_MEMORY_TYPE("auto"),
  .SIM_ASSERT_CHK(0),
  .TDATA_WIDTH(width)
) xfft_delay_fifo_inst (
  .almost_empty_axis(),
  .almost_full_axis(),

  .dbiterr_axis(),

  .m_axis_tdata(s_axis_fft.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(s_axis_fft.tlast),
  .m_axis_tstrb(),
  .m_axis_tuser(),
  .m_axis_tvalid(s_axis_fft.tvalid),

  .prog_empty_axis(),
  .prog_full_axis(),

  .rd_data_count_axis(),

  .s_axis_tready(s_axis.tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(clk),
  .m_axis_tready(s_axis_fft.tready),

  .s_aclk(clk),
  .s_aresetn(~rst),

  .s_axis_tdata(s_axis.tdata),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(1'b0),
  .s_axis_tstrb('0),
  .s_axis_tuser('0),
  .s_axis_tvalid(s_axis.tvalid)
);

parallel_xfft #(
  .FFT_LEN(FFT_LEN),
  .TUSER(TUSER),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) p_xfft_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fft),
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

parallel_axis_vip #(
  //.dtype(cx_phase_pkt_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) Xk_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_Xk),
  .full(full)
);

assign s_axis_adc.tdata = s_axis_fft.tdata;
assign s_axis_adc.tvalid = s_axis_fft.tvalid;
assign s_axis_adc.tlast = s_axis_fft.tlast;
assign s_axis_adc.tuser = s_axis_fft.tuser;

parallel_axis_vip #(
  //.dtype(cx_phase_pkt_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) adc_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_adc),
  .full(adc_full)
);

endmodule : adc_parallel_xfft_top

/******************************************************
  Top module: impulse -> parallel fft -> axis capture
*******************************************************/

module impulse_parallel_xfft_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter TWIDDLE_FILE="",
  // impulse parameters
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int TUSER=8,
  // capture parameters
  parameter int FRAMES = 2
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
alpaca_data_pkt_axis #(.dtype(cx_phase_mac_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) m_axis_Xk();
//alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*TUSER)) m_axis_Xk();

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

parallel_axis_vip #(
  //.dtype(cx_phase_pkt_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) Xk_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_Xk),
  .full(full)
);

endmodule : impulse_parallel_xfft_top

/*************************
  TESTBENCH
*************************/
import alpaca_constants_pkg::*;

parameter int FRAMES = 2;

parameter int IMPULSE_PHA = 13;
parameter int IMPULSE_VAL = 128*128;

parameter int TUSER = 8;

module tb();

logic clk, rst;

alpaca_xfft_config_axis s_axis_fft_config_x1(), s_axis_fft_config_x2();
alpaca_xfft_status_axis m_axis_fft_status_x1(), m_axis_fft_status_x2();

logic [1:0] event_frame_started;
logic [1:0] event_tlast_unexpected;
logic [1:0] event_tlast_missing;
logic [1:0] event_fft_overflow;
logic [1:0] event_data_in_channel_halt;

logic full;
logic adc_full;

clk_generator #(.PERIOD(ADC_PERIOD)) clk_gen_inst (.*);

adc_parallel_xfft_top #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .TWIDDLE_FILE(TWIDDLE_FILE),
  .TUSER(TUSER),
  .ADC_PERIOD(ADC_PERIOD),
  .ADC_BITS(ADC_BITS),
  .ADC_GAIN(ADC_GAIN),
  .F_SOI_NORM(F_SOI_NORM),
  .FRAMES(FRAMES)
) DUT (.*);

//impulse_parallel_xfft_top #(
//  .FFT_LEN(FFT_LEN),
//  .SAMP_PER_CLK(SAMP_PER_CLK),
//  .TWIDDLE_FILE(TWIDDLE_FILE),
//  .TUSER(TUSER),
//  .IMPULSE_PHA(IMPULSE_PHA),
//  .IMPULSE_VAL(IMPULSE_VAL),
//  .FRAMES(FRAMES)
//) DUT (.*);

task wait_cycles(input int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin

  //$display("Source ram contents");
  //for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
  //  $display("(ram: 0x%0p", DUT.impulse_gen_inst.ram[i]);
  //end
  //$display("");

  rst <= 1;
  // setup to configure scaling schedule and set to inverse fft
  s_axis_fft_config_x2.tdata <= {1'b0, 2'b10, 2'b10, 2'b10, 1'b0}; s_axis_fft_config_x2.tvalid <= 1'b0;
  s_axis_fft_config_x1.tdata <= {1'b0, 2'b10, 2'b10, 2'b10, 1'b0}; s_axis_fft_config_x1.tvalid <= 1'b0;
  wait_cycles(5); // xfft needs reset applied for at least 2 cycles.
  // apply configuration
  @(negedge clk); rst = 0; s_axis_fft_config_x1.tvalid = 1'b0; s_axis_fft_config_x2.tvalid = 1'b0;

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
  //$writememh("parallel_fft_tb_capture.hex", DUT.Xk_vip.ram);
  $writememb("parallel_fft_tb_capture.txt", DUT.Xk_vip.ram);
  $writememb("parallel_fft_tb_capture_adc.txt", DUT.adc_vip.ram);

  $finish;
end

endmodule : tb


