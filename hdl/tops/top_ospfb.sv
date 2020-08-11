`timescale 1ns/1ps
`default_nettype none

// TODO: ok to import all of constants now?
import alpaca_ospfb_constants_pkg::WIDTH;
import alpaca_ospfb_constants_pkg::COEFF_WID;
import alpaca_ospfb_constants_pkg::FFT_LEN;
import alpaca_ospfb_constants_pkg::DEC_FAC;
import alpaca_ospfb_constants_pkg::PTAPS;
import alpaca_ospfb_constants_pkg::SRLEN;

module top #(parameter WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic signed [WIDTH-1:0] s_tdata,
  input wire logic s_tvalid,
  output logic s_tready,

  output logic signed [WIDTH-1:0] m_tdata,
  output logic m_tvalid,
  input wire logic m_tready
);

axis #(.WIDTH(WIDTH)) m_axis(), s_axis();

assign s_axis.tdata = s_tdata;
assign s_axis.tvalid = s_tvalid;
assign s_tready = s_axis.tready;

assign m_tdata = m_axis.tdata;
assign m_tvalid = m_axis.tvalid;
assign m_axis.tready = m_tready;

// START HERE:
// 1) Note - Need to remove maxis_tready in pe fsm to get vivado to not warn
// 2) Why no DSP? Had one until starting to get ports connected correctly then it disapperared
//
//OSPFB #(
//  .WIDTH(16),
//  .COEFF_WID(16),
//  .FFT_LEN(512),
//  .DEC_FAC(384),
//  .PTAPS(8),
//  .SRLEN(64)
//) DUT (.*);

OSPFB #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) DUT (.*);

endmodule
