import numpy as np
from source import CounterSource, SymSource
from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)

  # TODO: phase compensation not developed using SFG methodology. Not sure there
  # is any benefit to doing it, but if the approach were to yield PEs it may
  # provide for a more concise straight forward implementation.

  # TODO: For numeric simulations valid/data rotation buffers are not needed
  # data buffers may be nice for other commensual on FPGA modes (correlator/raw voltage)

class PhaseComp:
  """
  Phase compensation operation for the oversampled polyphase FIR

  This operation is necessary to compensate for the oversampling done by the
  polyphase FIR and align the samples correctly with the expected phase of the
  kernel for the M-Pt FFT
  """

  def __init__(self, M=8, D=6, dt='str', initPhaseRot=True, keepHistory=False):
    """
      TODO: extend initPhaseRot to accept valid arbitray initial rotation state and
      effective read/write commutated port.

      TODO: initPhaseRot currently breaks symbolic simulations

      initPhaseRot : Bool - The input/output of the phase compensation buffer is modeled
      as a commutator of the input ports of a parallel structure to realize the decimation
      operation. In general decimators can start at arbitrary sample index. This parameter
      would provide control to allow for starting at a valid shift state index and port pair.

        True - initialize phase to be compatible with the conventional causal
        ospfb starting decimator phase. This is port zero. Symbolically the first sample
        is x0 and every other sample in the ospfb is anti-causal and so therefore the next
        step rolls us over into port M-1 of the next phase state

        False - give no initialization, everything defaults to zero (state index, stkA and
        stkB address pointers) effectively starting with zero shift offset and writing/reading
        port M-1/0 down/up to 0/M-1. (The phasecomp job is to take outputs from the polyphase
        fir ports from processing order M-1 down to zero to natural order 0 to M-1 for the FFT
        expecting natural ordered input. So the input is from M-1 to 0 and the output is the
        other way around 0 to M-1, hence the / notation).
    """
    # container data type
    self.dt = dt

    # OS PFB Parameters
    # The number of of shift states is the numerator of the oversampling ratio
    # which is the reduced form of M/D
    self.M = M
    self.D = D
    self.S = M//np.gcd(self.M, self.D)
    #WHY?!?!?!?! This bit me once before in HLS, but why??? Why does it need
    # to be ascending???? Doesn't the equation in the Tuthill paper do
    # differently? Do I not understand the right shift direction???
    # To add some more information, the shift direction is also affected by how
    # the data are filling into the memory. If we are doing processing order the correct
    # output is read out of the bottom of the memory.
    self.shifts = [-(s*D) % M for s in range(0, self.S)] # correct
    #self.shifts = [(s*D) % M for s in range(0, self.S)]  # developed (notes are written with this case and they sink only may work with this)

    # ping pong buffer
    # TODO: how long does the data/valid buffers need to be? M sounds about
    # right because there is an M latency before the buffer is first filled and
    # after that
    self.pp = ppbuf(length=self.M, dt=dt)
    self.databuf = ppbuf(length=self.M, dt=dt)
    self.validbuf = ppbuf(length=self.M, dt='bool')

    # meta data
    self.modCounter = 0
    self.cycle = 0

    # Initialize phase of the stack
    # TODO: would be better include something to ppbuf constructor
    if not initPhaseRot:
      self.stateIdx = 0
    else:
      self.stateIdx = self.S-1

      # The choice to setA first here is arbitrary, just wanted to have it match
      # the initalize to zero state after the first step when first debugging this

      # ppbuf
      # stack A to have one sample loaded
      self.pp.setA = True
      self.pp.stkA.top = self.M-1
      self.pp.stkA.bottom = 0
      self.pp.stkA.empty = False

      # stack B to get one sample read
      self.pp.stkB.bottom = self.shifts[self.stateIdx]
      self.pp.stkB.top = self.pp.stkB.bottom+1
      self.pp.stkB.empty = False

      # databuf
      # stack A to have one sample loaded
      self.pp.setA = True
      self.pp.stkA.top = self.M-1
      self.pp.stkA.bottom = 0
      self.pp.stkA.empty = False

      # stack B to get one sample read
      self.pp.stkB.bottom = self.shifts[self.stateIdx]
      self.pp.stkB.top = self.pp.stkB.bottom+1
      self.pp.stkB.empty = False

      # validbuf
      # stack A to have one sample loaded
      self.pp.setA = True
      self.pp.stkA.top = self.M-1
      self.pp.stkA.bottom = 0
      self.pp.stkA.empty = False

      # stack B to get one sample read
      self.pp.stkB.bottom = self.shifts[self.stateIdx]
      self.pp.stkB.top = self.pp.stkB.bottom+1
      self.pp.stkB.empty = False

    #self.keepHistory = keepHistory
    #self.sumhist = None
    #self.dbhist = None
    #self.validhist = None

  def step(self, din, sin, vin):
    """
    Single cycle transaction of the phase compensation operation

    When the ping pong buffer is full the correct rotation is applied on the
    cycle as being filled to correctly read the samples out of the buffer in
    the correct order.
    """

    # TODO: sout "sum out" is left over from the PFB need to think about how the
    # variable name should change here. But for now keeping sout to be the output
    # of the operation just to be consistent.
    sout = TYPES_INIT[self.dt]
    dout = TYPES_INIT[self.dt]
    vout = TYPES_INIT['bool']

    sout = self.pp.step(sin)# the sums are what we really want phase rotated
    dout = self.databuf.step(din)
    vout = self.validbuf.step(vin)

    # Is the seperate class really the structure I want to pursue?
    # What I am worried about is imposing too many step-by-step assumptions that
    # is not fit for hardware development.

    # Because without too much planning, the idea is that the phase roation hdl
    # implementation would be a state machine and the combinational logic in
    # that seems to match more the previous implementation when it was one
    # combined class.
    if self.pp.full():
      self.modCounter += 1
      if self.pp.setA:
        self.pp.stkB.top = self.shifts[self.stateIdx]
        self.pp.stkB.bottom = self.shifts[self.stateIdx]

        self.databuf.stkB.top = self.shifts[self.stateIdx]
        self.databuf.stkB.bottom = self.shifts[self.stateIdx]

        self.validbuf.stkB.top = self.shifts[self.stateIdx]
        self.validbuf.stkB.bottom = self.shifts[self.stateIdx]

        self.stateIdx = (self.stateIdx+1) % self.S
      else:
        self.pp.stkA.top = self.shifts[self.stateIdx]
        self.pp.stkA.bottom = self.shifts[self.stateIdx]

        self.databuf.stkA.top = self.shifts[self.stateIdx]
        self.databuf.stkA.bottom = self.shifts[self.stateIdx]

        self.validbuf.stkA.top = self.shifts[self.stateIdx]
        self.validbuf.stkA.bottom = self.shifts[self.stateIdx]

        self.stateIdx = (self.stateIdx+1) % self.S

    self.cycle += 1

    #if self.keepHistory:
    #  self.updateHistory()

    return (dout, sout, vout)

    # sout is the rotation out that used to be dout but renamed to
    # be consistent with the OSPFB implementation
    #return dout

  ## TODO: should the history functions be in phase comp or ppbuf?
  #def updateHistory(self):
  #  a = np.reshape(self.pp.stkA.buf, (self.M,1))
  #  b = np.reshape(self.pp.stkB.buf, (self.M,1))
  #  ab = np.concatenate((a,b), axis=1)

  #  if self.sumhist is None:
  #    self.sumhist = ab
  #  else:
  #    self.sumhist = np.concatenate((self.sumhist,ab), axis=1)

  #  #if self.dbhist is None:

  #  #else:

  #  #if self.validhist is None:

  #  #else:

  #def formatHistory(self,  dbfmt, sumfmt, validfmt):
  #  if self.sumhist is None:
  #    print("No history has been accumulated... returning...")
  #    return ""

  #  strhist = ""

  #  for i in range(0, self.M): # stack A and B put together
  #    for j in range(0, self.cycle):
  #      for k in range(0, 2):
  #        kid = 2*j + k
  #        strhist += sumfmt.format(self.sumhist[i,kid])

  #  return strhist

  def print(self):
    s = ""
    s += "Rotation pp buf:\n"
    s += "{}\n".format(self.pp)
    s += "Data pp buf:\n"
    s += "{}\n".format(self.databuf)
    s += "Valid pp buf:\n"
    s += "{}\n".format(self.validbuf)

    return s

  def __repr__(self):
    return self.print()


