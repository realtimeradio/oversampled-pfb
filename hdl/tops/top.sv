
`timescale 1ns/1ps
`default_nettype none

module top #(parameter WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

DelayBuf #(
  .DEPTH(4096),
  .SRLEN(256), // tested up to 256, no warnings so far (but no .xdc yet)
  .WIDTH(16)
) DUT (.*);

endmodule
