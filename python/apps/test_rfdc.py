import numpy as np
import matplotlib.pyplot as plt

from source import (RFDC, ToneGenerator)

def dBm2lin(dbm):
  return 10**(dbm/10)*1e-3

def calcVrms(dbm, rload):
  return np.sqrt(rload*dBm2lin(dbm))

if __name__=="__main__":
  src = ToneGenerator(sigpow_dBm=-6)

  rfdc = RFDC()

  nsamps = 256

  xt = np.zeros(nsamps, dtype=np.complex64)
  xn_re = np.zeros(nsamps)
  xn_im = np.zeros(nsamps)
  for i in range(0, nsamps):
    s = src.genSample()
    xt[i] = s
    xn_im[i], xn_re[i] = rfdc.sample(s)
