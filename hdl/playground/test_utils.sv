`timescale 1ns / 1ps
`default_nettype none

import alpaca_ospfb_constants::*;
import alpaca_ospfb_utils_pkg::*;

parameter CLK_PER = 10;               // clock period [ns]

module test_utils();

logic clk, rst;

initial begin
  clk <= 0;
  forever #(CLK_PER/2) clk = ~clk;
end



parameter int GCD = gcd(FFT_LEN, DEC_FAC);
parameter int NUM_STATES = FFT_LEN/GCD;

// a call to a dynamic array must be initialized with new[]
int shift_states[];

initial begin
  shift_states = new[NUM_STATES]; // initialize elements
  genShiftStates(shift_states, FFT_LEN, DEC_FAC);
  $display("FFT_LEN=%4d", FFT_LEN);
  $display("OSRATIO=%g", OSRATIO);
  $display("DEC_FAC=%4d", DEC_FAC);
  $display("GCD=%4d", GCD);
  $display("NUM_STATES=%4d", NUM_STATES);

  for (int i=0; i<NUM_STATES; i++) begin
    $display("shift_states[%1d] = %d", i, shift_states[i]);
  end
end
endmodule
