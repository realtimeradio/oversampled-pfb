`default_nettype none

package alpaca_sim_constants_pkg;
  import alpaca_constants_pkg::FFT_LEN;
  import alpaca_constants_pkg::PTAPS;
 
  // constants and constructs used in system verilog simulation that do not work
  // with vivado synthesis

  parameter ADC_BITS = 8;                         // simulation ADC effective bit resolution

  // display constants
  parameter string RED = "\033\[0;31m";
  parameter string GRN = "\033\[0;32m";
  parameter string MGT = "\033\[0;35m";
  parameter string RST = "\033\[0m";

  parameter string CYCFMT = $psprintf("%%%0d%0s",4, "d");
  parameter string BINFMT = $psprintf("%%%0d%0s",1, "b");
  parameter string DATFMT = $psprintf("%%%0d%0s",0, "d");

  // filter coefficient files from old-style original ospfb implementation before being
  // forced to move to pass taps as a parameter due to vivado synthesis not accepting strings or
  // able to use string interpolating functions like $psprintf and $sformat
  //parameter BASE_COEF_FILE = "h_2048_8_4_";
  parameter BASE_COEF_FILE = $psprintf("coeff/hann/h_%0d_%0d_4_%%0d.coeff", FFT_LEN, PTAPS);
  //parameter BASE_COEF_FILE = "coeff/ones/h%0d_unit_16.coeff";

endpackage : alpaca_sim_constants_pkg
