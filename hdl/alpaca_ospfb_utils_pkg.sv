`timescale 1ns/1ps
`default_nettype none

package alpaca_ospfb_utils_pkg;

parameter int  FFT_LEN = 32;               // (M)   polyphase branches
parameter real OSRATIO = 3.0/4.0;          // (M/D) oversampling ratio
parameter int  DEC_FAC = FFT_LEN*OSRATIO;  // (D)   decimation factor 

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

function automatic int gcd(input int M, D);
  if (M==0) return D;
  return gcd(D%M, M);
endfunction

function automatic void genShiftStates(ref int states[], input int M, D);
  for (int i=0; i < states.size; i++)
    states[i] = (i*D) % M;
endfunction

endpackage

