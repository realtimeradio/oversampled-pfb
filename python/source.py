import numpy as np
from numpy import random
from numpy import fft

from scipy import signal

class Source(object):
  """
  Simulation source for generating samples
  """
  def __init__(self, M=8): # general M
    self.M = M
    # decimated time index? will have to change something to get it to start at
    # zero
    self.i = 0
    self.modtimer = 0

  def genSample(self):
    dout = self.__createSample__()
    
    # update meta data on number of cycles ran
    self.modtimer = (self.modtimer+1) % self.M
    self.i = self.i+1 if self.modtimer == 0 else self.i

    return dout

  def __createSample__(self):
    pass

class BlueNoise(Source):
  def __init__(self, M=8, powdb=1):
    super().__init__(M)
    self.powdb = powdb
    self.pow = 10**(powdb/10)
    self.length=1024

    self.h = fft.ifft(fft.fftshift(np.sqrt(np.linspace(1,3,self.length))))
    self.zi = np.zeros(self.length-1)


  def __createSample__(self):

    xw = np.sqrt(self.pow/2)*(random.randn() + 1j*random.randn())

    dout, self.zi = signal.lfilter(self.h, 1, [xw], zi=self.zi)

    return dout

class ToneSource(Source):
  def __init__(self, M=8, fs=2048, sigpowdb=10, noisepowdb=1, ntones=1, freqlist=[1000]):
    super().__init__(M)
    self.fs = fs
    self.sigpowdb = sigpowdb
    self.noisepowdb = noisepowdb
    self.ntones = ntones
    self.f_soi = freqlist

    self.sigpow = 10**(sigpowdb/10)
    self.noisepow = 10**(noisepowdb/10)

  def __createSample__(self):
    dout = 0.0
    Amp = self.sigpow/np.sqrt(2)

    for f in self.f_soi:
      omega = 2*np.pi*f
      n = self.i*self.M + self.modtimer
      argf = omega*n/self.fs

      dout = dout + Amp*(np.cos(argf) + 1j*np.sin(argf))

    noise = np.sqrt(self.noisepow/2)*(random.randn() + 1j*random.randn())

    dout = dout + noise
    return dout

class CounterSource(Source):
  def __init__(self, M=8, order='natural'):
    super().__init__(M)
    self.order = order

  def __createSample__(self):

    if self.order == 'natural':
      val = self.i*self.M + self.modtimer
    else:
      val = (self.i+1)*self.M - self.modtimer - 1

    dout = val
    return dout

class SymSource(Source):
  def __init__(self, M=8, order='natural'):
    super().__init__(M)
    self.order = order

  def __createSample__(self):
    # TODO: The initial os pfb class allowed for an initval variable that would
    # set the first samples into the pfb. This was an artifact of my hand drawn
    # DG/SFG formulation that would use x-11 or x1 or x0 as the first input
    # sample. If I want that behaviour again I think I will need to include that
    # here instead. Since the OSPFB now doesn't generate its own samples.

    # natural order delivers samples in ascending order x0, x1, ..., etc.
    # processing order is newest to oldest, port x_M-1 down to x0, x_(2*M-1)
    # down to x_M, ..., etc.
    if self.order=='natural':
      val = (self.i)*self.M + self.modtimer
    else:
      val = (self.i+1)*self.M - self.modtimer - 1

    dout = "x{}".format(val)
    return dout


if __name__=="__main__":
  import matplotlib.pyplot as plt

  NBLK = 100
  M=1024
  NFFT = M
  flist = [2000, 4000, 6000, 8000]
  ntones = len(flist)
  fs = 10e3
 
  #src = ToneSource(M, fs=fs, ntones=4, freqlist=flist)
  src = BlueNoise(M, powdb=0)

  x = np.zeros(NFFT,dtype=np.complex128)
  X = np.zeros((M,NBLK), dtype=np.complex128)
  for k in range(0, NBLK):
    for i in range(0, NFFT):
      x[i] = src.genSample()
    X[:,k] = fft.fft(x, NFFT)

  Sxx = np.abs(X)**2

  Sxxhat = np.mean(Sxx, axis=1)

  fbins = np.arange(0,NFFT)
  df = fs/NFFT

  plt.plot(fbins*df, 20*np.log10(np.abs(X[:,99])))
  plt.ylim([-60, 60])
  plt.grid()
  plt.show()

  Sxx = np.mean(X, axis=1)
  plt.plot(fbins*df, 10*np.log10(Sxxhat))
  plt.ylim([-60,60])
  plt.grid()
  plt.show()

  

 
