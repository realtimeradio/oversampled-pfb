`timescale 1ns/1ps
`default_nettype none

package alpaca_dtypes_pkg;
  import alpaca_constants_pkg::*;

  typedef logic signed [WIDTH-1:0] sample_t;

  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  typedef cx_t [SAMP_PER_CLK-1:0] cx_pkt_t;

  typedef sample_t [SAMP_PER_CLK-1:0] fir_t;

  // alpaca butterfly types
  typedef struct packed {
    logic signed [PHASE_WIDTH-1:0] im;
    logic signed [PHASE_WIDTH-1:0] re;
  } wk_t;

  // TODO: get correct width
  // but this represents the growth required from mult and 1 add
  typedef struct packed {
    logic signed [PHASE_WIDTH+WIDTH:0] im;
    logic signed [PHASE_WIDTH+WIDTH:0] re;
  } arith_t;

  typedef arith_t [SAMP_PER_CLK-1:0] arith_pkt_t;

endpackage : alpaca_dtypes_pkg

