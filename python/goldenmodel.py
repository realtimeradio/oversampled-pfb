import numpy as np
from numpy import (abs, log10, min, max)
from numpy import fft
from numpy import random
from scipy import signal
import matplotlib.pyplot as plt

def golden(x, h, yi, M, D, decmod, dt=np.complex128):

  L = int(np.ceil((M-decmod)/D))
  Y = np.zeros((M,L), dtype=dt)
  n = np.arange(0, M)

  for k in range(0, M):
    # mix down
    argmix = (-1j*2*np.pi*k*n)/M
    xmix = x*np.exp(argmix)

    # low pass filter
    ymix, yi[k,:] = signal.lfilter(h, 1, xmix, zi=yi[k,:])

    # decimate
    ydec = ymix[decmod:-1:D]

    Y[k,:] = ydec

  decmod = (D-M+decmod) % D

  return (Y, yi, L, decmod)

def pltfine(FineSpectrumMat, fs, NFFT_FINE, M, D):
  fs_os = fs/D
  hsov = (M-D)*NFFT_FINE//(2*M)
  
  fig, ax = plt.subplots(4,8, sharey='row')
  for i in range(0,4):
    for j in range(0,8):
      k = (i*8)+j
      # this shift corrects for overlap between adjacent bins
      bin_shift = - ((NFFT_FINE//2) + k*2*hsov)

      subbins = np.arange(k*NFFT_FINE, (k+1)*NFFT_FINE) + bin_shift
      cur_ax = ax[i,j]
      cur_ax.plot(subbins*fs_os/NFFT_FINE, 20*log10(abs(FineSpectrumMat[k, :])))
      cur_ax.set_xlim(min(subbins*fs_os/NFFT_FINE), max(subbins*fs_os/NFFT_FINE))
      cur_ax.grid(True)
  plt.show()

def crandn(shape):
  return (random.randn(shape) + 1j*random.randn(shape))

if __name__=="__main__":
  print("********* BANK OF DECIMATED LPF ************")

  # simulation parameters
  M = 32
  D = 24
  P = 8
  L = M*P

  osratio = M/D

  fs = 10e3
  f_soi = 2e3

  NFFT = M
  NFFT_FINE = 512

  FINE_FRAMES = 10

  hsov = (M-D)*NFFT_FINE//(2*M)

  # prototype LPF filter taps
  sincarg = np.arange(-P/2*osratio, osratio*P/2, 1/D)
  sinc = np.sinc(sincarg)
  hann = np.hanning(L)
  h = sinc*hann

  # shaping filter
  blueNoise = fft.ifft(fft.fftshift(np.sqrt(np.linspace(1,3,1024)))) # TODO: some magic numbers here
  zi = np.zeros(1024-1, dtype=np.complex128)

  X = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
  Xf = np.zeros((NFFT*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)
  Xfpruned = np.zeros((D*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)

  yi = np.zeros((M, L-1), dtype=np.complex128)
  n = np.arange(0,M)
  nn = 0
  decmod = 0

  for i in range(0, FINE_FRAMES):
    st = 0
    ed = 0
    X = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)

    while ed < NFFT_FINE:
      # generate filterd noiese samples 
      argf = (1j*2*np.pi*f_soi/fs*(np.arange(nn*M, (nn+1)*M)))
      nn += 1
      sig = np.exp(argf)
      noise = crandn(M)
      xh = sig + noise
      #xh = crandn(M)
      #xh, zi = signal.lfilter(blueNoise, 1, x, zi=zi)

      (Ydec, yi, ndec, decmod) = golden(xh, h, yi, M, D, decmod)

      ed = st + ndec
      X[:, st:ed] = Ydec
      st = ed

    # compute a the fine spectrum output along with the corrected with
    # oversample regions discarded
    fine = fft.fftshift(fft.fft(X, NFFT_FINE, axis=1), axes=(1,))/NFFT_FINE
    finepruned = fine[:,(hsov-1):-(hsov+1)]
    Xf[:, i] = fine.reshape(NFFT*NFFT_FINE)
    Xfpruned[:,i] = finepruned.reshape(D*NFFT_FINE)

  # plot averaged fine spectrum
  Sxx_pruned = np.mean(np.real(Xfpruned*np.conj(Xfpruned)), 1)
  fshift = -(NFFT_FINE/2-hsov+1)
  fbins_fine = np.arange(0, D*NFFT_FINE) + fshift
  faxis_fine = fbins_fine*fs/D/NFFT_FINE

  plt.plot(faxis_fine, 10*np.log10(Sxx_pruned))
  plt.ylim([-20, 70])
  plt.grid()
  plt.show()

