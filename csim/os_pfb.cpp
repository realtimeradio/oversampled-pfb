#include <stdio.h>
#include <iostream>

#include "os_pfb.h"

//void os_pfb(cx_datain_t in[M], cx_dataout_t out[M], int shift_states[SHIFT_STATES], bool* overflow)
void os_pfb(cx_datain_t in[M], os_pfb_axis_t out[M], bool* ovflow)
{
#pragma HLS interface axis depth=1 port=ovflow
#pragma HLS interface axis depth=FFT_LENGTH port=in,out
#pragma HLS data_pack variable=in
#pragma HLS data_pack variable=out
#pragma HLS dataflow

  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };

  // shift states that have been pre-determined. Need to figure out how to auto-generate
  static int shift_states[SHIFT_STATES] = {0, 24, 16, 8};

  static cx_dataout_t filter_state[L];

  cx_dataout_t filter_out[M] = { 0 };

  // Note: in the fir loop...
  // interchange p and m iterators for m to be fastest moving for sequential memory access. This can be seen from
  // the 'idx' variable because m is the fastest moving element and the fact p is multiplied by M shows that p controls
  // row jumps (if it were a two dimensional data structure--which it is in the model/block diagram).

  // shift/capture samples and polyphase fir filter
  for (int p = P-1; p >= 0 ; --p) {
    for (int m = M-1; m >= 0; --m) {
      int idx = p*M+m;

      if (idx <= D-1) {
        filter_state[idx] = in[idx];
      } else {
        filter_state[idx] = filter_state[idx-D];
      }

      filter_out[m] = filter_out[m] + h[idx]*filter_state[idx];
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

//  hls::fft<os_pfb_config>(ifft_buffer, out, &ifft_status, &ifft_config);
  cx_dataout_t ifft_out[M] = { 0 };
  hls::fft<os_pfb_config>(ifft_buffer, ifft_out, &ifft_status, &ifft_config);
  *ovflow = ifft_status.getOvflo() & 0x1;

  // hls::fft implements the output as an ap_fifo (although the HLS documentation says it is a stream? Unless
  // stream and ap_fifo are synonyms and so I had to add another variable to explicittly set as an axi stream.
  // Also interesting that I had to start at i=0 and copy out to M. Couldn't do what I had been doing
  // of starting at the end of the array. I wonder if this is has to do with how hls::fft fills ifft_out
  for (int i=0; i<M; ++i) {
    out[i].data = ifft_out[i];
    out[i].last = (i==M-1) ? 1 : 0;
  }

  return;
}


