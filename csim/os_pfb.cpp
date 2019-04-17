#include "os_pfb.h"

void os_pfb(cx_datain_t in[D], cx_dataout_t out[M], bool* overflow) {
#pragma HLS interface axis depth=FFT_LENGTH port=in,out
#pragma HLS data_pack variable=in
#pragma HLS data_pack variable=out
#pragma HLS dataflow
  // filter taps
  const coeff_t h[L] = {
    #include "coeff.dat"
  };
#pragma HLS ARRAY_PARTITION variable=h complete dim=1
  // shift states that have been pre-computed.
  static int shift_states[SHIFT_STATES] = {0, 24, 16, 8};
#pragma HLS ARRAY_PARTITION variable=shift_states complete dim=1
  // maintain filter state for subsequent calls
  static cx_dataout_t filter_state[L];
#pragma HLS ARRAY_PARTITION variable=filter_state complete dim=1

  // shift/capture samples and polyphase fir filter
  cx_dataout_t filter_out[M] = { 0 };
  for (int p = P-1; p >= 0 ; --p) {
#pragma HLS unroll complete
    for (int m = M-1; m >= 0; --m) {
#pragma HLS pipeline II=1
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
#pragma HLS unroll complete
    oidx = (i+shift) % M;
    ifft_buffer[oidx] = filter_out[i];
  }

  // circularly rotate states array
  int tmp = shift_states[SHIFT_STATES-1];
  for (int i=SHIFT_STATES-1; i > 0; --i) {
    shift_states[i] = shift_states[i-1];
  }
  shift_states[0] = tmp;
  //ifft computation
  os_pfb_config_t ifft_config;
  os_pfb_status_t ifft_status;
  ifft_config.setDir(0); // inverse transform

  cx_dataout_t ifft_out[M] = { 0 };
  hls::fft<os_pfb_config>(ifft_buffer, ifft_out, &ifft_status, &ifft_config);
  *overflow = ifft_status.getOvflo() & 0x1;

  // stream data out
  for (int i=0; i<M; ++i)
    out[i] = ifft_out[i];
}


