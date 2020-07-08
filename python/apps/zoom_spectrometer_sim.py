import numpy as np
from numpy.fft import (fft, ifft, fftshift)

from ospfb import OSPFB
from phasecomp import stack
from taps import HannWin
from utils import (TYPES_INIT, TYPES_MAP)

from source import ToneSource
from goldenmodel import golden

from utils import pltOSPFBChannels
from utils import pltCoarseSpectrum
from utils import pltCompareFine
from utils import pltCompareSxx

if __name__=="__main__":
  print("**** Software OS PFB Symbolic Hardware Simulation ****")
  
  # simulation data type
  SIM_DT = 'cx'

  # OS PFB parameters
  # Note: this program is not optimized and struggles for large M, D, P, NFFT_FINE
  M = 64; D = 48; P = 8;
  NFFT = M

  # second stage parameters
  NFFT_FINE = 128
  FINE_FRAMES = 2
  PLT_BETWEEN_FRAME=False

  taps = HannWin.genTaps(M, P, D)
  ospfb = OSPFB(M=M, D=D, P=P, taps=taps, dt=SIM_DT, followHistory=False)
  ospfb.enable()

  # output stack and collection of output frames
  dout = stack(length=M, dt=SIM_DT)
  ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=TYPES_MAP[SIM_DT])
  fi = 0 # ospfb_data output idx counter

  # storage for golden computation
  golden_in = []

  frameidx = 0
  GfMat = np.zeros((D*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)
  fineSpectrumMat = np.zeros((D*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)

  # initialize data generator
  fs = 10e3
  flist = [2200, 3050, 4125,5000, 6561, 8333]
  ntones = len(flist)

  src = ToneSource(M, sigpowdb=-3, fs=fs, ntones=ntones, freqlist=flist)

  Tvalid = M*P+2

  # why the -1 for Tvalid-1? I remember it has to do with Tvalid having +2 but would it make
  # more sense to instead have Tvalid at +1?
  # I did verify that this is the correct sequence that we want for collecting
  # the output as it lines the frames up into the FFT buffer correctly.

  # Need to advance the ospfb before stepping the sink
  din = TYPES_INIT[SIM_DT] # init din in case ospfb.valid() not ready
  for i in range(0, Tvalid-1):
    # Imitate hardware-like AXIS handshake
    # The OS PFB indicates a new sample will be accepted otherwise din will keep
    # the previous value generated
    if ospfb.valid():
      din = src.genSample()
      golden_in.append(din)

    peout, pe_firout = ospfb.step(din)

  while frameidx < FINE_FRAMES:
    if ospfb.valid():
      din = src.genSample()
      golden_in.append(din)

    peout, _ = ospfb.step(din)

    # need to append each run but need to make sure an ifft shouldn't fire first
    if dout.full:
      x = dout.buf
      ospfb_data[:, fi] = ifft(x, NFFT)*NFFT
      fi += 1
      dout.reset()

    dout.write(peout[1])

    # Second stage fft evaluation

    # if we want to check for NFFT_FINE -1 might want to move fi++ to end of
    # loop instead of right after ifft computation
    if (fi==NFFT_FINE): # we have enough outputs to comute a fine spectrum
      # second fine stage PFB looking for scalloping and aliasing (simplified as
      # just an FFT for now)
      # Must generate enough output windows for a second stage
      N_FINE_CHANNELS = D*NFFT_FINE
      hsov = (M-D)*NFFT_FINE//(2*M)
      fs_os = fs/D
      if (ospfb_data.shape[1] < NFFT_FINE):
        print("Not enough output windows for a second stage NFFT_FINE=", NFFT_FINE)
        sys.exit()
      fineoutputmat = fftshift(fft(ospfb_data, NFFT_FINE, axis=1), axes=(1,))/NFFT_FINE

      fineOutputPruned = fineoutputmat[:,(hsov-1):-(hsov+1)]
      fineSpectrum = fineOutputPruned.reshape(N_FINE_CHANNELS)
      fineSpectrumMat[:, frameidx] = fineSpectrum

      # GOLDEN MODEL CALCULATION
      st = 0
      ed = 0
      GX = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
      decmod = 0
      gi = np.zeros((M, M*P-1), dtype=np.complex128)

      while ed < NFFT_FINE:
        gx = np.array(golden_in[0:M])
        del golden_in[0:M]
        (Gdec, gi, ndec, decmod) = golden(gx, ospfb.taps, gi, M, D, decmod)

        ed = st + ndec
        GX[:, st:ed] = Gdec
        st = ed

      Gfine = fftshift(fft(GX, NFFT_FINE, axis=1), axes=(1,))/NFFT_FINE
      Gfinepruned = Gfine[:, (hsov-1):-(hsov+1)]
      Gf = Gfinepruned.reshape(N_FINE_CHANNELS)
      GfMat[:, frameidx] = Gf
      frameidx += 1

      # clear ospfb_data and reset fi
      ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=TYPES_MAP[SIM_DT])
      fi = 0

      if PLT_BETWEEN_FRAME:
        # plot the most recent output of the OSPFB
        pltCoarseSpectrum(ospfb_data[:,-1], fs)

        # plot individual channels from ospfb simulation outputs
        pltOSPFBChannels(M, 4, 8, fineoutputmat, hsov, fs_os, pruned=False)
        pltOSPFBChannels(M, 4, 8, fineoutputmat, hsov, fs_os, pruned=True)

        # plot full fine spectrum for ospfb simulation and model
        pltCompareFine(fineoutputmat, Gfine, N_FINE_CHANNELS, NFFT_FINE, fs_os, hsov)


  # plot the PSD estimates comparing the simulated model with the gold standard
  pltCompareSxx(fineSpectrumMat, GfMat, N_FINE_CHANNELS, NFFT_FINE, fs_os, hsov)
