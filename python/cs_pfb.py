import sys
import numpy as np
from numpy.fft import (fft, ifft, fftshift)
from numpy import random
import matplotlib.pyplot as plt

from source import ToneGenerator
from taps import (HammWin, HannWin)

def os_golden(x, h, yi, M, D, decmod, dt=np.complex128):

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


def os_pfb(x, modinc, h, M, P):
  L = M*P
  s = x.shape #(512,)
  if x.ndim > 1:
    tmp = np.zeros((s[0],M), dtype=np.complex128)
  else:
    tmp = np.zeros(M, dtype=np.complex128)

  for m in range(0, M):
    for p in range(0, P):
      tmp[...,m] = tmp[...,m] + h[...,p*M+m]*x[...,L-p*M-m-1]

  tmp = np.roll(tmp, modinc, axis=len(s)-1)
  X = ifft(tmp, M, axis=len(s)-1)

  return X

def cs_pfb(x, h, M, P):
  L = M*P
  s = x.shape # (64, 256)
  if x.ndim > 1:
    tmp = np.zeros((s[0],M), dtype=np.complex128)
  else:
    tmp = np.zeros(M, dtype=np.complex128)

  for m in range(0, M):
    for p in range(0, P):
      tmp[...,m] = tmp[...,m] + h[...,p*M+m]*x[...,L-p*M-m-1]

  return ifft(tmp, M, axis=len(s)-1)

def crandn(shape):
  return (random.randn(shape) + 1j*random.randn(shape))

if __name__=="__main__":

  # First stage PFB parameters
  Mcoarse = 512
  OSRATIO = 4/3
  Dcoarse = int(Mcoarse/OSRATIO)
  Pcoarse = 8
  Lcoarse = Mcoarse*Pcoarse
  M_D = Mcoarse-Dcoarse

  # Second stage PFB parameters
  Mfine = 128
  Dfine = Mfine
  Pfine = 8
  Lfine = Mfine*Pfine

  # derived parameters and other simulation constants
  NFFT_COARSE = Mcoarse
  NFFT_FINE = Mfine
  N_FINE_CHANNELS = Dcoarse*Mfine
  FINE_FRAMES = 10

  hsov = M_D*Mfine//(2*Mcoarse)
  sel_range = np.arange(hsov, Mfine-hsov)

  fs = 10e3
  f_soi = 2.7e3
  argf = 2*np.pi*f_soi/fs

  # protype low pass filter generation
  hcoarse = HammWin.genTaps(Mcoarse, Pcoarse, Dcoarse)
  hfine = HammWin.genTaps(Mfine, Pfine, Dfine)

  # process
  Xkfine_fft = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)
  Xkfine_pfb = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)

  zicoarse = np.zeros(Lcoarse, dtype=np.complex128)
  zifine = np.zeros((Mcoarse, Lfine), dtype=np.complex128)

  nn=0
  modinc = 0
  for i in range(0, FINE_FRAMES):
    Xkcoarse = np.zeros((Mcoarse, Mfine), dtype=np.complex128)

    for j in range(0, Mfine):
      zicoarse[-Dcoarse:] = np.exp(1j*argf*(np.arange(nn*Dcoarse, (nn+1)*Dcoarse)))# + 0.001*crandn(Dcoarse)
      Xkcoarse[:, j] = os_pfb(zicoarse, modinc, hcoarse, Mcoarse, Pcoarse)
      zicoarse[:-Dcoarse] = zicoarse[Dcoarse:]

      modinc = (modinc+M_D) % Mcoarse
      nn+=1

    # second stage FFT
    Xkfinetmp = fftshift(fft(Xkcoarse, Mfine, axis=1), axes=(1,))/Mfine

    Xkfine_pruned = Xkfinetmp[:, sel_range]

    Xkfine_fft[:, i] = Xkfine_pruned.reshape(N_FINE_CHANNELS)

    #second stage PFB
    zifine[:, -Mfine:] = Xkcoarse
    Xkfinetmp = fftshift(cs_pfb(zifine, hfine, Mfine, Pfine), axes=(1,))

    Xkfine_pruned = Xkfinetmp[:, sel_range]

    Xkfine_pfb[:, i] = Xkfine_pruned.reshape(N_FINE_CHANNELS)
    zifine[:, :-Mfine] = zifine[:, Mfine:]

  Sxx_fft = np.mean(np.real(Xkfine_fft*np.conj(Xkfine_fft)), 1)
  Sxx_pfb = np.mean(np.real(Xkfine_pfb*np.conj(Xkfine_pfb)), 1)

  fig, ax = plt.subplots(2, 1, figsize=(17,15))
  fbins = np.arange(0, N_FINE_CHANNELS)
  ax[0].plot(fbins, 10*np.log10(Sxx_fft))
  ax[0].grid()

  ax[1].plot(fbins, 10*np.log10(Sxx_pfb))
  ax[1].grid()
  plt.show()

  plt.figure(figsize=(17,15))
  plt.plot(fbins, 10*np.log10(Sxx_fft))
  plt.plot(fbins, 10*np.log10(Sxx_pfb))
  plt.grid()
  plt.show() 
