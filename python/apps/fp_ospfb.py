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
  
  # simulation parameters 
  SIM_DT = 'int32'    # data type
  COEFF_WID = 8
  TDATA_WID = 16
  # need an int16 source which is what I was working on last night but would also need an ospfb
  # that matches my hardware that processes real and imaginary parts

  # OS PFB parameters
  # Note: this program is not optimized and struggles for large M, D, P, NFFT_FINE
  M = 256; D = int(M*3.0/4.0); P = 4;
  NFFT = M

  FRAMES = 20
  PLT_BETWEEN_FRAME=False

  # initialize data generator
  fs = 2048#10e3
  flist = [500] #[2200]#, 3050, 4125,5000, 6561, 8333]
  ntones = len(flist)

  src = ToneGenerator(M=M, fs=fs, sigpow_dBm=0, f=flist[0])

  # initialize ADC
  rfdc = RFDC()

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
  ospfb_data = np.zeros((NFFT, FRAMES), dtype=TYPES_MAP[SIM_DT])
  fi = 0 # ospfb_data output idx counter

  # storage for golden computation
  golden_in_re = []
  golden_in_im = []

  # Need to advance the ospfb before stepping the sink
  din = TYPES_INIT[SIM_DT] # init din in case ospfb.valid() not ready
  while fi < FRAMES:
    if (ospfb_re.valid() and ospfb_im.valid()):
      din_im, din_re = rfdc.sample(src.genSample())
      golden_in_re.append(din_re)
      golden_in_im.append(din_im)

    peout_re, pe_firout_re = ospfb_re.step(din_re)
    peout_im, pe_firout_im = ospfb_im.step(din_im)

    # need to append each run but need to make sure an ifft shouldn't fire first
    if (dout_re.full and dout_im.full):
      xi = dout_re.buf
      xq = dout_im.buf
      ospfb_data[:, fi] = ifft(xi+1j*xq, NFFT)*NFFT
      fi += 1
      dout_re.reset()
      dout_im.reset()

    dout_re.write(peout_re[1])
    dout_im.write(peout_im[1])


  PLT_WIDTH = 4
  PLT_DEPTH = FRAMES//PLT_WIDTH

  fbins = np.arange(0, NFFT)
  fig, ax = plt.subplots(PLT_DEPTH, PLT_WIDTH, sharey='row')
  for i in range(0, PLT_DEPTH):
    for j in range(0, PLT_WIDTH):
      idx = (i*PLT_WIDTH) + j
      cur_ax = ax[i,j]

      cur_ax.plot(fbins, 20*np.log10(np.abs(ospfb_data[:, idx]+0.0001)))
      cur_ax.grid()

  # alternativly could plot all of them
  #plt.plot(fbins, magX.transpose())
  plt.show() 

