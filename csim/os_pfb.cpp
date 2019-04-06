#include <stdio.h>
#include <iostream>

#include "os_pfb.h" // need to fix these path issues

void os_pfb(cx_datain_t *in, cx_dataout_t *out, int* shift_states)
{
  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };

  // static persistent state variables to exist between function calls
  static cx_dataout_t filter_state[L]; // real filter products
  //static dataout_t filter_state_im[L]; // imaginary filter products
  static cx_dataout_t ifft_buffer[M];     // input data to the fft

  // amount to shift data to line up with correct fft port
  static unsigned char shift_state[SHIFT_STATES];

  cx_dataout_t *state = filter_state;
  cx_dataout_t *stateEnd = filter_state + L;


  return;
}


