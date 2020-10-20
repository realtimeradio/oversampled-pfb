#!/usr/bin/env python
from plt_adc_sim import read_cx_bin

if __name__=="__main__":
  import sys, argparse
  import matplotlib.pyplot as plt
  import numpy as np
  from numpy.fft import (fft, fftshift)
  from numpy import (abs, log10)

  parser = argparse.ArgumentParser()

  parser.add_argument('file', type=str, help="file containing binary fft data")
  parser.add_argument('nfft', type=int, help='Size of FFT transform')
  parser.add_argument('nframes', type=int, help='Number of FFT frames of length nfft')
  parser.add_argument('-X', '--transform', action='store_true', help="perform FFT on input file")
  parser.add_argument('-p', '--plot', action='store_true', help="plot the data")
  parser.add_argument('-l', '--linear', action='store_true', help="plot linear")
  args = parser.parse_args()

  # parase arguments
  fname = args.file
  NFFT = args.nfft
  FRAMES = args.nframes
  SAMPS = NFFT*FRAMES

  # read in fft output sample
  (xi, xq) = read_cx_bin(fname, SAMPS)

  # form complex basebanded and reshape
  xi = xi.reshape(FRAMES, NFFT)
  xq = xq.reshape(FRAMES, NFFT)

  X = xi + 1j*xq

  if (args.transform):
    X = fft(X, NFFT)

  if (args.linear):
    magX = np.real(X)
  else:
    magX = 20*log10(abs(X+.0001))

  if (args.plot):
    PLT_WIDTH = 4
    PLT_DEPTH = FRAMES//PLT_WIDTH

    fbins = np.arange(0, NFFT)
    fig, ax = plt.subplots(PLT_DEPTH, PLT_WIDTH, sharey='row')
    for i in range(0, PLT_DEPTH):
      for j in range(0, PLT_WIDTH):
        idx = (i*PLT_WIDTH) + j
        cur_ax = ax[i,j]

        cur_ax.plot(fbins, magX[idx, :])
        cur_ax.grid()

    # alternativly could plot all of them
    #plt.plot(fbins, magX.transpose())
    plt.show()

