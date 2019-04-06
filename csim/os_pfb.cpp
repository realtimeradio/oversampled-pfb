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
  static cx_dataout_t filter_state[L];   // real filter products
  cx_dataout_t ifft_buffer[M]; // input data to the fft (remember dum dum... set to zero (not static)

  // amount to shift data to line up with correct fft port
  static unsigned char shift_state[SHIFT_STATES];

  cx_dataout_t *state = filter_state;
  cx_dataout_t *stateEnd = filter_state + L;

  // move filter state down
  for (int i=0; i < L-D; ++i) {
    filter_state[i] = filter_state[i+D];
  }

  // copy new data in
  for (int i=L-D, k=0; i < L; ++i, ++k) {
    filter_state[i] = in[k];
  }

  // fir filtering
  for (int m=0; m < M; ++m) {
    for (int p = 0; p < P; ++p) {
      ifft_buffer[m] = ifft_buffer[m] + h[p*M+m]*filter_state[L-p*M-m-1];
    }
  }

  //apply phase correction
  int shift = shift_states[0];

  // repeat 'shift' times
  for (int i=0; i < shift ; ++i) {

    // shift up by one and copy end to beginning
    cx_dataout_t tmp = ifft_buffer[M-1];
    for (int i=M-1; i > 0; --i) {
      ifft_buffer[i] = ifft_buffer[i-1];
    }
    ifft_buffer[0] = tmp;
  }

  // move shift array up by one and copy end to beginning
  int tmp = shift_states[SHIFT_STATES-1];
  for (int i=SHIFT_STATES-1; i > 0; --i) {
    shift_states[i] = shift_states[i-1];
  }
  shift_states[0] = tmp;

  //ifft computation

  return;
}


