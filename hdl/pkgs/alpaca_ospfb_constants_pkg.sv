`default_nettype none

package alpaca_ospfb_constants_pkg;

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
parameter ADC_BITS = 8;          // simulation ADC effective bit resolution
parameter WIDTH = 16;            // axi-sample word width, ADC samples padded to this width
parameter COEFF_WID = 16;        // filter coefficient word width

parameter int FFT_CONF_WID = 8; // fft configuration width (set inverse xform and scale schedule
parameter int FFT_STAT_WID = 8;  // fft status width (overflow and optional Xk index)

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

endpackage
