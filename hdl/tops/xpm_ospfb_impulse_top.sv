`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/******************************************************************************************
  Top module : impulse -> sample delay -> dual-clock fifo -> ospfb  -> axis capture
*******************************************************************************************/

module xpm_ospfb_impulse_top #(
  parameter int SAMP_PER_CLK=2,
  // ospfb
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter TWIDDLE_FILE="",
  // source impulse 
  parameter int IMPULSE_PHA=DEC_FAC+1,
  parameter int IMPULSE_VAL=64,
  // dc fifo
  parameter int DC_FIFO_DEPTH=32,
  // vip capture
  parameter int FRAMES=1
) (
  input wire logic s_axis_aclk, // adc clk
  input wire logic m_axis_aclk, // dsp clk
  input wire logic rst,
  input wire logic en,
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
alpaca_data_pkt_axis #(.dtype(cx_phase_mac_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*8)) m_axis_Xk();
// note the above data type is the full width out of the alpaca butterfly

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(s_axis_aclk),
  .rst(rst),
  .m_axis(s_axis)
);

xpm_ospfb #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .TWIDDLE_FILE(TWIDDLE_FILE),
  .DC_FIFO_DEPTH(DC_FIFO_DEPTH)
) ospfb_inst (
  .s_axis_aclk(s_axis_aclk),
  .m_axis_aclk(m_axis_aclk),
  .rst(rst),
  .en(en),

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

endmodule : xpm_ospfb_impulse_top
