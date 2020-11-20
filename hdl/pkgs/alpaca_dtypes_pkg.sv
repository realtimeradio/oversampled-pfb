`timescale 1ns/1ps
`default_nettype none

package alpaca_dtypes_pkg;
  import alpaca_constants_pkg::*;

  typedef logic signed [WIDTH-1:0] sample_t;
  typedef logic signed [COEFF_WID-1:0] coeff_t;
  typedef logic signed [WIDTH+COEFF_WID:0] mac_t;

  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  typedef cx_t [SAMP_PER_CLK-1:0] cx_pkt_t;

  typedef sample_t [SAMP_PER_CLK-1:0] fir_pkt_t;
  typedef coeff_t [SAMP_PER_CLK-1:0] coeff_pkt_t;
  typedef mac_t [SAMP_PER_CLK-1:0] mac_pkt_t;

  typedef coeff_pkt_t branch_taps_t[FFT_LEN/SAMP_PER_CLK];
  typedef coeff_pkt_t fir_taps_t[PTAPS*(FFT_LEN/SAMP_PER_CLK)];

  // alpaca butterfly types
  typedef logic signed [PHASE_WIDTH-1:0] phase_t; // single re/im part of a twiddle factor
  typedef logic signed [WIDTH+PHASE_WIDTH:0] phase_mac_t;

  typedef struct packed {
    logic signed [PHASE_WIDTH-1:0] im;
    logic signed [PHASE_WIDTH-1:0] re;
  } wk_t;

  // allows for bit-growth required from a mult and add
  typedef struct packed {
    logic signed [PHASE_WIDTH+WIDTH:0] im;
    logic signed [PHASE_WIDTH+WIDTH:0] re;
  } cx_phase_mac_t;

  typedef cx_phase_mac_t [SAMP_PER_CLK-1:0] cx_phase_pkt_t;

  typedef wk_t twiddle_factor_t[FFT_LEN/2];

endpackage : alpaca_dtypes_pkg

