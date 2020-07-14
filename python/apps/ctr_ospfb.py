import sys
import numpy as np
import struct

from ospfb import OSPFB, computeLatency, latencyComp
from source import CounterSource

from taps import CyclicRampTaps

from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)

if __name__=="__main__":
  M=64; D=48; P=3;
  fname = "golden_ctr.dat"
  fp = open(fname, 'wb')

  Tend = 1000
  SIM_DT = 'int16'

  taps = CyclicRampTaps.genTaps(M, P, D)
  ospfb = OSPFB(M=M, D=D, P=P, taps=taps, dt=SIM_DT, followHistory=False)
  ospfb.enable()

  src = CounterSource(M=M, order="natural")

  din = TYPES_INIT[SIM_DT]
  for i in range(0, Tend):
    if ospfb.valid():
      din = src.genSample()

    peout, pe_firout = ospfb.step(np.int16(din))
    fp.write(struct.pack('h', pe_firout))
    fp.write(struct.pack('h', 0x20)) # space ' ' character
    fp.write(struct.pack('h', peout[1]))
    fp.write(struct.pack('h', 0xa)) # new line character, '\n'

  fp.close() 
