from fixedpoint import toSigned
import numpy as np
from numpy.fft import fft
import matplotlib.pyplot as plt
"""
  readmemb is probably the best method to use because working on the bit
  level means you don't have to really worry about the nibble (4-bit) boundary
  with hex formatted data

  unless you know all your data will multiples of 4-bits
"""
if __name__=="__main__":

  fname = "/home/mcb/git/alpaca/oversampled-pfb/hdl/sim/tb/parallel_fft_wbutterfly.bin"

  # need to work in the number of frames
  Nfft = 32
  Nfft_2 = Nfft//2
  Xk_lo = np.zeros(Nfft_2, dtype=np.complex)
  Xk_hi = np.zeros(Nfft_2, dtype=np.complex)

  n = np.arange(0, Nfft)
  k = np.arange(0, Nfft_2)

  dat = np.loadtxt(fname, dtype=str, skiprows=3)

  bit_width = 40
  
  for i, packed in enumerate(dat):
    unpacked = [int(packed[i*bit_width:(i+1)*bit_width],2) for i in range(0, 4)]
    """
      will come out (im, re, im, re), but need to make sure I get which one
      is Xk[n] and Xk[n+Nfft_2]
    """
    print([hex(i) for i in unpacked])
    Xklo_im = toSigned(unpacked[2], bit_width)
    Xklo_re = toSigned(unpacked[3], bit_width)

    Xkhi_im = toSigned(unpacked[0], bit_width)
    Xkhi_re = toSigned(unpacked[1], bit_width)

    Xk_lo[i] = Xklo_re + 1j*Xklo_im
    Xk_hi[i] = Xkhi_re + 1j*Xkhi_im

  Xk = np.concatenate([Xk_lo, Xk_hi])
  Xk = Xk#*(2**(-22))# alternates between needing the scaling and not, because of how the impulse switches between going into X1 and X2 and
                     # so when it goes into X2 is when it gets multiplied by Wk

  """
  """
  xsim = np.zeros(Nfft, dtype=np.complex)
  xsim[2] = 256 # impulse for first complex fundamental on output

  x1sim = xsim[0::2]
  x2sim = xsim[1::2]

  X1sim = fft(x1sim, Nfft_2)/Nfft_2
  X2sim = fft(x2sim, Nfft_2)/Nfft_2

  Wk = np.exp(-1j*2*np.pi*k/Nfft)

  Xlosim = X1sim + Wk*X2sim
  Xhisim = X1sim - Wk*X2sim
  Xksim = np.concatenate([Xlosim, Xhisim])

  fig, ax = plt.subplots(2, 1)

  ax[0].stem(n, np.real(xsim))
  ax[0].grid()

  ax[1].plot(n, np.real(Xk), label="Hardware")
  ax[1].plot(n, np.real(Xksim), label="FP Simulation", linestyle='--')
  ax[1].legend(loc="upper right")
  ax[1].grid()

  ax[0].title.set_text('FFT Input Sequence')
  ax[0].set_ylabel('arb. units')
  ax[0].set_xlabel('Sample Index')

  ax[1].title.set_text('FFT Output')
  ax[1].set_ylabel('arb. units')
  ax[1].set_xlabel('Bin Index')

  fig.tight_layout()
