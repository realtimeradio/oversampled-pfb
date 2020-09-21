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

  input wire logic [FFT_CONF_WID-1:0] s_axis_fft_config_x2_tdata,
  input wire logic s_axis_fft_config_x2_tvalid,
  output wire logic s_axis_fft_config_x2_tready,

  input wire logic [FFT_CONF_WID-1:0] s_axis_fft_config_x1_tdata,
  input wire logic s_axis_fft_config_x1_tvalid,
  output wire logic s_axis_fft_config_x1_tready,

  output logic [FFT_STAT_WID-1:0] m_axis_fft_status_x2_tdata,
  output logic m_axis_fft_status_x2_tvalid,

  output logic [FFT_STAT_WID-1:0] m_axis_fft_status_x1_tdata,
  output logic m_axis_fft_status_x1_tvalid,

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

alpaca_axis #(.dtype(cx_pkt_t), .TUSER(TUSER)) s_axis();
alpaca_axis #(.dtype(arith_pkt_t), .TUSER(2*TUSER)) m_axis_Xk();

alpaca_axis #(.dtype(logic [FFT_CONF_WID-1:0]), .TUSER(TUSER)) s_axis_fft_config_x1(), s_axis_fft_config_x2();
alpaca_axis #(.dtype(logic [FFT_STAT_WID-1:0]), .TUSER(TUSER)) m_axis_fft_status_x1(), m_axis_fft_status_x2();

// note: driving unused signals in the protocol to help readability (and probably good style) of
// the synthesis report.

// Thinking of moving to defining several different interface types that should resolve unused
// signals in the protocol and having more descriptive names etc.
assign s_axis.tdata  = s_axis_tdata;
assign s_axis.tvalid = s_axis_tvalid;
assign s_axis_tready = s_axis.tready;
assign s_axis.tlast  = s_axis_tlast;
assign s_axis.tuser  = '0;

assign s_axis_fft_config_x2.tdata  = s_axis_fft_config_x2_tdata;
assign s_axis_fft_config_x2.tvalid = s_axis_fft_config_x2_tvalid;
assign s_axis_fft_config_x2_tready = s_axis_fft_config_x2.tready;

assign s_axis_fft_config_x1.tdata  = s_axis_fft_config_x1_tdata;
assign s_axis_fft_config_x1.tvalid = s_axis_fft_config_x1_tvalid;
assign s_axis_fft_config_x1_tready = s_axis_fft_config_x1.tready;

assign m_axis_Xk_tdata  = m_axis_Xk.tdata;
assign m_axis_Xk_tvalid = m_axis_Xk.tvalid;
assign m_axis_Xk.tready = m_axis_Xk_tready;
assign m_axis_Xk_tlast  = m_axis_Xk.tlast;
assign m_axis_Xk_tuser  = m_axis_Xk.tuser;

assign m_axis_fft_status_x2_tdata  = m_axis_fft_status_x2.tdata;
assign m_axis_fft_status_x2_tvalid = m_axis_fft_status_x2.tvalid;

assign m_axis_fft_status_x1_tdata  = m_axis_fft_status_x1.tdata;
assign m_axis_fft_status_x1_tvalid = m_axis_fft_status_x1.tvalid;

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
