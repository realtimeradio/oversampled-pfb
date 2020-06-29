import numpy as np

TYPES = (str, 'int16', 'int32', int, float, 'complex128', bool)

TYPES_MAP = {
  # max representable is a 128 long string per buffer element
  'str'   : np.dtype((np.unicode_, 128)),
  'int16' : np.int16,
  'int32' : np.int32,
  'int'   : int,
  'float' : float,
  'cx'    : np.complex128,
  'bool'  : bool
}

TYPES_INIT = {
  'str'   : '-',
  'int16' : 0,
  'int32' : 0,
  'int'   : 0,
  'float' : 0.0,
  'cx'    : 0+0*1j,
  'bool'  : False
}

TYPES_STR_FMT = {
  'str'   : ':<4s',
  'int'   : ':<4d',
  'cx'    : ':<4g',
}

import matplotlib.pyplot as plt
from numpy import log10, abs, max


def pltCoarseSpectrum(spectrum, fs):
  nbins = spectrum.shape[0]
  df = fs/nbins

  fbins = np.arange(0, nbins)
  faxis = fbins*fs/nbins

  plt.plot(faxis, 20*log10(abs(spectrum)))
  plt.grid()
  plt.show()

def pltFineSpectrum(spectrum, fs, hsov, pruned=True):
  """
  Plot the fine spectrum of the ospfb

  In reality it never makes sense to plot a "continous" spectrum of the
  oversamplede PFB without pruning first because the spectrum isn't continous.
  This is because in reality the channels overlap and the plots and to show on a
  contious axis would require placing the channels in the appropriate position to
  show the overlap on a continous frequency axis.

  However, since there is still information in the full coarse channel we keep
  all the data until we wish to present it.
  """

  NFFT_FINE = spectrum.shape[1]

  if pruned:
    spectrum = spectrum[:, (hsov-1):-(hsov+1)]

  # number of fine channels in the resulting spectrum of an ospfb is D*NFFT_FINE
  nbins = spectrum.shape[0]*spectrum.shape[1]
  spectrum = spectrum.reshape(nbins)

  fshift = -(NFFT_FINE/2-hsov+1)
  fbins = np.arange(0, nbins)* + fshift
  faxis = fbins*fs/NFFT_FINE

  plt.plot(faxis, 20*log10(abs(spectrum)))
  plt.grid()
  plt.show()

def pltCompareFine(model, golden, nfine_channels, nfft_fine, fs_os, hsov):
  """
  Compare a single frame of output date for the simulated model and gold
  standard model.

  model and golden - are (nfft x nfft_fine) matrices of output data from the
  second stage pfb whre overlapping channels have not yet been discarded.
  """
  model = model[:, (hsov-1):-(hsov+1)]
  golden = golden[:, (hsov-1):-(hsov+1)]

  model = model.reshape(nfine_channels)
  golden = golden.reshape(nfine_channels)

  model = np.real(model*np.conj(model))
  golden = np.real(golden*np.conj(golden))

  fshift = -(nfft_fine/2-hsov+1) 
  fbins_fine = np.arange(0, nfine_channels) + fshift
  faxis_fine = fbins_fine*fs_os/nfft_fine

  plt.plot(faxis_fine, 10*np.log10(model), label='model')
  plt.plot(faxis_fine, 10*np.log10(golden), label='golden', linestyle='--')
  plt.xlabel("Frequency")
  plt.ylabel("Power (arb units dB)")
  plt.legend()
  plt.grid()
  plt.show()

def pltCompareSxx(model, golden, nfine_channels, nfft_fine, fs_os, hsov):
  """
  Compare the PSD estimate of the simulated model and gold standard model.

  For this method the model and golden spectrum are matrices for collections of
  frames we are averaging over. Therefore, they have already been pruned

  #TODO: already being pruned doesn't have to be true in gernal. In fact it
  wouldn't it make more sense from an instrument point of view to not throw away
  the overlapped channels until we have to for presentation just like the rest of
  the functions

  model and golden - are (nfine_channels x nframes) matrix of data where nframes
  is the number of frames we are averaging over.

  """

  Sxx_model = np.mean(np.real(model*np.conj(model)), 1)
  Sxx_golden = np.mean(np.real(golden*np.conj(golden)), 1) 

  fshift = -(nfft_fine/2-hsov+1) 
  fbins_fine = np.arange(0, nfine_channels) + fshift
  faxis_fine = fbins_fine*fs_os/nfft_fine

  plt.plot(faxis_fine, 10*np.log10(Sxx_model), label='model')
  plt.plot(faxis_fine, 10*np.log10(Sxx_golden), label='golden', linestyle='--')
  plt.title("OSPFB Architecture Simulation")
  plt.xlabel("Frequency")
  plt.ylabel("Power (arb units dB)")
  plt.legend()
  plt.grid()
  plt.show()


def pltOSPFBChannels(n,r,c, spectrum, hsov, fs, pruned=True):
  """
  n, r, c: total number of subplots (numebr of polyphase channels to plot),
           number of rows in subplot, num. of columns in subplots.

  spectrum: M x NFFT_FINE channels where M is the number of branches (coarse
            channels) in the first stage OSPFB.
            This can be a subset of an OSPFB with many coarse channels that
            needs to be split across multiple plt windows

  hsov:     Half-sided overlap - the number of channels to be discared from each
            coarse channel band edge

  fs:       coarse channel bandwidth

  pruned:   should plot pruned spectrum
  """
  if n is not r*c:
    print("rows and columns do not meet number of channels to plot")
    return None

  NFFT_FINE = spectrum.shape[1]
  df = fs/NFFT_FINE

  fig, ax = plt.subplots(r,c, sharey='row')
  for i in range(0,r):
    for j in range(0,c):
      k = (i*8)+j # ... 8... what is this magic number... plt/row right? so, c?
      # In both cases:
      # NFFT//2 corrects for being a shifted complex basebanded signal
      # the hsov corrects for overlap between adjacent channels
      # TODO: make sure the not pruned faxis actually wraps around to show
      # frequency overlap between adjacent channels
      if not pruned:
        bin_shift = - ((NFFT_FINE//2) + k*2*hsov)
        subbins = np.arange(k*NFFT_FINE, (k+1)*NFFT_FINE) + bin_shift
        data = spectrum[k, :]
      else:
        subbins = np.arange((k-1/2)*(NFFT_FINE-2*hsov),(k+1/2)*(NFFT_FINE-2*hsov))
        data = spectrum[k, (hsov-1):-(hsov+1)]

      faxis = subbins*df
      cur_ax = ax[i,j]
      cur_ax.plot(faxis, 20*log10(abs(data)))
      cur_ax.set_xlim(min(faxis), max(faxis))
      cur_ax.grid(True)
  plt.show()


