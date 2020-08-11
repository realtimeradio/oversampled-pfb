`timescale 1ns/1ps
`default_nettype none

package alpaca_ospfb_utils_pkg;
  import alpaca_ospfb_constants_pkg::*;

  function automatic int mod(input int x, M);
    if (x < 0)
      x = x+M;
    return x % M;
  endfunction

  function automatic int gcd(input int M, D);
    if (M==0) return D;
    return gcd(D%M, M);
  endfunction

  function automatic void genShiftStates(ref int states[], input int M, D);
    for (int i=0; i < states.size; i++)
      states[i] = (i*D) % M;
  endfunction

  class Source;
    int M, i, modtimer;

    // constructor
    function new(int M);
      this.M = M;
      i = 1; // processing order
      // i = 0; // natural order
      modtimer = 0;
    endfunction

    // class methods
    function int createSample();
      int dout = i*M - modtimer - 1; // processing order
      // int dout = i*M + modtimer; // natural order
      // increment meta data
      modtimer = (modtimer + 1) % M;
      i = (modtimer == 0) ? i+1 : i;
      return dout;
    endfunction
  endclass // Source

  // TODO: I am also doing something wrong because Source and Sink are almost
  // identical... there should be a better way for reuse...
  class Sink;
    int M, m, n, r, modtimer, NStates;
    int shiftStates[];

    // constructor
    function new(int M, numStates);
      this.M = M;
      n = 0;          // decimated time sample
      r = 0;          // current state index
      modtimer = 0;   // right now, a mod counter to keep track AND the branch index

      NStates = numStates;
      shiftStates = new[NStates];
      genShiftStates(shiftStates, FFT_LEN, DEC_FAC);
    endfunction

    // TODO: should we have a check output method or just return a value? i.e.,
    // outputTruth method?  I am iffy on how we would be expecting branch order on
    // the output... I had this nailed down at one point but am since confused
    // again...
    function int outputTruth();
      // man... I am really shooting myself in the foot here with these variable
      // scope issues...  but why should i... isn't it just like python... just
      // get used to it...
      int dout = n*M + mod((modtimer-shiftStates[r]), M);

      // increment meta data
      modtimer = (modtimer + 1) % M;
      if (modtimer == 0) begin
        n = n+1;
        r = (r+1) % NStates;
      end

      return dout;
    endfunction

  endclass //Sink

endpackage

