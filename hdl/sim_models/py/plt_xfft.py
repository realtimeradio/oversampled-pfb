from plt_adc_sim import read_cx_bin

if __name__=="__main__":
  import sys
  import matplotlib.pyplot as plt
  import numpy as np
  from numpy.fft import (fft, fftshift)
  from numpy import (abs, log10)

  fname = "dat/fft_data.bin"
  NFFT = 8
  FRAMES = 4

  SAMPS = NFFT*FRAMES

  # read in fft output sample
  (xi, xq) = read_cx_bin(fname, SAMPS)

  # right now fft_data contains 4 frames of NFFT=8 samples
  xi = xi.reshape(FRAMES, NFFT)
  xq = xq.reshape(FRAMES, NFFT)

  X = xi + 1j*xq
  magX = 20*log10(abs(X))

  fbins = np.arange(0, NFFT)
  plt.plot(fbins, magX[0,:])
  plt.plot(fbins, magX[1,:])
  plt.plot(fbins, magX[2,:])
  plt.plot(fbins, magX[3,:])
  plt.show() 

