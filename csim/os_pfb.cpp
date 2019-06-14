#include <stdio.h>
#include <iostream>

#include "os_pfb.h"

void polyphase_filter(cx_datain_t in[M], cx_dataout_t filter_out[M], os_pfb_config_t* ifft_config) {

  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };

  // shift states that have been pre-determined. Need to figure out how to auto-generate
//    static int shift_states[SHIFT_STATES] = {0, 24, 16, 8};
  static int shift_states[SHIFT_STATES] = {0, 16};

  ifft_config->setDir(0); //inverse transform

  static cx_dataout_t filter_state[L];
  cx_dataout_t temp[M];
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
      temp[m] = temp[m] + h[idx]*filter_state[idx];
//      filter_out[m] = filter_out[m] + h[idx]*filter_state[idx];
    }
  }

  //apply phase correction
  int shift = shift_states[0];
  int oidx;
  for (int i=0; i<M; ++i) {
    oidx = (i+shift) % M;
    filter_out[oidx] = temp[i];
  }

  // move shift array up by one and copy end to beginning
  int tmp = shift_states[SHIFT_STATES-1];
  for (int i=SHIFT_STATES-1; i > 0; --i) {
    shift_states[i] = shift_states[i-1];
  }
  shift_states[0] = tmp;

//  for (int m=0; m < M; ++m) {
//    filter_out[m] = temp[m];
//  }

  return;
}

void apply_phase_correction (cx_dataout_t filter_out[M], cx_dataout_t ifft_buffer[M]) {

  // shift states that have been pre-determined. Need to figure out how to auto-generate
//  static int shift_states[SHIFT_STATES] = {0, 24, 16, 8};
  static int shift_states[SHIFT_STATES] = {0, 16};

  //apply phase correction
  int shift = shift_states[0];
  int oidx;
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

  return;
}

void be(cx_dataout_t ifft_out[M], os_pfb_axis_t out[M], os_pfb_status_t* ifft_status, bool* ovflow) {
  // Interesting that I had to start at i=0 and copy out to M. Couldn't do what I had been doing
  // by starting at the end of the array. I wonder if this is has to do with how hls::fft fills ifft_out
  for (int i=0; i < M; ++i) {
    out[i].data = ifft_out[i];
    out[i].last = (i==M-1) ? 1 : 0;
  }
  *ovflow = ifft_status->getOvflo() & 0x1;
  return;
}

//void os_pfb(cx_datain_t in[M], cx_dataout_t out[M], int shift_states[SHIFT_STATES], bool* overflow)
void os_pfb(cx_datain_t in[M], os_pfb_axis_t out[M], bool* ovflow)
{
#pragma HLS interface axis depth=1 port=ovflow
#pragma HLS interface axis depth=FFT_LENGTH port=in,out
#pragma HLS interface ap_ctrl_none port=return
#pragma HLS data_pack variable=in
#pragma HLS data_pack variable=out
#pragma HLS dataflow

  os_pfb_config_t ifft_config;
  os_pfb_status_t ifft_status;
  cx_dataout_t filter_out[M];
//  cx_dataout_t ifft_buffer[M];
  cx_dataout_t ifft_out[M];

  polyphase_filter(in, filter_out, &ifft_config);
//  apply_phase_correction(filter_out, ifft_buffer);
//  hls::fft<os_pfb_config>(ifft_buffer, ifft_out, &ifft_status, &ifft_config);
  hls::fft<os_pfb_config>(filter_out, ifft_out, &ifft_status, &ifft_config);
  be(ifft_out, out, &ifft_status, ovflow);

  return;
}


