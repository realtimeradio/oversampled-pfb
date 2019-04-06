#ifndef OS_PFB_H
#define OS_PFB_H

#include "typedefs.h"

#define M 32  // polyphase branches (NFFT)
#define D 24  // Decimation rate (D <= M)
#define L 256 // Taps in prototype FIR filter
#define P L/M // Taps in branch of polyphase FIR filter

#define SHIFT_STATES 4 // for the above D=24, M=32 there are 4 shifting states

void os_pfb(cx_datain_t *in, cx_dataout_t *out, int* shift_states);

#endif // OS_PFB_H

