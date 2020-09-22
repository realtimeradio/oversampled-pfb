`timescale 1ns/1ps
`default_nettype none

/*
  copied from parallel xfft development as a module to keep

  At the time, this module was used to test the new impulse generator and axis_vip
  modules that worked on multiple samples per clock.

  However using this and revisiting the BRAM generator + controller capture this
  could be a good way to test everything is working
*/

module impulse_passthrough_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int TUSER=8,
  // capture parameters
  parameter int FRAMES = 2

) (
  input wire logic clk,
  input wire logic rst,

  output logic [1:0] full
);

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(TUSER)) s_axis();
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(1), .TUSER(TUSER)) m_axis_x1(), m_axis_x2();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

seperate_stream ss_inst (//no clk -- combinational circuit
  .s_axis(s_axis),
  .m_axis_x2(m_axis_x2),
  .m_axis_x1(m_axis_x1)
);

axis_vip #(
  //.dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x2_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_x2),
  .full(full[1])
);

axis_vip #(
  //.dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x1_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_x1),
  .full(full[0])
);

endmodule : impulse_passthrough_top

