import numpy as np
from numpy import fft
from numpy import random
from scipy import signal

def crandn(shape):
  return (random.randn(shape) + 1j*random.randn(shape))

if __name__=="__main__":
  print("********* BANK OF DECIMATED LPF ************")

  # simulation parameters
  M = 64
  D = 48
  P = 8
  L = M*P

  osratio = M/D

  fs = 10e3
  NFFT = M
  NFFT_FINE = 128

  FINE_FRAMES = 10

  # prototype LPF filter taps
  sincarg = np.arange(-P/2*osratio, osratio*P/2, 1/D)
  sinc = np.sinc(sincarg)
  hann = np.hanning(L)
  h = sinc*hann


  # shaping filter
  blueNoise = fft.ifft(fft.fftshift(np.sqrt(np.linspace(1,3,1024))))
  zi = np.zeros(1024-1)

  X = np.zeros(NFFT, NFFT_FINE*FINE_FRAMES)

  fmix = np.arange(-M/2


  for i in range(0, FINE_FRAME):
    for j in range(0, NFFT_FINE):

      # generate samples
      x = crandn(M)
      xh, zi = signal.lfilter(blueNoise, 1, x, zi=zi)

      for k in range(0, M):
        # mix down
        argexp = -M/2

      # low pass filter

      # decimate
