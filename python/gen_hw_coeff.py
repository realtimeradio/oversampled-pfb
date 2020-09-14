#!/usr/bin/env python
import sys, argparse

import numpy as np
import matplotlib.pyplot as plt

from taps import (HannWin, Ones, CyclicRamp)

if __name__=="__main__":

  parser = argparse.ArgumentParser()
  parser.add_argument('-M', '--FFTLEN', type=int, default=64, help="Transform Size")
  parser.add_argument('-D', '--DECFAC', type=int, default=48, help="Decimation Rate")
  parser.add_argument('-P', '--Taps', type=int, default=3, help="Polyphase Taps")
  parser.add_argument('-b', '--bits', type=int, default=16, help="Bit resolution")
  parser.add_argument('-w', '--window', type=str, default="hann", help="Filter window (Types: 'hann', 'rect')")
  parser.add_argument('-s', '--save', action='store_true', help="Save coeff to file")
  args = parser.parse_args()

  # parse parameters for coeff generation
  M = args.FFTLEN
  D = args.DECFAC
  P = args.Taps
  BITS = args.bits
  window = args.window

  # compute filter
  if (window == "hann"):
    h = HannWin.genTaps(M, P, D)
  elif (window == "rect"):
    h = Ones.genTaps(M, P, D)
  else:
    print("Window not supported")
    sys.exit()

  filter_pk = np.max(h)
  lsb_scale = filter_pk/(2**(BITS-1)-1)

  h_scale = h/lsb_scale; # forgetting rounding step...

  h_quant = np.array(h_scale, dtype=np.int16)

  H = h_quant.reshape(P, M)

  if args.save:
    print("saving coeff file:")
    fnamebase = "h{}_{}.coeff"
    for p in range(0, P):
      fname = fnamebase.format(p, BITS)
      print(fname)
      fp = open(fname, 'w')

      b = H[p, :].tobytes()

      it = iter(b)
      # bytes array endianess is backwards, zip() so we can process 2 in a row
      for (lo, hi) in zip(it, it):
        # ':02x' width two, pad with zeros hex format
        fp.write((2*"{:02x}").format(hi, lo)+'\n')
      fp.close()


