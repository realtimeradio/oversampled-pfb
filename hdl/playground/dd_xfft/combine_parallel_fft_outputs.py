import struct
import numpy as np
import matplotlib.pyplot as plt
from numpy.fft import (fft, fftshift)
if __name__=="__main__":

  """
    On a quad ADC RFSoC part with the RFDC configured I/Q mode, with 4 AXI output samples
    per clock the data are packed at each time step with the newest samples to the oldest
    samples as 2 byte words from the MSB down to the LSB, e.g.,

      n0 = {Q1, I1, Q0, I0}, n1 = {Q3, I3, Q2, I2}, n2 = {Q5, I5, Q4, I4}, ...

    My impulse generators (in this case specifically impulse_generator6) the data match
    the RFDC outputs. And are split

    After passing through the parallel FFT the data are output from the system verilog
    testbench as 4 bytes unformatted in native endian format. The otuput from the
    'hi_vip` (output of xfft_1) is written first followed by the 'lo_vip' (output of
    xfft_0).
  """

  Nfft = 32
  Nfft_2 = 16

  Nframes = 2
  
  fname = "parallel_fft.bin"
  fp = open(fname, 'rb')

  # get raw byte array
  d = fp.read()

  """
    unpack the data as an array of int16

    The testbench writes 4 bytes native endian format per sample, this flips the re and imaginary part
    of the word such that the 'dat' variable is now:

      x = I1, Q1, I0, Q0, I3, Q3, I2, Q2, I5, Q5, I4, Q4, ...           (1)

    Also, our data are two bytes ('h' formatter) but we need another multipler by 2 to get to 4 bytes
    needed that the testbench writes out
  """
  num_bytes_read = Nfft*Nframes*2
  fmt = "{}h".format(num_bytes_read)
  dat = np.asarray(struct.unpack(fmt, d))

  # start to parse the data to rearange it correctly. Recall from above the endianess has swapped re/im
  # part from how the testbench wrote the data
  xi = dat[::2]
  xq = dat[1::2]

  # create complex data, everything is aligned at this stage to do so as a single variable
  x = xi + 1j*xq

  """
    Take x a single dimensional array, time order the data correctly, and produce a matrix (Nfft, Nframes)
  """
  x = np.fliplr(x.reshape(Nframes*Nfft_2,2)).reshape(Nframes*Nfft_2*2,).reshape(Nframes,Nfft).T

  """
    In this approach we are processing multiple samples by doing two Nfft/SAMP_PER_CLK point FFTs and
    and then the last stage FFT is a SAMP_PER_CLK point FFT ran in parallel. So in our case we will
    be processing two samples per clock and therefore are Nfft/2 with the final stage a radix-2 butterfly.

    In this approach the incoming time samples are decimated and split between the two parallel Nfft/2
    point FFTs. X1 receives the even samples [x0, x2, x4, x6, ...] and X2 receives the odd samples
    [x1, x3, x5, x7, x9, ...]

    Since the RFDC outputs samples ordered as in (1) this means that samples to go to X1 are at the lower
    end of the word and X2 gets the samples at the high end of the word. (X2 hi, X1 lo)

    The last computation above uses np.fliplr to put the time output sequence [x1, x0, x3, x2, x5, x4...]
    into the correct order. This means that in the next step we can correctly decimate the x sequence
    to form X1 and X2 since the data is now [x0, x1, x2, x3, x4, x5, ...].

    Had I not done the fliplr step it make since that this would be reversed (e.g., X2 = x[::2], X1 = x[1::2])
  """
  X1 = x[::2]
  X2 = x[1::2]

  X1 = X1.reshape(Nfft_2, Nframes)
  X2 = X2.reshape(Nfft_2, Nframes)

  n = np.arange(0, Nfft)
  k = n[0:int(Nfft_2)]

  Wk = np.exp(-1j*2*np.pi*k/Nfft)

  Xlo = X1[:,0] + Wk*X2[:,0]
  Xhi = X1[:,0] - Wk*X2[:,0]

  Xk = np.concatenate([Xlo, Xhi])

  """
    create simulated version to compare with
  """

  xsim = np.zeros(Nfft, dtype=np.complex)
  xsim[2] = 256 # impulse for first complex fundamental on output

  x1sim = xsim[0::2]
  x2sim = xsim[1::2]

  X1sim = fft(x1sim, Nfft_2)/Nfft_2
  X2sim = fft(x2sim, Nfft_2)/Nfft_2

  Xlosim = X1sim + Wk*X2sim
  Xhisim = X1sim - Wk*X2sim
  Xksim = np.concatenate([Xlosim, Xhisim])

