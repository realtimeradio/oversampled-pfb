`timescale 1ns/1ps
`default_nettype none


// moved to attic because this works and will be incorporating elsewhere
module ShiftRegArr #(NUM=4, DEPTH=8, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

logic [0:NUM-1][WIDTH-1:0] tmpout;

PE_ShiftReg #(
  .DEPTH(DEPTH),
  .WIDTH(WIDTH)
) pe[0:NUM-1] (
  .clk(clk),
  .rst(rst),
  .en(en),
  .din({din, tmpout[0:NUM-2]}),
  .dout(tmpout)
);

assign dout = tmpout[NUM-1];

endmodule
