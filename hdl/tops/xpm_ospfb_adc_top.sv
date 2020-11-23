`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/******************************************************************************************
  Top module : adc model -> sample delay -> dual-clock fifo -> ospfb  -> axis capture
*******************************************************************************************/

module xpm_ospfb_adc_top #(
  parameter int SAMP_PER_CLK=2,
  // ospfb
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter twiddle_factor_t WK,
  // source adc
  parameter real SRC_PERIOD=10,
  parameter real F_SOI_NORM=0.27,
  parameter real ADC_GAIN=1.0,
  parameter int ADC_BITS=12,
  parameter int SIGMA_BIT=6,
  // dc fifo
  parameter int DC_FIFO_DEPTH=32,
  // vip capture
  parameter int FRAMES=1
) (
  input wire logic s_axis_aclk, // adc clk
  input wire logic m_axis_aclk, // dsp clk
  input wire logic rst,
  input wire logic en,  // to model an indication for when to mark rfdc data as valid
  // fft status singals
  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,
  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt,
  // vip signal
  output logic vip_full
);

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(1)) s_axis();
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*8)) m_axis_Xk();
// note the above data type is the full width out of the alpaca butterfly

// data source for simulation
adc_model #(
  .PERIOD(SRC_PERIOD),
  .F_SOI_NORM(F_SOI_NORM),
  .GAIN(ADC_GAIN),
  .BITS(ADC_BITS),
  .SIGMA_BIT(SIGMA_BIT)
) adc_inst (
  .clk(s_axis_aclk),
  .rst(rst),
  .en(en),
  .m_axis(s_axis)
);

xpm_ospfb #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .WK(WK),
  .DC_FIFO_DEPTH(DC_FIFO_DEPTH)
) ospfb_inst (
  .s_axis_aclk(s_axis_aclk),
  .m_axis_aclk(m_axis_aclk),
  .rst(rst),

  .s_axis(s_axis),
  .m_axis_data(m_axis_Xk),

  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);

parallel_axis_vip #(
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) vip_inst (
  .clk(m_axis_aclk),
  .rst(rst),
  .s_axis(m_axis_Xk),
  .full(vip_full)
);

endmodule : xpm_ospfb_adc_top
