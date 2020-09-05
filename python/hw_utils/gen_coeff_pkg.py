import sys, argparse

import numpy as np
import matplotlib.pyplot as plt

from taps import (HannWin, Ones, CyclicRamp)

alpaca_coeff_pkg = {
  "name"            : "alpaca_ospfb_coeff_pkg",
  "def_pkg"         : "alpaca_ospfb_constants_pkg",
  "coeff_param_name": "TAPS",
  "width"           : 16,
  "ptaps"           : 8,
  "ntaps"           : 2048,
}
  

def gen_coeff_pkg_file(h, pkg_info=alpaca_coeff_pkg):
  # create package file
  PKG_NAME = pkg_info["name"]
  DEF_PKG = pkg_info["def_pkg"]
  COEFF_WID = pkg_info["width"]
  PTAPS = pkg_info["ptaps"]
  NTAPS = pkg_info["ntaps"]
  VAR_NAME = pkg_info["coeff_param_name"]

  TAPS_PER_LINE = 16

  fname = "{:s}.sv".format(PKG_NAME)

  fp = open(fname, 'w')

  fp.write("/* This file was auto-generated */\n")
  fp.write("package {:s};\n".format(PKG_NAME))
  fp.write("  import {:s}::*;\n\n".format(DEF_PKG))
  fp.write("  parameter logic signed [{:d}:0] {:s} [{:d}] =".format(COEFF_WID-1, VAR_NAME, PTAPS*NTAPS))
  fp.write(" {\n\t")

  b = h.tobytes()
  it = iter(b)

  ii = 0
  # bytes array endianess is backwards, zip() so we can process 2 in a row
  for (lo, hi) in zip(it, it):
    if ((ii) % TAPS_PER_LINE==0):
      fp.write("\n\t")

    # ':02x' width two, pad with zeros hex format
    fp.write("{:d}'h".format(COEFF_WID))
    if (ii==P*M-1):
      fp.write((2*"{:02x}").format(hi, lo))
    else:
      fp.write((2*"{:02x}").format(hi, lo)+',')

    ii+=1

  fp.write("\n\n\t};\n\n")
  fp.write("endpackage\n")
  fp.close()

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
    filter_pk = np.max(h)
    lsb_scale = filter_pk/(2**(BITS-1)-1)
    h_scale = h/lsb_scale;
    h = np.array(h_scale, dtype=np.int16)
  elif (window == "rect"):
    h = Ones.genTaps(M, P, D)
    filter_pk = np.max(h)
    lsb_scale = filter_pk/(2**(BITS-1)-1)
    h_scale = h/lsb_scale;
    h = np.array(h_scale, dtype=np.int16)
  elif (window == "ramp"):
    h = CyclicRamp.genTaps(M, P, D)
  elif (window == "ones"):
    h = np.ones(M*P, dtype=np.int16)
  else:
    print("Window not supported")
    sys.exit()

  alpaca_coeff_pkg["name"] = "alpaca_ospfb_{:s}_{:d}_{:d}_coeff_pkg".format(window, M, P)
  alpaca_coeff_pkg["ptaps"] = P
  alpaca_coeff_pkg["ntaps"] = M
  gen_coeff_pkg_file(h, alpaca_coeff_pkg)

