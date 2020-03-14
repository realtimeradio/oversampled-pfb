import numpy as np
from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)

  # TODO: The phase compensation operation was not written using the SFG
  # formulation as was the polyphase FIR. As such there is no PE definition and
  # there isn't any other data/valid buffers. At this I am wanting to know what
  # I should add... I am thinking of just implementing the data and valid
  # buffers out of consistency.

  # in ospfb the class that contains all the buffers is called the PE and then
  # the OSPFB class steps through each PE and the step function operates on all
  # the PEs. Should I rename and change the approach?

  # Also, do we really need a valid buffer? For sure we do not need it in the
  # same way we do for the polyphase FIR because after the latency of the FIR
  # then every sample will be valid. In addition the data are not needed becuase
  # when we get to hooking this up to the FFT there is no where in the Xilinx
  # FFT to do something with the data.
class PhaseComp:
  """
  Phase compensation operation for the oversampled polyphase FIR

  This operation is necessary to compensate for the oversampling done by the
  polyphase FIR and align the samples correctly with the expected phase of the
  kernel for the M-Pt FFT
  """

  def __init__(self, M=8, D=6, dt='str', keepHistory=False):
    # container data type
    self.dt = dt

    # OS PFB Parameters
    # The number of of shift states is the numerator of the oversampling ratio
    # which is the reduced form of M/D
    self.M = M
    self.D = D
    self.S = M//np.gcd(self.M, self.D) 
    self.shifts = [s*D % M for s in range(0, self.S)]
    self.stateIdx = 0

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

    # sout "sum out" is left over from the PFB need to think about how the
    # variable name should change here. But for now keeping sout to be the
    # output of the operation just to be consistent.
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
    self.top = 0
    self.bottom = 0
    self.full = False
    self.empty = True
    # don't need the +1 because the wrap around helps
    self.length = length # +1 potentially need to add a dummy space to help at top

    self.buf = np.full(length, TYPES_INIT[dt], dtype=TYPES_MAP[dt])
    #self.buf = np.zeros(length, self.dt)
    # will need a generic empty data generator depending on the data type so
    # that switching between symbolic and numeric modes works
    #self.buf = ["-" for i in range(0, self.length)]

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
  srcint = source(init=M, dt='int', srctype='counter')
  pcint = PhaseComp(M=M, D=D, dt='int')

  # create string symbolic objects and run simulation
  src = source(init=M)
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

