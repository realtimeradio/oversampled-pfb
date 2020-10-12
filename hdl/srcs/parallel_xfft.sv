`timescale 1ns/1ps
`default_nettype none

/*******************************************************
  Simple parallel 2-sample input fft from Xilinx fft's
********************************************************/
module parallel_xfft #(
  parameter int FFT_LEN=16,
  parameter int TUSER=8,
  parameter TWIDDLE_FILE=""
) (
  input wire logic clk,
  input wire logic rst,
  // data
  alpaca_data_pkt_axis.SLV s_axis,
  alpaca_data_pkt_axis.MST m_axis_Xk,
  // configuration
  alpaca_xfft_config_axis.SLV s_axis_config_x2,
  alpaca_xfft_config_axis.SLV s_axis_config_x1,
  // status
  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,
  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

alpaca_xfft_data_axis s_axis_fft_x2(), s_axis_fft_x1();
alpaca_xfft_data_axis m_axis_fft_x1(), m_axis_fft_x2();

seperate_stream ss_inst (//no clk -- combinational circuit
  .s_axis(s_axis),
  .m_axis_x2(s_axis_fft_x2),
  .m_axis_x1(s_axis_fft_x1)
);

sv_xfft_0_wrapper xfft_2 (
  .clk(clk), 
  .rst(rst),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config(s_axis_config_x2),
  .s_axis_data(s_axis_fft_x2),

  .m_axis_data(m_axis_fft_x2),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status(m_axis_fft_status_x2),

  .event_frame_started(event_frame_started[1]),
  .event_tlast_unexpected(event_tlast_unexpected[1]),
  .event_tlast_missing(event_tlast_missing[1]),
  .event_fft_overflow(event_fft_overflow[1]),
  .event_data_in_channel_halt(event_data_in_channel_halt[1])
);

sv_xfft_0_wrapper xfft_1 (
  .clk(clk), 
  .rst(rst),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config(s_axis_config_x1),
  .s_axis_data(s_axis_fft_x1),

  .m_axis_data(m_axis_fft_x1),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status(m_axis_fft_status_x1),

  .event_frame_started(event_frame_started[0]),
  .event_tlast_unexpected(event_tlast_unexpected[0]),
  .event_tlast_missing(event_tlast_missing[0]),
  .event_fft_overflow(event_fft_overflow[0]),
  .event_data_in_channel_halt(event_data_in_channel_halt[0])
);

alpaca_butterfly #(
  .FFT_LEN(FFT_LEN),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) butterfly_inst (
  .clk(clk),
  .rst(rst),
  .x1(m_axis_fft_x1),
  .x2(m_axis_fft_x2),
  .Xk(m_axis_Xk)
);

endmodule : parallel_xfft

// purley combinational
module seperate_stream
(
  alpaca_data_pkt_axis.SLV s_axis,

  alpaca_xfft_data_axis.MST m_axis_x2, // (odd sample time idx)
  alpaca_xfft_data_axis.MST m_axis_x1  // (even sample time idx)
);

  // just an AXIS passthrough, re-wire
  assign s_axis.tready = (m_axis_x2.tready & m_axis_x1.tready);

  assign m_axis_x2.tdata = s_axis.tdata[0];//[1];
  assign m_axis_x1.tdata = s_axis.tdata[1];//[0];

  assign m_axis_x2.tvalid = s_axis.tvalid;
  assign m_axis_x1.tvalid = s_axis.tvalid;

  assign m_axis_x2.tlast = s_axis.tlast;
  assign m_axis_x1.tlast = s_axis.tlast;

  assign m_axis_x2.tuser = s_axis.tuser;
  assign m_axis_x1.tuser = s_axis.tuser;

endmodule : seperate_stream

/****************************************
  system verilog wrapper for xilinx fft
*****************************************/

module sv_xfft_0_wrapper (
  input wire logic clk,
  input wire logic rst,

  alpaca_xfft_data_axis.SLV     s_axis_data,
  alpaca_xfft_config_axis.SLV   s_axis_config,

  alpaca_xfft_data_axis.MST     m_axis_data,
  alpaca_xfft_status_axis.MST   m_axis_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

  // xilinx fft is reset low
  logic aresetn;
  assign aresetn = ~rst;

  xfft_0 xfft_inst (
    .aclk(clk), 
    .aresetn(aresetn),
    // Confguration channel to set inverse transform and scaling schedule
    // (width dependent on configuration and selected optional features)
    .s_axis_config_tdata(s_axis_config.tdata),
    .s_axis_config_tvalid(s_axis_config.tvalid),
    .s_axis_config_tready(s_axis_config.tready),

    .s_axis_data_tdata(s_axis_data.tdata),
    .s_axis_data_tvalid(s_axis_data.tvalid),
    .s_axis_data_tready(s_axis_data.tready),
    .s_axis_data_tlast(s_axis_data.tlast),

    .m_axis_data_tdata(m_axis_data.tdata),
    .m_axis_data_tvalid(m_axis_data.tvalid),
    .m_axis_data_tlast(m_axis_data.tlast),
    .m_axis_data_tuser(m_axis_data.tuser),
    // Status channel for overflow information and optional Xk index
    // (width dependent on configuration and selected optional features)
    .m_axis_status_tdata(m_axis_status.tdata),
    .m_axis_status_tvalid(m_axis_status.tvalid),

    .event_frame_started(event_frame_started),
    .event_tlast_unexpected(event_tlast_unexpected),
    .event_tlast_missing(event_tlast_missing),
    .event_fft_overflow(event_fft_overflow),
    .event_data_in_channel_halt(event_data_in_channel_halt)
  );

endmodule : sv_xfft_0_wrapper
