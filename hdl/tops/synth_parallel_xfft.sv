`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

module synth_xfft_top #(
  parameter int FFT_LEN=2048, // full n-point fft len
  parameter int FFT_CONF_WID=16,
  parameter int FFT_STAT_WID=8,
  parameter int TUSER=8,
  parameter TWIDDLE_FILE="twiddle_n2048_b23.bin"
) (
  input wire logic clk,
  input wire logic rst,

  input wire cx_pkt_t s_axis_tdata,
  input wire logic s_axis_tvalid,
  output logic s_axis_tready,
  input wire logic s_axis_tlast,

  alpaca_xfft_config_axis.SLV s_axis_fft_config_x2,
  alpaca_xfft_config_axis.SLV s_axis_fft_config_x1,

  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,

  output arith_pkt_t m_axis_Xk_tdata,
  output logic m_axis_Xk_tvalid,
  input wire logic m_axis_Xk_tready,
  output logic m_axis_Xk_tlast,
  output logic [2*TUSER-1:0] m_axis_Xk_tuser,

  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(2), .TUSER(TUSER)) s_axis();
alpaca_data_pkt_axis #(.dtype(arith_t), .SAMP_PER_CLK(2), .TUSER(2*TUSER)) m_axis_Xk();


assign s_axis.tdata  = s_axis_tdata;
assign s_axis.tvalid = s_axis_tvalid;
assign s_axis_tready = s_axis.tready;
assign s_axis.tlast  = s_axis_tlast;
assign s_axis.tuser  = '0;

assign m_axis_Xk_tdata  = m_axis_Xk.tdata;
assign m_axis_Xk_tvalid = m_axis_Xk.tvalid;
assign m_axis_Xk.tready = m_axis_Xk_tready;
assign m_axis_Xk_tlast  = m_axis_Xk.tlast;
assign m_axis_Xk_tuser  = m_axis_Xk.tuser;

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

endmodule
