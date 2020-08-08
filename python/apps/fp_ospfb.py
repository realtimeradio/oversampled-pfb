import numpy as np
from numpy.fft import (fft, ifft, fftshift)

from ospfb import OSPFB
from phasecomp import stack
from taps import (HannWin, Ones)
from utils import (TYPES_INIT, TYPES_MAP)

from source import (RFDC, ToneGenerator)
from goldenmodel import golden

import matplotlib.pyplot as plt

if __name__=="__main__":
  print("**** Software OS PFB Symbolic Hardware Simulation ****")

  """
  Note: The current hardware does not correctly compute arithmetic, rounding and scaling (shifting)
  and so using full ALPACA specs (specifically 15/16 bit coefficients, 12 bit ADC) then keeping the
  data width of the delay buffers at 16 causes overflow and the hardware simulation suffers from
  overflow and truncation issues.

  To an extent those issues can be shown here as the python ospfb can accept different data types.
  The python simulator does not do scaling and shifting but when you do SIM_DT=int32, COEFF_WID=15,
  ADC_BITS=12 and run the small PFB (M=64, D=48, P=4) you see how the PFB filter ramp up exhibits the
  same shallow, and notch behavior of the Hann window until it becomes the steep narrow cliff. Showing
  that it was the hardware was never able to pass the ramp up and was shallow due to bit growth
  and truncation.

  But since the python and hardware simulations accept parameterized using ADC_BITS=8 and
  COEFF_WID=4 with P=4 the entire filter growth (since the FFT is float) can fit in int16's. You see
  a little more quantization noise in the floor of the spectrum from the coefficients but the 4 bit
  coefficients still results in a nice windowed spectrum. Then applying this to the hardware simulator
  the outputs are very similar
  """ 
  # simulation parameters 
  SIM_DT = 'int16'    # data type
  COEFF_WID = 4       # doesn't ovf at 9 (need to do closer analysis)
  ADC_BITS = 8        # adc resolution, signed twos-complement

  # OS PFB parameters
  # Note: this program (mainly the golden model) is not optimized and struggles for large M, D, P, NFFT_FINE
  M = 64
  osratio = 3.0/4.0
  D = int(M*osratio)
  P = 4
  NFFT = M

  NFFT_FINE = 32              # second stage fine fft size
  FINE_FRAMES = 1             # number of fine frames to compute

  MAX_COARSE_FRAMES = 100     # keep up to this amount of coarse channels without deleting them
  COARSE_FRAMES_TO_PLOT = 32  # which of the saved coarse frames to use to plot

  PLT_BETWEEN_FRAME=False

  # initialize data generator
  fs = 2048#10e3
  flist = [500] #[2200]#, 3050, 4125,5000, 6561, 8333]
  ntones = len(flist)

  src = ToneGenerator(M=M, fs=fs, sigpow_dBm=0, f=flist[0])

  # initialize ADC
  rfdc = RFDC(bits=ADC_BITS)

  # generate filter taps
  h = HannWin.genTaps(M, P, D)
  #h = Ones.genTaps(M, P, D)
  filter_pk = np.max(h)
  lsb_scale = filter_pk/(2**(COEFF_WID-1)-1)
  h_scale = h/lsb_scale;
  h_quant = np.array(h_scale, dtype=TYPES_MAP['int16'])

  ospfb_re = OSPFB(M=M, D=D, P=P, taps=h_quant, dt=SIM_DT, followHistory=False)
  ospfb_im = OSPFB(M=M, D=D, P=P, taps=h_quant, dt=SIM_DT, followHistory=False)
  ospfb_re.enable()
  ospfb_im.enable()

  # output stack and collection of output frames
  dout_re = stack(length=M, dt=SIM_DT)
  dout_im = stack(length=M, dt=SIM_DT)
  ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
  saved_coarse_data = np.zeros((NFFT, MAX_COARSE_FRAMES), dtype=np.complex128)
  ci = 0 # saved coarse outputs idx
  fi = 0 # ospfb_data output idx counter
  frameidx = 0 # fine frame output idx counter

  # storage for golden computation
  golden_in = []

  # Need to advance the ospfb before stepping the sink
  din_re = TYPES_INIT[SIM_DT] # init din in case ospfb.valid() not ready
  din_im = TYPES_INIT[SIM_DT] # init din in case ospfb.valid() not ready
  while frameidx < FINE_FRAMES:
    if (ospfb_re.valid() and ospfb_im.valid()):
      din_im, din_re = rfdc.sample(src.genSample())
      golden_in.append(din_re+1j*din_im)

    peout_re, pe_firout_re = ospfb_re.step(din_re)
    peout_im, pe_firout_im = ospfb_im.step(din_im)

    # need to append each run but need to make sure an ifft shouldn't fire first
    if (dout_re.full and dout_im.full):
      xi = dout_re.buf
      xq = dout_im.buf
      ospfb_data[:, fi] = ifft(xi+1j*xq, NFFT)*NFFT # Scale or not? probably not, depends on hardware
      if (ci != MAX_COARSE_FRAMES):
        saved_coarse_data[:, ci] = ospfb_data[:, fi]
        ci += 1
      fi += 1
      dout_re.reset()
      dout_im.reset()

    dout_re.write(peout_re[1])
    dout_im.write(peout_im[1])

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
        (Gdec, gi, ndec, decmod) = golden(gx, ospfb_re.taps, gi, M, D, decmod)

        ed = st + ndec
        GX[:, st:ed] = Gdec
        st = ed

      ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
      fi = 0
      frameidx += 1


  PLT_WIDTH = 4
  PLT_DEPTH = COARSE_FRAMES_TO_PLOT//PLT_WIDTH

  fbins = np.arange(0, NFFT)
  fig, ax = plt.subplots(PLT_DEPTH, PLT_WIDTH, sharey='row')
  for i in range(0, PLT_DEPTH):
    for j in range(0, PLT_WIDTH):
      idx = (i*PLT_WIDTH) + j
      cur_ax = ax[i,j]

      cur_ax.plot(fbins, 20*np.log10(np.abs(saved_coarse_data[:, idx]+0.0001)))
      cur_ax.grid()
  plt.show()

  # alternativly could plot all of them
  #plt.plot(fbins, magX.transpose())
