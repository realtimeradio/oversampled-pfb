`timescale 1ns/1ps
`default_nettype none

/*
  Capture AXIS Samples from upstream until RAM is full.

  Cannot accept more samples until reset

  // Notes/ideas
  TLAST not implemented anwhere... do we work of tlast or just count samples?
  what does the snapshot ip do? TODO
*/
module axis_vip #(
  parameter int WIDTH=32,
  parameter int DEPTH=32
) (
  input wire logic clk,
  input wire logic rst,
  axis.SLV s_axis,
  output logic full
);

logic [$clog2(DEPTH)-1:0] wAddr;
logic signed [WIDTH-1:0] ram [DEPTH];
logic wen;

assign wen = (s_axis.tready & s_axis.tvalid);

always_ff @(posedge clk)
  if (rst)
    wAddr <= '0;
  else if (wen)
    wAddr <= wAddr + 1;
  else
    wAddr <= wAddr;

always_ff @(posedge clk)
  if (wen)
    ram[wAddr] <= s_axis.tdata;

// cannot accept any more writes until reset
// registered the full signal so that it will be asserted after DEPTH number of
// samples have been written, otherwise as soon as wAddr == DEPTH-1 full is asserted
// and we don't register the last value
always_ff @(posedge clk)
  if (rst)
    full <= 1'b0;
  else if (wAddr == DEPTH-1)
    full <= 1'b1;
  else
    full <= full;
//assign full = (wAddr == DEPTH-1) ? 1'b1 : 1'b0;

assign s_axis.tready = ~full;

endmodule

