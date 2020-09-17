`timescale 1ns/1ps
`default_nettype none

`define WIDTH 16
`define SAMP_PER_CLK 2
`define CMPX 2

`define FFT_LEN 64
`define IMPULSE_PHA 0
`define IMPULSE_VAL 64

`define TDATA_WID `CMPX*`SAMP_PER_CLK*`WIDTH
`define TNUM_BYTES `TDATA_WID/8

module impulse_generator_wrapper (
  input wire clk,
  input wire rst,

  output wire signed [`TDATA_WID-1:0] m_axis_tdata,
  output wire m_axis_tvalid,
  input wire m_axis_tready,
  output wire m_axis_tlast
);

axis_rfdc #(.WIDTH(`WIDTH), .SAMP_PER_CLK(`SAMP_PER_CLK)) m_axis();

assign m_axis_tdata = m_axis.tdata;
assign m_axis_tvalid = m_axis.tvalid;
assign m_axis.tready = m_axis_tready;
assign m_axis_tlast = m_axis.tlast;

impulse_generator #(
  .FFT_LEN(`FFT_LEN),
  .IMPULSE_PHA(`IMPULSE_PHA),
  .IMPULSE_VAL(`IMPULSE_VAL)
) (
  .clk(clk),
  .rst(rst),
  .m_axis(m_axis)
);

endmodule
