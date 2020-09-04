`timescale 1ns/1ps
`default_nettype none

module fir_pe #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter NTAPS=64,
  parameter logic signed [COEFF_WID-1:0] TAPS [NTAPS]
) (
  input wire logic clk,
  input wire logic rst,

  axis.SLV s_axis_data,
  axis.SLV s_axis_sum,

  axis.MST m_axis_data,
  axis.MST m_axis_sum

);
logic new_sum_sample, new_data_sample, new_mac;

logic signed [WIDTH-1:0] din;
logic signed [WIDTH-1:0] sin;
logic signed [2*WIDTH-1:0] mac;

logic signed [COEFF_WID-1:0] coeff_ram [NTAPS] = TAPS;
logic signed [COEFF_WID-1:0] h;
logic [$clog2(NTAPS)-1:0] coeff_ctr;

always_ff @(posedge clk)
  if (rst)
    coeff_ctr <= '0;
  else if (new_mac)
    coeff_ctr <= coeff_ctr + 1;
  else
    coeff_ctr <= coeff_ctr;

always_ff @(posedge clk)
  if (rst)
    sin <= '0;
  else if (new_sum_sample)
    sin <= s_axis_sum.tdata;
  else
    sin <= sin;

always_ff @(posedge clk)
  if (rst)
    din <= '0;
  else if (new_data_sample)
    din <= s_axis_data.tdata;
  else
    din <= din;

// the idea would be to trigger do the sum when you have a new din and a new sin
// capture then wait until you have both
always_comb begin
  new_sum_sample = (s_axis_sum.tready & s_axis_sum.tvalid);
  new_data_sample = (s_axis_data.tready & s_axis_data.tvalid);

  h = coeff_ram[coeff_ctr];
  mac = din*h + sin;
end

assign m_axis_sum.tdata = mac;
assign m_axis_sum.tvalid = 1'b0; // needs work

endmodule 
