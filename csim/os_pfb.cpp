#include <stdio.h>
#include <iostream>

#include "os_pfb.h"

void os_pfb(cx_datain_t in[M], cx_dataout_t out[M], int shift_states[SHIFT_STATES], bool* overflow)
{
#pragma HLS interface ap_fifo depth=FFT_LENGTH port=in,out
#pragma HLS interface ap_fifo depth=1 port=overflow
#pragma HLS data_pack variable=in
#pragma HLS data_pack variable=out
#pragma HLS dataflow

  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };

  // move filter state up
  static cx_dataout_t filter_state[L];
  for (int i=L-1; i >= D; --i) {
    filter_state[i] = filter_state[i-D];
  }

  // copy new data in
  for (int i = D-1; i >= 0; --i) {
      filter_state[i] = in[i];
  }

  // fir filtering
  cx_dataout_t filter_out[M] = { 0 };
  for (int m=0; m < M; ++m) {
    for (int p = 0; p < P; ++p) {
      filter_out[m] = filter_out[m] + h[p*M+m]*filter_state[p*M+m];
    }
  }

  //apply phase correction
  int shift = shift_states[0];
  int oidx;
  cx_dataout_t ifft_buffer[M] = { 0 };
  for (int i=0; i<M; ++i) {
    oidx = (i+shift) % M;
    ifft_buffer[oidx] = filter_out[i];
  }

  // move shift array up by one and copy end to beginning
  int tmp = shift_states[SHIFT_STATES-1];
  for (int i=SHIFT_STATES-1; i > 0; --i) {
    shift_states[i] = shift_states[i-1];
  }
  shift_states[0] = tmp;

  //ifft computation
  os_pfb_config_t ifft_config;
  os_pfb_status_t ifft_status;

  ifft_config.setDir(0); // inverse transform

  hls::fft<os_pfb_config>(ifft_buffer, out, &ifft_status, &ifft_config);

  *overflow = ifft_status.getOvflo() & 0x1;


  return;
}


