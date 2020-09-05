`timescale 1ns/1ps
`default_nettype none

module xpm_ospfb_ctr_top #(
  // data width
  parameter int WIDTH=16,
  // ospfb
  parameter int FFT_LEN=64,
  parameter int COEFF_WID=16,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter logic signed [COEFF_WID-1:0] TAPS [PTAPS*FFT_LEN],
  // fft axis config
  parameter int FFT_CONF_WID=8,
  parameter int FFT_USER_WID=8,
  // source counter
  parameter int ORDER="natural",
  // dc fifo
  parameter int DC_FIFO_DEPTH=32,
  // vip capture
  parameter int SAMP=2048
) (
  input wire logic s_axis_aclk, // adc clk
  input wire logic m_axis_aclk, // dsp clk
  input wire logic rst,
  input wire logic en,

  // fft singals
  axis.MST m_axis_fft_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt,

  // vip signal
  output logic vip_full
);

axis #(.WIDTH(WIDTH)) s_axis();          // counter output
axis #(.WIDTH(2*WIDTH)) s_axis_ospfb(); // replicate counter output into ospfb
logic s_axis_ospfb_tlast;

axis #(.WIDTH(2*WIDTH)) m_axis_data();
logic m_axis_data_tlast;
logic [7:0] m_axis_data_tuser;

// data source for simulation
src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(FFT_LEN),
  .ORDER("natural")
) src_ctr_inst (
  .clk(s_axis_aclk),
  .rst(rst),
  .m_axis(s_axis)
);

// replicate counter outputs
assign s_axis_ospfb.tdata = {2{s_axis.tdata}};
assign s_axis_ospfb.tvalid = s_axis.tvalid;
assign s_axis.tready = s_axis_ospfb.tready;

xpm_ospfb #(
  .WIDTH(WIDTH), // not 2*WIDTH because internal the OSPFB does that
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .LOOPBUF_MEM_TYPE("auto"),
  .DATABUF_MEM_TYPE("auto"),
  .SUMBUF_MEM_TYPE("auto"),
  .FFT_CONF_WID(FFT_CONF_WID),
  .FFT_USER_WID(FFT_USER_WID),
  .DC_FIFO_DEPTH(DC_FIFO_DEPTH)
) ospfb_inst (
  .s_axis_aclk(s_axis_aclk),
  .m_axis_aclk(m_axis_aclk),
  .rst(rst),
  .en(en),
  .s_axis(s_axis_ospfb),
  .s_axis_tlast(s_axis_ospfb_tlast),
  .m_axis_data(m_axis_data),
  .m_axis_data_tlast(m_axis_data_tlast),
  .m_axis_data_tuser(m_axis_data_tuser),
  .m_axis_fft_status(m_axis_fft_status),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);

axis_vip #(
  .WIDTH(2*WIDTH),
  .DEPTH(SAMP)
) vip_inst (
  .clk(m_axis_aclk),
  .rst(rst),
  .s_axis(m_axis_data),
  .full(vip_full)
);

endmodule
