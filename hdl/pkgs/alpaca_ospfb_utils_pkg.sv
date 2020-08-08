`timescale 1ns/1ps
`default_nettype none

package alpaca_ospfb_utils_pkg;

// display constants
parameter string RED = "\033\[0;31m";
parameter string GRN = "\033\[0;32m";
parameter string MGT = "\033\[0;35m";
parameter string RST = "\033\[0m";

parameter PERIOD = 10;          // simulation clock period

/*
  TODO: implement correct arithmetic
  The current hardware does not correctly compute arithmetic, rounding and scaling (shifting)
  and so using full ALPACA specs (specifically 15/16 bit coefficients, 12 bit ADC) then keeping the
  data width of the delay buffers at 16 causes overflow and the hardware simulation suffers from
  overflow and truncation issues.

  To an extent those issues can be shown here as the python ospfb can accept different data types.
  The python simulator does not do scaling and shifting but when you do SIM_DT=int32, COEFF_WID=15,
  ADC_BITS=12 and run the small PFB (M=64, D=48, P=4) you see how the PFB filter ramp up exhibits the
  same shallow, and notch behavior of the Hann window until it becomes the steep narrow cliff. Showing
  that it was the hardware was never able to pass the ramp up and was shallow due to bit growth
  and truncation.

  But since the python and hardware simulations accept parameterized using ADC_BITS=8 and
  COEFF_WID=4 with P=4 the entire filter growth (since the FFT is float) can fit in WIDTH=16. You see
  a little more quantization noise in the floor of the spectrum from the coefficients but the 4 bit
  coefficients still results in a decent (no truncation/quantization effects) spectrum.
  Comparing this to the python simulator the outputs are similar.
*/
parameter ADC_BITS = 8;         // simulation ADC effective bit resolution
parameter WIDTH = 16;           // axi-sample word width, ADC samples padded to this width
parameter COEFF_WID = 16;       // filter coefficient word width

// TODO: FFT_LEN-DEC_FAC an issue here because need to build out the correct length
parameter SRLEN = 4;

// testing smaller modules (DelayBuf, SRLShiftReg, set DEPTH=FFT_LEN)
parameter int  FFT_LEN = 64;               // (M)   polyphase branches
parameter real OSRATIO = 3.0/4.0;          // (M/D) oversampling ratio
parameter int  DEC_FAC = FFT_LEN*OSRATIO;  // (D)   decimation factor 
parameter PTAPS = 4;                       // (P)   polyphase taps corresponds to number of PEs

parameter string CYCFMT = $psprintf("%%%0d%0s",4, "d");
parameter string BINFMT = $psprintf("%%%0d%0s",1, "b");
parameter string DATFMT = $psprintf("%%%0d%0s",0, "d");

// TODO: do we want an idle state?
typedef enum logic {FILLA, FILLB, ERR='X} phasecomp_state_t;

//typedef struct {
//  /* is it possible to parameterize a struct or just a class?
//  /* looks like the answer is yes... example in rfdc demo_tb_fft_checker.sv from xilinx rfdc
//  /* project
//  /* eg.,
//  /* parameter FFT_LEN = 1024;
//  /* typedef struct {
//  /*  complex_t arr[FFT_LEN];
//  /* } cplxArray_t;
//   
//} ospfb_cfg_t;

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

