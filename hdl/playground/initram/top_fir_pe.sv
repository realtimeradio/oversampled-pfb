`timescale 1ns/1ps
`default_nettype none

parameter WIDTH = 16;
parameter COEFF_WID = 16;
parameter PTAPS = 4;
parameter NTAPS = 8;

//parameter [NTAPS] [COEFF_WID-1:0] coeff_set [PTAPS] = {
//  {COEFF_WID'{

parameter logic signed [COEFF_WID-1:0] foobar [PTAPS*NTAPS] = {
  16'h0, 16'h1, 16'h2, 16'h3, 16'h4, 16'h5, 16'h6, 16'h7,
  16'h8, 16'h9, 16'ha, 16'hb, 16'hc, 16'hd, 16'he, 16'hf,
  16'h10, 16'h11, 16'h12, 16'h13, 16'h14, 16'h15, 16'h16, 16'h17,
  16'h18, 16'h19, 16'h1a, 16'h1b, 16'h1c, 16'h1d, 16'h1e, 16'h1f
};

module top_fir (
  input wire logic clk,
  input wire logic rst,

  input wire logic signed [WIDTH-1:0] s_axis_data_tdata,
  input wire logic s_axis_data_tvalid,
  output logic s_axis_data_tready,

  input wire logic signed [WIDTH-1:0] s_axis_sum_tdata,
  input wire logic s_axis_sum_tvalid,
  output logic s_axis_sum_tready,

  output logic signed [WIDTH-1:0] m_axis_data_tdata,
  output logic m_axis_data_tvalid,
  input wire logic m_axis_data_tready,


  output logic signed [WIDTH-1:0] m_axis_sum_tdata,
  output logic m_axis_sum_tvalid,
  input wire logic m_axis_sum_tready
);

  axis #(.WIDTH(WIDTH)) axis_pe_data[PTAPS+1]();
  axis #(.WIDTH(WIDTH)) axis_pe_sum[PTAPS+1]();

  assign axis_pe_data[0].tdata = s_axis_data_tdata;
  assign axis_pe_data[0].tvalid = s_axis_data_tvalid;
  assign s_axis_data_tready = axis_pe_data[0].tready;

  assign axis_pe_sum[0].tdata = s_axis_sum_tdata;
  assign axis_pe_sum[0].tvalid = s_axis_sum_tvalid;
  assign s_axis_sum_tready = axis_pe_sum[0].tready;

  assign m_axis_data_tdata = axis_pe_data[PTAPS].tdata;
  assign m_axis_data_tvalid = axis_pe_data[PTAPS].tvalid;
  assign axis_pe_data[PTAPS].tready = m_axis_data_tready;

  assign m_axis_sum_tdata = axis_pe_sum[PTAPS].tdata;
  assign m_axis_sum_tvalid = axis_pe_sum[PTAPS].tvalid;
  assign axis_pe_sum[PTAPS].tready = m_axis_sum_tready;

  genvar pp;
  generate
    for (pp=0; pp < PTAPS; pp++) begin : gen_pe
      localparam logic signed [COEFF_WID-1:0] taps [NTAPS] = foobar[pp*NTAPS:(pp+1)*NTAPS-1];
      fir_pe #(
        .WIDTH(WIDTH),
        .COEFF_WID(COEFF_WID),
        .NTAPS(NTAPS),
        .TAPS(taps)
      ) pe (
        .clk(clk),
        .rst(rst),
        .s_axis_data(axis_pe_data[pp]),
        .s_axis_sum(axis_pe_sum[pp]),
        .m_axis_data(axis_pe_data[pp+1]),
        .m_axis_sum(axis_pe_sum[pp+1])
      );
    end
  endgenerate
endmodule


