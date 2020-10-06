`timescale 1ns/1ps
`default_nettype none

/*********************************
  TYPE DEFINITIONS
**********************************/

package cx_types_pkg;
  parameter int WIDTH = 16;
  parameter int FRAC_WIDTH = WIDTH-1;

  parameter int PHASE_WIDTH = 23;
  parameter int PHASE_FRAC_WIDTH = PHASE_WIDTH-1;

  typedef logic signed [WIDTH-1:0] sample_t;
  typedef logic signed [PHASE_WIDTH-1:0] phase_t;

  typedef logic signed [WIDTH+PHASE_WIDTH:0] mac_t;

  // simualtion parameters
  // display constants
  parameter string RED = "\033\[0;31m";
  parameter string GRN = "\033\[0;32m";
  parameter string MGT = "\033\[0;35m";
  parameter string RST = "\033\[0m";

  parameter int PERIOD = 10;
  parameter int END = 20;

endpackage : cx_types_pkg

/*********************************
  INTERFACES
**********************************/
import cx_types_pkg::*;

interface fp_data #(
  parameter type dtype=sample_t,
  parameter int W=WIDTH,
  parameter int F=FRAC_WIDTH
) ();

  // information for derived modules
  localparam w=W;
  localparam f=F;
  typedef dtype data_t;

  // display parameters
  localparam real lsb_scale = 1.0/(2**f);
  localparam DATFMT = $psprintf("%%%0d%0s",$ceil(W/4.0), "X");
  localparam FPFMT = "%f";

  // interface signals
  dtype data;

  // modports
  modport I (input data);
  modport O (output data);

  // convenience functions for testbench

  // return bits and scaled fixed-point interpretation of the data
  function string print_all();
    automatic string s = $psprintf("{data: 0x%s, fp:%s}", DATFMT, FPFMT);
    return $psprintf(s, data, $itor(data)*lsb_scale);
  endfunction

  // return fixed-point interpretation of the data
  function string print_data_fp();
    automatic string s = $psprintf("%s", FPFMT);
    return $psprintf(s, $itor(data)*lsb_scale);
  endfunction

endinterface : fp_data