class ppbuf:
  """
  A generic ping pong buffer data structure implementation
  """
  def __init__(self, length=8, dt='str'):
    self.length = length

    # ping pong buffer control
    self.setA = False
    self.stkA = stack(length=length, dt=dt)
    self.stkB = stack(length=length, dt=dt)

    self.cycle = 0

  def full(self):
    """
    The ping pong buffer is considered full when of the writing buffer is full
    and the reading buffer is empty.
    """
    return (self.stkA.full and self.stkB.empty) \
            or (self.stkA.empty and self.stkB.full)

  def step(self, din):
    """
    A single cycle transaction of the ping pong buffer. A sample is written in
    and a sample is read out.
    """

    dout = "-"

    if self.setA:
      self.stkA.write(din)
      dout = self.stkB.read()

      if self.stkA.full:
        # next M cycles will load B and read out from A
        # set A to read from the next phase roation state on the next iteration
        self.setA = False

        # prepare the B stack to be loaded
        self.stkB.top = 0
        self.stkB.bottom = 0
    else:
      self.stkB.write(din)
      dout = self.stkA.read()

      if self.stkB.full:
        # next M cycles will load A and read out from B
        # set A to read from the next phase roation state on the next iteration
        self.setA = True
        self.stkA.top = 0
        self.stkA.bottom = 0

    self.cycle += 1
    return dout

  def __repr__(self):
    return self.print()

  def print(self):
    s = ""
    s += "setA: {}\n".format(self.setA)
    s += "A: {}\n".format(self.stkA)
    s += "B: {}\n".format(self.stkB)
    return s


