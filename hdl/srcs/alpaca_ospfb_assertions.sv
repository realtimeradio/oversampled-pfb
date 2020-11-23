`timescale 1ns/1ps
`default_nettype none

module alpaca_ospfb_assertions (
  input wire logic clk,
  input wire logic rst,

  input wire logic [1:0] event_frame_started,
  input wire logic [1:0] event_tlast_unexpected,
  input wire logic [1:0] event_tlast_missing,
  input wire logic [1:0] event_fft_overflow,
  input wire logic [1:0] event_data_in_channel_halt
);

property fft_ovflow;
  @(posedge clk) disable iff (rst)
  (event_fft_overflow == 2'b0)
endproperty

chk_fft_ovflow: assert property (fft_ovflow) else $fatal(0, "FFT overflow occured");

endmodule : alpaca_ospfb_assertions



