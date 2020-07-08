import numpy as np

from utils import (TYPES, TYPES_MAP)

class Taps(object):

  @classmethod
  def genTaps(cls, M, P, D):
    h = cls.__createTaps__(M, P, D)

    return h

  @staticmethod
  def __createTaps__(M, P, D):
    pass

# TODO: not really liking the whole _name_Taps construct. It seems this would be better
# if the working interface was to call Taps.CyclicRamp, Taps.SymTaps, etc.
class CyclicRampTaps(Taps):
  """
    Generate a ramp of coeff of type np.int16 from 0 to M-1 in each PE
  """
  @staticmethod
  def __createTaps__(M, P, D):
    h = np.array(P*[i for i in range(0, M)], dtype=np.int16)
    return h


class RampTaps(Taps):
  """
    Generate a ramp of coeff of type np.int16 from 0 to M*P-1. The taps are distributed
    across PEs by steps of M
  """
  @staticmethod
  def __createTaps(M, P, D):
    L = M*P
    h = np.arange(0, L, dtype=np.int16)
    return h

class SymTaps(Taps):
  @staticmethod
  def __createTaps__(M, P, D):
    L = M*P
    h = np.array(['h{}'.format(i) for i in range(0, L)], dtype=TYPES_MAP['str'])
    return h


# TODO: osratio... how to seed ospfb design info... maybe static/classmethods are not really
# what I want because to make this work I now have D that I only use in one class and not all of them
# instead still want to work with a base instance 
class HannWin(Taps):
  @staticmethod
  def __createTaps__(M, P, D):
    osratio = float(M)/float(D)
    L = M*P
    tmpid = np.arange(-P/2*osratio, osratio*P/2, 1/D)
    tmpx = np.sinc(tmpid)
    hann = np.hanning(L)
    # TODO: give h its numpy dtype
    h = tmpx*hann
    return h

