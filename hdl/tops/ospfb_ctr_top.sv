`timescale 1ns/1ps
`default_nettype none

module ospfb_ctr_top #(
  parameter int WIDTH=16,
  parameter int FFT_LEN=64,
  parameter int SAMP=FFT_LEN,
  parameter int ORDER="natural",
  parameter int COEFF_WID=16,
  parameter int DEC_FAC=48,
  parameter int SRT_PHA=DEC_FAC-1,
  parameter int PTAPS=3,
  parameter int SRLEN=4,
  parameter int CONF_WID=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,

  axis.MST m_axis_fir,
  axis.MST m_axis_fft_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt,

  output logic vip_full
);

axis #(.WIDTH(WIDTH)) s_axis();          // counter output
axis #(.WIDTH(2*WIDTH)) s_axis_ospfb();  // replicate counter output into ospfb

axis #(.WIDTH(2*WIDTH)) m_axis_data();
logic m_axis_data_tlast;
logic [7:0] m_axis_data_tuser;

// data source for simulation
src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(FFT_LEN),
  .ORDER("natural")
) src_ctr_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

// replicate counter outputs
assign s_axis_ospfb.tdata = {2{s_axis.tdata}};
assign s_axis_ospfb.tvalid = s_axis.tvalid;
assign s_axis.tready = s_axis_ospfb.tready;

OSPFB #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN),
  .CONF_WID(CONF_WID)
) ospfb_inst (
  .clk(clk),
  .rst(rst),
  .en(en),
  .s_axis(s_axis_ospfb),
  .m_axis_fir(m_axis_fir),
  .m_axis_fft_status(m_axis_fft_status),
  .m_axis_data(m_axis_data),
  .m_axis_data_tlast(m_axis_data_tlast),
  .m_axis_data_tuser(m_axis_data_tuser),
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
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_data),
  .full(vip_full)
);

endmodule
