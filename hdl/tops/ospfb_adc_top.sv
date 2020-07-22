`timescale 1ns/1ps
`default_nettype none

module ospfb_adc_top #(
  parameter int PERIOD = 10,
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

// NOTE: The input en signal is sent to both modules, need to make sure they don't interfer
// with eachother.

// data source for simulation
adc_model #(
  .PERIOD(PERIOD),
  .TWID(WIDTH),
  .DTYPE("CX")
) adc_inst (
  .clk(clk),
  .rst(rst),
  // TODO: is it time to remove, I think it was temporarily added to test FFT functionality 
  .en(en),
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
) ospfb_isnt (
  .clk(clk),
  .rst(rst),
  .en(en),
  .m_axis(m_axis),
  .s_axis(s_axis)
);

endmodule
