import numpy as np
from numpy import random
from numpy import fft

from scipy import signal

from utils import (TYPES, TYPES_MAP)

from fixedpoint import s16

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

class RFDC():
  def __init__(self, fs=2.048e9, bits=12, fsv=1.0, sample_mode='sim_cx', output_mode='twos'):
    """
      sample_mode:
        cx - simulate digital down converter
        sim_cx - expected to receive a complex tone on the input
        real - sample real signal

      output_mode:
        twos - output data backed as binary data for complex sampled modes the data are {vq, vi}
        natural - single natural number for real mode and tuble for complex sampling modes
    """
    self.fs = fs                                      # sample rate [hz]
    self.dt = 1/self.fs                               # sample period [s]
    self.bits = bits                                  # adc bit resolution [bits]
    self.fsv = fsv                                    # full-scale voltage [volts]
    self.vpk = self.fsv/2.0                           # peak voltage [volts]
    self.lsb_scale = -self.vpk * -2**-(self.bits-1)   # scaling weight [volts / bit]
    self.bit_range = (-2**(self.bits-1), 2**(self.bits-1) - 1)

    self.Rtile = 100                                  # [ohm]
    self.vrms = self.vpk/np.sqrt(2)                   # [volts]
    self.Pmax = self.vrms**2/self.Rtile               # [watts]

    self.sample_mode = sample_mode
    self.nco = self.fs/2                              # [hz]
    self.decimation_fac = 1

  def fromNative16(v):
    """
      pythons built in types don't display correctly when doing bin()/hex() of a negative
      number so we convert them to the integer version so we can have the correct number
      that when interpreted as two's complement gives us right numbers
    """
    return (v & 0x8000) | (v & 0x7fff)

  def quantize(self, q):
    # quantize
    d = np.round(q/self.lsb_scale)
    # saturate - where() is over the top with it being one sample but poteitnally extend to an array in the future
    d = bit_range[0] if d < self.bit_range[0] else d
    d = bit_range[1] if d > self.bit_range[1] else d

    return np.int16(d)

  def sample(self, v):

    if (np.abs(v) > self.vpk):
      print("WARNING: input voltage greater than ADC can tolerate")
    
    if self.sample_mode=='cx':
      omega = 2*pi*self.nco/self.fs
      # TODO: how to keep track of sample time for digital down converter
      vi = v*np.cos(omega)

      out = None

    elif self.sample_mode=='sim_cx':
      vi = np.real(v)
      vq = np.imag(v)

      vi = self.quantize(vi)
      vq = self.quantize(vq)

      out = (vq, vi)

    elif self.sample_mode=='real':
      vi = self.quantize(v)

      out = vi

    else:
      print("sample mode configuration error")
      sys.exit()

    return out

    #if output_mode=='twos':
    #  vi = self.fromNative(vi)
    #  vq = self.fromNative(vq)

    #  # concatenate output as {vq, vi} in to be interpreted as two's complement
    #  out = (vq << 16) | vi
    #  """
    #  to get the number back we would do:
    #    vi = out & 0xffff
    #    vq = (out & 0xffff0000) >> 16
    #  """
    #
    #return out

class ToneGenerator(Source):
  def __init__(self, M=8, fs=2048, sigpow_dBm=-6, f=100, rload=100):
    super().__init__(M)
    self.rload = rload                               # [ohms]
    self.fs = fs                                     # [hz]
    self.sigpow = 10**(sigpow_dBm/10)*1e-3           # [watts]
    self.vrms = np.sqrt(self.rload*self.sigpow)
    self.vpk = self.vrms*np.sqrt(2)
    self.f_soi = f

  def __createSample__(self):
    omega = 2*np.pi*self.f_soi
    n = self.i*self.M + self.modtimer
    argf = omega*n/self.fs

    sample = self.vpk*(np.cos(argf) + 1j*np.sin(argf))

    return sample

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

class Impulse(Source):
  def __init__(self, M=8, P=4, D=6, k=0, dt='float'):
    super().__init__(M)
    self.P = P
    self.D = D
    self.L = M*P
    self.dt = TYPES_MAP[dt]
    if (k < 0 or k > self.M-1):
      print("ERROR: valid impulse index are: 0 <= k < M-1")

    self.k = k

  def __createSample__(self):
    if (self.modtimer==self.k):
      # TODO: add dynamic weight, may potentially want to add to track scaling, quantization etc.
      return self.dt(1)
    else:
      return self.dt(0)

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

  

 
