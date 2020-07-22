`timescale 1ns/1ps
`default_nettype none

module ospfb_ctr_top #(
  parameter int WIDTH = 16,
  parameter int FFT_LEN = 64,
  parameter int ORDER = "natural",
  parameter int COEFF_WID = 16,
  parameter int DEC_FAC = 48,
  parameter int SRT_PHA = DEC_FAC-1,
  parameter int PTAPS = 3,
  parameter int SRLEN = 4
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  axis.MST m_axis
);

axis #(.WIDTH(WIDTH)) s_axis();

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

OSPFB #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) ospfb_inst (
  .clk(clk),
  .rst(rst),
  .en(en),
  .m_axis(m_axis),
  .s_axis(s_axis)
);

endmodule
