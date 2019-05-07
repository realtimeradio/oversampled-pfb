#ifndef TYPEDEFS_H
#define TYPEDEFS_H

#include <complex>
#include "ap_fixed.h"

typedef float coeff_t;
//TODO: our data types will be 8-bit real/imag and so while testing on floats will work for
// now to quickly get the (-1, 1) requirement for the FFT core I need to see where this scaling
// will need to take place. Perhaps in the core itself?
// TODO: Noticed that in the FFT output there is a  bias at 0 Hz, is this because of the quantization?
//typedef std::complex<signed char> cx_datain_t;
typedef std::complex<float> cx_datain_t;
typedef std::complex<float> cx_dataout_t;

struct os_pfb_axis_t {
  cx_dataout_t data;
  ap_uint<1> last;
};

#endif // TYPEDEFS_H

