#ifndef TYPEDEFS_H
#define TYPEDEFS_H

#include "ap_int.h"
#include "ap_fixed.h"
#include "hls_fft.h"

#define M 32           // polyphase branches (NFFT)
#define D 24           // Decimation rate (D <= M)
#define L 256          // Taps in prototype FIR filter
#define P L/M          // Taps in branch of polyphase FIR filter
#define SHIFT_STATES 4 // for the above D=24, M=32 there are 4 shifting states

#define FLOAT 0
#define FIXED 1

#define DTYPE FIXED

// type definition and setup configuration
const int FFT_LENGTH = M;

#if DTYPE==FLOAT
  const int FFT_INPUT_WIDTH = 32;
  const int FFT_OUTPUT_WIDTH = FFT_INPUT_WIDTH;
  typedef float dtype_in;
  typedef float dtype_out;
  typedef float coeff_t;
#else
  const int FFT_INPUT_WIDTH = 16;
  const int FFT_OUTPUT_WIDTH = FFT_INPUT_WIDTH;
  typedef ap_fixed<FFT_INPUT_WIDTH, 1> dtype_in;
  typedef ap_fixed<FFT_OUTPUT_WIDTH, FFT_OUTPUT_WIDTH-FFT_INPUT_WIDTH+1> dtype_out;
  typedef ap_fixed<16,1> coeff_t; // error in overloaded complex multiplication if binary point is not the same
  typedef ap_fixed<40,24> accum_t; // error with getting the complex data type to work with HLS.... probably not going to work out well
#endif


//TODO: our data types will be 8-bit real/imag and so while testing on floats will work for
// now to quickly get the (-1, 1) requirement for the FFT core I need to see where this scaling
// will need to take place. Perhaps in the core itself?
// TODO: Noticed that in the FFT output there is a  bias at 0 Hz, is this because of the quantization?
//typedef std::complex<signed char> cx_datain_t;
#include <complex>
typedef std::complex<dtype_in> cx_datain_t;
typedef std::complex<dtype_out> cx_dataout_t;
typedef std::complex<accum_t> cx_accum_t;

// Vivado FFT IP configuration
struct os_pfb_config : hls::ip_fft::params_t {
  static const unsigned ordering_opt = hls::ip_fft::natural_order;
  static const unsigned max_nfft = 5; // 1 << 5 = 32
  static const unsigned input_width = FFT_INPUT_WIDTH;
  static const unsigned output_width = FFT_OUTPUT_WIDTH;
  static const unsigned config_width = 8;
  static const unsigned phase_factor_width = 24;
  // stages_block_ram does not update from inherited struct
  static const unsigned stages_block_ram = (max_nfft < 10) ? 0 : (max_nfft - 9);

  // the example configures the FFT width, what else do I need here... time to
  // check the user guide...
};

typedef hls::ip_fft::config_t<os_pfb_config> os_pfb_config_t;
typedef hls::ip_fft::status_t<os_pfb_config> os_pfb_status_t;

struct os_pfb_axis_t {
  cx_dataout_t data;
  ap_uint<1> last;
};


#endif // TYPEDEFS_H

