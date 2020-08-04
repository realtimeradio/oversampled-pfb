import sys
import numpy as np
from numpy.fft import (fft, ifft, fftshift)
import matplotlib.pyplot as plt

from ospfb import OSPFB
from phasecomp import stack

from source import Impulse
from goldenmodel import golden

from taps import (Ones, HannWin)

from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)

if __name__=="__main__":
  M=32; D=24; P=8;
  NFFT = M
  NFFT_FINE = 128
  FRAMES = 128
  FINE_FRAMES = 1
  SIM_DT = 'float'

  taps = M*P*Ones.genTaps(M, P, D)
  #taps = HannWin.genTaps(M, P, D)
  ospfb = OSPFB(M=M, D=D, P=P, taps=taps, dt=SIM_DT, followHistory=False)
  ospfb.enable()

  k = 0
  src = Impulse(M, P, D, k, dt=SIM_DT)

  # output stack and collection of output frames
  dout = stack(length=M, dt=SIM_DT)
  ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
  fi = 0 # ospfb_data coarse output idx counter
  frameidx = 0 # fine frame output idx counter

  # storage for golden computation
  golden_in = []

  din = TYPES_INIT[SIM_DT]
  while frameidx < FINE_FRAMES:
  #while fi < FRAMES:
    if ospfb.valid():
      din = src.genSample()
      golden_in.append(din)
    #else:
    #  src.genSample() # still want to step the source to get the correct sequence spacing

    peout, pe_firout = ospfb.step(din)

    # need to append each run but need to make sure an ifft shouldn't fire first
    if (dout.full):
      x = dout.buf
      ospfb_data[:, fi] = ifft(x, NFFT)# *NFFT
      fi += 1
      dout.reset()

    dout.write(peout[1])

    if (fi == NFFT_FINE):
      # GOLDEN MODEL CALCULATION
      st = 0
      ed = 0
      GX = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
      decmod = 0
      gi = np.zeros((M, M*P-1), dtype=np.complex128)

      while ed < NFFT_FINE:
        gx = np.array(golden_in[0:M])
        del golden_in[0:M]
        # few things to note:
        # 1. need to roll the input so that it presents itself correctly to the golden model.
        #    for k=D+1 here in the python hardware version a roll of 7 will put the impulse
        #    in the zeroth location for the constant output of the fft.
        #    This need to roll is expected as it is the same in the matlab version that
        #    how my impulse data is generated is different between the matlab golden and the
        #    simulation version.
        # 2. However, it seems that each golden output ramps up to the full (in the case of
        #    the constant output from 1 to P where the matlab version is constantly output
        #    at 8 from the beginning.
        (Gdec, gi, ndec, decmod) = golden(np.roll(gx, 7), ospfb.taps, gi, M, D, decmod)

        ed = st + ndec
        GX[:, st:ed] = Gdec/M # scale back down by M to match
        st = ed

      fig, ax = plt.subplots(2, 1) 
      ax[0].plot(np.arange(0,M), np.real(ospfb_data))
      ax[1].plot(np.arange(0,M), np.real(GX))
      ax[0].grid(); ax[1].grid();
      plt.show()

      # clear ospfb_data, reset fi, advance fine frame
      ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
      fi = 0
      frameidx += 1

      

  """
  START HERE:
  
  A few things I notice:

  1. I never get up to the output equal to P like in my MATLAB simulations
  2. I have a zero in this plot. In my matlab plots I can also have zeros but it is the last frame that
     equals zero and I thought that was because I just didn't produce enough data to process that frame
  3. The k=D+1 here instead of what I thought would be D-1. This is the starting impulse phase. In
     matlab I claim I understood it because matlab was one-based. Making me think here it would be D-1
     however, that is not the case it is D+1

  ** should run the golden model to capture the output and compare with what matlab gives
  """
