
from numpy import (dtype, int8, float32, complex64)
from numpy import (arange, zeros, pi, sqrt, cos, sin, abs, log10, random, fft)
import matplotlib.pyplot as plt

SCALE_FACTOR = 127

# custom data type for complex basebanded data that isn't a native type
cx_int8_t = dtype([('re', int8), ('im', int8)])

if __name__=="__main__":

  # Signal scenario
  fs = 10e3         # sample rate (Hz)
  f = 2e3           # frequency of interest (Hz)
  t = 2.0           # simulation time (s)

  Nsamps = int(t*fs)
  x = zeros(Nsamps, dtype=cx_int8_t)

  # generate samples
  omega = 2*pi*f
  for n in range(0, Nsamps):
    x[n]['re'] = SCALE_FACTOR*0.1*cos(omega*n/fs) + SCALE_FACTOR*0.1*random.randn()
    x[n]['im'] = SCALE_FACTOR*0.1*sin(omega*n/fs) + SCALE_FACTOR*0.1*random.randn()
  

  x = x.view(int8).astype(float32).view(complex64)

  # perform DFT using the FFT
  Nfft = 2048
  X = fft.fft(x, Nfft)/Nfft

  # plot
  fbins = arange(0, Nfft)
  faxis = fbins*fs/Nfft

  plt.plot(faxis, 20*log10(abs(X)))
  plt.xlim([min(faxis), max(faxis)])
  plt.xlabel('Frequency (Hz)')
  plt.ylabel('Power (arb. units dB)')
  plt.grid()
  plt.show()

