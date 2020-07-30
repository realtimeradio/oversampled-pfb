import struct
import numpy as np

def read_char(fname, samps):
  """
  The alternative approach would be instead to write each byte in SV using multiple %c formatters and then we coudl read in the exact
  number we would just need to make sure to get the correct endianess format on the struct in this case it would be '>128'
  """

  fmt = '>{}h'.format(samps)

  fp_dat = open(fname, 'rb')
  bindat = fp_dat.read()
  fp_dat.close()

  d = struct.unpack(fmt, bindat)

  x = np.asarray(d, dtype=np.int16)

  return x

def read_unformat_bin(fname, samps):
  """
  The ADC sim runs producing 16-bit (2-byte) samples but each fwrite with %u writes unformatted binary data using the native architecture
  endianess resulting file is written as a 32-bit (4-byte) word. So we have to read in twice as many signed shorts and then drop every
  other one
  """

  fmt = '{}h'.format(samps*2)

  fp_dat = open(fname, 'rb')
  bindat = fp_dat.read()
  fp_dat.close()

  d = struct.unpack(fmt, bindat)
  d = d[::2] # skip every other short

  x = np.asarray(d, dtype=np.int16)

  return x

def read_cx_bin(fname, samps):
  """
  The ADC sim runs producing 16-bit (2-byte) samples but each fwrite with %u writes unformatted binary data using the native architecture
  endianess resulting file is written as a 32-bit (4-byte) word. So we have to read in twice as many signed shorts and then drop every
  other one
  """

  fmt = '{}h'.format(samps*2)

  fp_dat = open(fname, 'rb')
  bindat = fp_dat.read()
  fp_dat.close()

  d = struct.unpack(fmt, bindat)

  xi = np.asarray(d[::2], dtype=np.int16)
  xq = np.asarray(d[1::2], dtype=np.int16)

  return (xi, xq)

if __name__=="__main__":
  import sys
  import matplotlib.pyplot as plt
  from numpy.fft import (fft, fftshift)
  from numpy import (abs, log10)

  fname = "dat/cx_adc_data.bin"
  SAMPS = 128

  #x = read_char(fname, SAMPS)
  #x = read_unformat_bin(fname, SAMPS)
  (xi, xq) = read_cx_bin(fname, SAMPS)

  sys.exit()
  X = fft(x, SAMPS)

  magX = 20*log10(abs(fftshift(X)))

  fbins = np.arange(0, SAMPS)

  plt.plot(fbins, magX)
  plt.grid()
  plt.show()
