import sys, argparse
import numpy as np
import struct

from ospfb import OSPFB, computeLatency, latencyComp
from source import CounterSource

from taps import CyclicRamp

from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)

if __name__=="__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('-M', '--FFTLEN', type=int, default=64, help="Transform Size")
  parser.add_argument('-D', '--DECFAC', type=int, default=48, help="Decimation Rate")
  parser.add_argument('-P', '--Taps', type=int, default=4, help="Polyphase Taps")
  args = parser.parse_args()

  M = args.FFTLEN
  D = args.DECFAC
  P = args.Taps
  fname = "golden_ctr_{}_{}_{}.dat".format(M, D, P)
  fp = open(fname, 'wb')

  Tend = 4*M*P
  SIM_DT = 'int16'

  taps = CyclicRamp.genTaps(M, P, D)
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