class stack:
  """
  Stack data structure
  """
  def __init__(self, length=8, dt='str'):
    self.dt = dt
    self.top = 0
    self.bottom = 0
    self.full = False
    self.empty = True
    # don't need the +1 because the wrap around helps
    self.length = length # +1 potentially need to add a dummy space (address) to help at top in HDL

    self.buf = np.full(length, TYPES_INIT[dt], dtype=TYPES_MAP[dt])

  def reset(self):
    self.buf = np.full(self.length, TYPES_INIT[self.dt], dtype=TYPES_MAP[self.dt])
    self.full = False
    self.empty = True

  def read(self):
    """
    Read a value from the stack
    """
 
    if (self.full):
      self.full = False

    if (self.empty):
      res = self.buf[self.top]
    else:
      self.top = (self.top-1) % self.length
      res = self.buf[self.top]
      if (self.top==self.bottom):
        self.empty = True
    
    return res

  def write(self, din):
    """
    Insert a value onto the stack
    """

    if (self.full):
      print("Error: the stack is full... not writing")
      return

    if (self.empty):
      self.empty = False

    res = (self.top, din)
    self.buf[self.top] = din
    # the mod wrap around is to have an extra space and used to indicate when
    # full and empty. Works because the bottom is never used to access elements.
    self.top = (self.top+1) % self.length
    if (self.top == self.bottom):
      self.full = True

    return res

  def __repr__(self):
    return self.print()

  def print(self):
    s = "top: {} bottom: {} full: {}, empty:{}".format(self.top, self.bottom,
                                                      self.full, self.empty)
    s += "\n{}".format(self.buf)
    return s


if __name__ == "__main__":
  print("OSPFB phase compensation implementation")
  # OS PFB simulation parameters
  M = 8
  D = 6

  # examples creating containers of different types
  ppstr = ppbuf(length=M, dt='str')
  ppint16 = ppbuf(length=M, dt='int16')
  srcint = CounterSource(M=M)
  pcint = PhaseComp(M=M, D=D, dt='int')

  # create string symbolic objects and run simulation
  src = SymSource(M=M, order="processing")
  pc = PhaseComp(M=M, D=D)
  fftin = []

  while pc.modCounter < 12:
    nextsamp = src.genSample()

    if pc.pp.full():
      print("**********************************************************************")
      print("FFT Input: ", fftin)
      print("**********************************************************************\n")
      fftin = []

    out = pc.step(nextsamp, nextsamp, True)
    fftin.append(out)

