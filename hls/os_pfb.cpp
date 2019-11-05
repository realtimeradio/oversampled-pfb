#include <stdio.h>
#include <iostream>

#include "os_pfb.h"

void polyphase_filter(cx_datain_t in[D], cx_dataout_t filter_out[M], os_pfb_config_t* ifft_config) {
  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };

  // shift states that have been pre-determined. Need to figure out how to auto-generate
  static int shift_states[SHIFT_STATES] = {0, 8, 16, 24};
  static int state_idx = 0;

  ifft_config->setDir(0); //inverse transform

  static cx_dataout_t filter_state[L];
  cx_dataout_t temp[M]; // need a temp variable to not violate dataflow requirements in synthesis

  // shift/capture samples and polyphase fir filter
  filter_taps: for (int p = P-1; p >= 0 ; --p) {
    #pragma HLS pipeline II=1 rewind
    filter_brances: for (int m = M-1; m >= 0; --m) {
      int idx = p*M+m;

      if (idx <= D-1) {
        // TODO: synthesis still complains about non-sequential accessing even though these
        // are being accessed in reverse order. Will this be a problem?
        filter_state[idx] = in[idx];
      } else {
        filter_state[idx] = filter_state[idx-D];
      }
      temp[m] = temp[m] + h[idx]*filter_state[idx];
    }
  }

  polyphase_out: for (int i=0; i<M; i++)
    filter_out[i] = temp[i];

  return;
}

void apply_phase_correction (cx_dataout_t filter_out[M], cx_dataout_t ifft_buffer[M]) {
  #pragma HLS interface ap_fifo port=filter_out
  #pragma HLS interface ap_fifo port=ifft_buffer

  // shift states that have been pre-determined. Need to figure out how to auto-generate
  static int shift_states[SHIFT_STATES] = {0, 8, 16, 24};
  static int state_idx = 0;

  //apply phase correction
  int shift = shift_states[state_idx];
  int tmpidx;
  rotate: for (int i=0; i<M; ++i) {
    tmpidx = (M-shift+i) % M;
    ifft_buffer[i] = filter_out[tmpidx];
  }
  state_idx = (state_idx+1) % SHIFT_STATES;

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
void os_pfb(cx_datain_t in[D], os_pfb_axis_t out[M], bool* ovflow)
{
#pragma HLS interface axis depth=1 port=ovflow
#pragma HLS interface axis depth=FFT_LENGTH port=in,out
#pragma HLS interface ap_ctrl_none port=return
#pragma HLS data_pack variable=in
#pragma HLS data_pack variable=out

  dataflow_region: {
    #pragma HLS dataflow
    cx_dataout_t filter_out[M];
    cx_dataout_t ifft_buffer[M];
    cx_dataout_t ifft_out[M];

    os_pfb_config_t ifft_config;
    os_pfb_status_t ifft_status;
    #pragma HLS data_pack variable=ifft_config

    polyphase_filter(in, filter_out, &ifft_config);
    apply_phase_correction(filter_out, ifft_buffer);
    hls::fft<os_pfb_config>(ifft_buffer, ifft_out, &ifft_status, &ifft_config);
  //  hls::fft<os_pfb_config>(filter_out, ifft_out, &ifft_status, &ifft_config);
    be(ifft_out, out, &ifft_status, ovflow);
  }
  return;
}


