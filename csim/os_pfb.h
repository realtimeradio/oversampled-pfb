#ifndef OS_PFB_H
#define OS_PFB_H

#include "typedefs.h"
#include "hls_fft.h"

#define M 32  // polyphase branches (NFFT)
#define D 24  // Decimation rate (D <= M)
#define L 256 // Taps in prototype FIR filter
#define P L/M // Taps in branch of polyphase FIR filter

#define SHIFT_STATES 4 // for the above D=24, M=32 there are 4 shifting states

// Vivado FFT IP configuration

struct os_pfb_config : hls::ip_fft::params_t {
  static const unsigned ordering_opt = hls::ip_fft::natural_order;
  static const unsigned max_nfft = 5; // 1 << 5 = 32
  static const unsigned input_width = 32;
  static const unsigned output_width = 32;
  static const unsigned config_width = 8;
  static const unsigned phase_factor_width = 24;
  // the example configures the FFT width, what else do I need here... time to
  // check the user guide...
};

typedef hls::ip_fft::config_t<os_pfb_config> os_pfb_config_t;
typedef hls::ip_fft::status_t<os_pfb_config> os_pfb_status_t;

void os_pfb(cx_datain_t *in, cx_dataout_t *out, int* shift_states, bool* overflow);

#endif // OS_PFB_H

