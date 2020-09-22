`default_nettype none

package alpaca_constants_pkg;

// Module instantiation parameters

//`ifndef CONSTANTS
//  `define CONSTANTS
//  `include "alpaca_ospfb_constants_pkg.svh"
//`endif
parameter WIDTH = 16;                // axi-sample word width, ADC samples padded to this width
parameter PHASE_WIDTH = 23;
parameter SAMP_PER_CLK = 2;          // number of samples in adc packet
parameter COEFF_WID = 16;            // filter coefficient word width

parameter FFT_CONF_WID = 16;         // fft configuration width (set inverse and scale schedule
parameter FFT_STAT_WID = 8;          // fft status width (overflow and optional Xk index)
parameter FFT_USER_WID = 8;

parameter PHASE_WIDTH = 23;          // precision for parallel fft twiddle factors

parameter FFT_LEN = 2048;            // (M)   polyphase branches
parameter OSRATIO = 3.0/4.0;
parameter DEC_FAC = FFT_LEN*OSRATIO; // (D)   decimation factor
parameter PTAPS = 8;                 // (P)   polyphase taps corresponds to number of PEs

parameter DC_FIFO_DEPTH = FFT_LEN/2;

// Simulation parameters
parameter ADC_BITS = 8;                         // simulation ADC effective bit resolution

// determine ADC clk period given the DSP clk
parameter real ADC_PERIOD = 12;                 // ADC simulation clock period
parameter real DSP_PERIOD = OSRATIO*ADC_PERIOD; // oversampled DSP simulation clock period
parameter real PERIOD = DSP_PERIOD;             // general period for other modules

// simulation display constants
parameter string RED = "\033\[0;31m";
parameter string GRN = "\033\[0;32m";
parameter string MGT = "\033\[0;35m";
parameter string RST = "\033\[0m";

parameter string CYCFMT = $psprintf("%%%0d%0s",4, "d");
parameter string BINFMT = $psprintf("%%%0d%0s",1, "b");
parameter string DATFMT = $psprintf("%%%0d%0s",0, "d");

// TODO: do we want an idle state?
typedef enum logic {FILLA, FILLB, ERR='X} phasecomp_state_t;

// First go ospfb parameters
// TODO: FFT_LEN-DEC_FAC an issue here because need to build out the correct length
// for testing smaller modules (DelayBuf, SRLShiftReg, set DEPTH=FFT_LEN)
parameter SRLEN = 4;

//parameter BASE_COEF_FILE = "h_2048_8_4_";
parameter BASE_COEF_FILE = $psprintf("coeff/hann/h_%0d_%0d_4_%%0d.coeff", FFT_LEN, PTAPS);
//parameter BASE_COEF_FILE = "coeff/ones/h%0d_unit_16.coeff";

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

endpackage : alpaca_constants_pkg
