#ifndef OS_PFB_H
#define OS_PFB_H

#include "typedefs.h"

//void os_pfb(cx_datain_t in[M], cx_dataout_t out[M], int shift_states[SHIFT_STATES], bool* overflow);
void os_pfb(cx_datain_t in[D], os_pfb_axis_t out[M], bool* overflow);

#endif // OS_PFB_H

