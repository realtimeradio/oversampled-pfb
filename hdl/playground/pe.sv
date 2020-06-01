`timescale 1ns / 1ps
`default_nettype none

// default parameters are for an oversampled polyphase filter bank with
// M = 32
// P = 8
// D = 24
// This translates to prototype FIR length L and oversample ratio M/D
// L = M*P = 256
// M/D = 4/3
//
// The bit width is default to 16-bits per sample

module ospfb_systolic_pe #(
  BRANCHES=32, // Polyphase branches, M
  POLYTAPS=8,  // Polyphase taps per branch, P
  DEC=24,      // Decimation rate , D (D<M)
  WIDTH=16,    // data sample word width
  SUMWIDTH=32) // partial sum word width
)
  input wire logic clk,
  input wire logic rst,
  input wire logic [(WIDTH-1):0] din,
  input wire logic [(SUMWIDTH-1):0] sin,
  output logic [(WIDTH-1):0] dout,
  output logic [(SUMWIDTH-1):0] sout
);

fifo #(
  DEPTH=(2*BRANCHES),
  WIDTH=WIDTH
) loopback (

);

dpfifo #(
  DEPTHA=(2*BRANCHES),
  DEPTHB=BRANCHES,
  WIDTHA=WIDTH,
  WIDTHB=SUMWIDTH,
) delayline (

);

always_comb begin
  
end

endmodule
