import sys
import numpy as np
from numpy.fft import (fft, ifft, fftshift)
from numpy import random
from scipy import signal
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

# will work in place of cs_pfb as D=M for critically sampled -> modinc=M-D=0
def os_pfb(x, modinc, h, M, P):
  L = M*P
  # detect shape dimension for versatility as a function 
  # as a first stage (single)=(Mcoarse*Pcoarse=Lcoarse,)
  # as a second stage (parallel)=(Mcoarse, Mfine*Pfine=Lfine)
  s = x.shape
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
  # detect shape dimension for versatility as a function 
  # as a first stage (single)=(Mcoarse*Pcoarse=Lcoarse,)
  # as a second stage (parallel)=(Mcoarse, Mfine*Pfine=Lfine)
  s = x.shape
  if x.ndim > 1:
    tmp = np.zeros((s[0],M), dtype=np.complex128)
  else:
    tmp = np.zeros(M, dtype=np.complex128)

  for m in range(0, M):
    for p in range(0, P):
      tmp[...,m] = tmp[...,m] + h[...,p*M+m]*x[...,L-p*M-m-1]

  X = ifft(tmp, M, axis=len(s)-1)
  return X

def crandn(shape):
  return (random.randn(shape) + 1j*random.randn(shape))

if __name__=="__main__":

  # First stage PFB parameters
  Mcoarse = 64
  OSRATIO = 4/3
  Dcoarse = int(Mcoarse/OSRATIO)
  Pcoarse = 8
  Lcoarse = Mcoarse*Pcoarse
  M_D = Mcoarse-Dcoarse

  # Second stage PFB parameters
  Mfine = 32 
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
  f_soi = 5.0e3#2.7e3
  argf = 2*np.pi*f_soi/fs

  # protype low pass filter generation
  hcoarse = HannWin.genTaps(Mcoarse, Pcoarse, Dcoarse)
  hfine = HannWin.genTaps(Mfine, Pfine, Dfine)

  # ospfb process
  Xkfine_fft = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)
  Xkfine_pfb = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)

  # filter state for first and second stage filter banks
  zicoarse = np.zeros(Lcoarse, dtype=np.complex128)
  zifine = np.zeros((Mcoarse, Lfine), dtype=np.complex128)

  # bank of decimated lpf
  Ykfine_fft = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)
  Ykfine_pfb = np.zeros((N_FINE_CHANNELS, FINE_FRAMES), dtype=np.complex128)

  # first stage temprorary buffer and filter state since
  # the temporary buffer holds intermediate values as the ospfb and bank of decimated lpf are
  # operating at different intervals (ospfb stepping Dcoarse, while lpf steps Mcoarse)
  ybuf = np.zeros(2*Mcoarse, dtype=np.complex128)
  yi = np.zeros((Mcoarse, Lcoarse-1), dtype=np.complex128) # first stage filter state for bank of decimated lpf
  yifine = np.zeros((Mcoarse, Lfine), dtype=np.complex128) # second stage pfb filter state

  nn=0
  modinc = 0 # ospfb phase compensation rotation
  decmod = 0 # bank of decimated lpf decimation step
  for i in range(0, FINE_FRAMES):
    # ospfb
    Xkcoarse = np.zeros((Mcoarse, Mfine), dtype=np.complex128)

    # bank of lpf
    # the bank of decimated lpf run at a slower interval (steping Mcoarse samples at a time and so intermediate state
    # variables are required to count and keep track.
    # `bufed` is the current write pointer in the temporary index. Processing waits until at least Mcoarse samples are
    # in the temporary buffer marked by `bufed`
    # `yst` and `yed` are used because at different iterations of the bank of decimated lpfs and depending on `decmod`
    # there will be multiple frequency channel outputs and so these keep track of the current coarse frame output.
    yst = 0
    yed = 0
    bufed = 0
    Ykcoarse = np.zeros((Mcoarse, Mfine), dtype=np.complex128)
    for j in range(0, Mfine):
      # generate Dcoarse amount of samples
      sig = 0.001*np.exp(1j*argf*(np.arange(nn*Dcoarse, (nn+1)*Dcoarse)))# + 0.001*crandn(Dcoarse)

      # process through bank of lpf - requires Mcoarse number of samples so monitor and process as necessary
      ybuf[bufed:(bufed+Dcoarse)] = sig
      bufed += Dcoarse

      while (bufed >= Mcoarse):
        y = ybuf[:Mcoarse]
        (Ydec, yi, ndec, decmod) = os_golden(y, hcoarse, yi, Mcoarse, Dcoarse, decmod)
        ybuf[:Mcoarse] = ybuf[-Mcoarse:] # move top half into bottom half, `bufed` keeps track where next write will be
        bufed -= Mcoarse
        # append outputs
        yed = yst + ndec
        Ykcoarse[:, yst:yed] = Ydec
        yst = yed

      # process ospfb
      zicoarse[-Dcoarse:] = sig
      Xkcoarse[:, j] = os_pfb(zicoarse, modinc, hcoarse, Mcoarse, Pcoarse)
      zicoarse[:-Dcoarse] = zicoarse[Dcoarse:]
      modinc = (modinc+M_D) % Mcoarse
      # advance data counter
      nn+=1

    # second stage FFT on ospfb outputs
    Xkfinetmp = fftshift(fft(Xkcoarse, Mfine, axis=1), axes=(1,))/Mfine
    Xkfine_pruned = Xkfinetmp[:, sel_range]
    Xkfine_fft[:, i] = Xkfine_pruned.reshape(N_FINE_CHANNELS)

    #second stage CSPFB on ospfb outputs
    zifine[:, -Mfine:] = Xkcoarse
    Xkfinetmp = fftshift(cs_pfb(zifine, hfine, Mfine, Pfine), axes=(1,))
    Xkfine_pruned = Xkfinetmp[:, sel_range]
    Xkfine_pfb[:, i] = Xkfine_pruned.reshape(N_FINE_CHANNELS)
    zifine[:, :-Mfine] = zifine[:, Mfine:]

    # second stage FFT on bank of decimated lpf outputs
    Ykfinetmp = fftshift(fft(Ykcoarse, Mfine, axis=1), axes=(1,))/Mfine # pretty sure arb. scaling to compare
    Ykfine_pruned = Ykfinetmp[:, sel_range]
    Ykfine_fft[:, i] = Ykfine_pruned.reshape(N_FINE_CHANNELS)

    # second stage CSPFB on bank of decimated lpf outputs
    yifine[:, -Mfine:] = Ykcoarse
    Ykfinetmp = fftshift(cs_pfb(yifine, hfine, Mfine, Pfine), axes=(1,))
    Ykfine_pruned = Ykfinetmp[:, sel_range]
    Ykfine_pfb[:, i] = Ykfine_pruned.reshape(N_FINE_CHANNELS)
    yifine[:, :-Mfine] = yifine[:, Mfine:]

  Sxx_fft = np.mean(np.real(Xkfine_fft*np.conj(Xkfine_fft)), 1)
  Sxx_pfb = np.mean(np.real(Xkfine_pfb*np.conj(Xkfine_pfb)), 1)

  Syy_fft = np.mean(np.real(Ykfine_fft*np.conj(Ykfine_fft)), 1)
  Syy_pfb = np.mean(np.real(Ykfine_pfb*np.conj(Ykfine_pfb)), 1)

  ## plot ################################################################

  # compare second stage outputs when implemented as fft vs cspfb on when ospfb is the first stage
  fig, ax = plt.subplots(2, 1, figsize=(17,15))
  fbins = np.arange(0, N_FINE_CHANNELS)
  ax[0].plot(fbins, 10*np.log10(Sxx_fft))
  ax[0].grid()
  ax[0].title.set_text('OSPFB -> FFT')

  ax[1].plot(fbins, 10*np.log10(Sxx_pfb))
  ax[1].grid()
  ax[1].title.set_text('OSPFB -> CSPFB')
  plt.show()

  plt.figure(figsize=(17,15))
  plt.plot(fbins, 10*np.log10(Sxx_fft))
  plt.plot(fbins, 10*np.log10(Sxx_pfb))
  plt.title("Compare second stage FFT/CSPFB on OSPFB outputs")
  plt.grid()
  plt.show()

  # compare second stage outputs when implemented as fft vs cspfb on when bank of
  # decimated lpf is the first stage
  fig, ax = plt.subplots(2, 1, figsize=(17,15))
  fbins = np.arange(0, N_FINE_CHANNELS)
  ax[0].plot(fbins, 10*np.log10(Syy_fft))
  ax[0].grid()
  ax[0].title.set_text('Bank of Decimated LPF -> FFT')

  ax[1].plot(fbins, 10*np.log10(Syy_pfb))
  ax[1].grid()
  ax[1].title.set_text('Bank of Decimated LPF -> CSPFB')
  plt.show()

  plt.figure(figsize=(17,15))
  plt.plot(fbins, 10*np.log10(Syy_fft))
  plt.plot(fbins, 10*np.log10(Syy_pfb))
  plt.title("Compare second stage FFT/CSPFB on Bank of decimated LPF outputs")
  plt.grid()
  plt.show()

  # compare second stage outputs when first stage is OSPFB or Bank of decimated LPF
  plt.figure(figsize=(17,15))
  plt.plot(fbins, 10*np.log10(Sxx_pfb))
  plt.plot(fbins, 10*np.log10(Syy_pfb))
  plt.title("Compare OSPFB to Bank of decimated LPF outputs following CSPFB")
  plt.grid()
  plt.show()
