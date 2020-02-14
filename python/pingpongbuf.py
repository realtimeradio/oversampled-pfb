import numpy as np
from ospfb import ringbuffer

TYPES = (str, 'int16', 'int32', int, float)

TYPES_MAP = {
  'str'   : np.dtype((np.unicode_, 128)), # max representable is a 128 long string per buffer element
  'int16' : np.int16,
  'int32' : np.int32,
  'int'   : int,
  'float' : float
}

TYPES_INIT = {
  'str'   : '-',
  'int16' : 0,
  'int32' : 0,
  'int'   : 0,
  'float' : 0.0
}

class phaseComp:
  """
  Phase compensation operation for the oversampled polyphase FIR

  This operation is necessary to compensate for the oversampling done by the
  polyphase FIR and align the samples correctly with the expected phase of the
  kernel for the M-Pt FFT
  """

  def __init__(self, M=8, D=6, dt='str'):
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
    self.pp = ppbuf(length=self.M, dt=dt)

    # meta data
    self.modCounter = 0
    self.cycle = 0

  def step(self, din):
    """
    Single cycle transaction of the phase compensation operation

    When the ping pong buffer is full the correct rotation is applied on the
    cycle as being filled to correctly read the samples out of the buffer in
    the correct order.
    """

    dout = TYPES_INIT[self.dt]

    dout = self.pp.step(din)

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
        self.stateIdx = (self.stateIdx+1) % self.S
      else:
        self.pp.stkA.top = self.shifts[self.stateIdx]
        self.pp.stkA.bottom = self.shifts[self.stateIdx]
        self.stateIdx = (self.stateIdx+1) % self.S

    self.cycle += 1
    return dout


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
    self.length = length # +1 potentially need to  add a dummy space to help at top

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

# I know I want a simulation source but I am not sure I am liking exactly how
# this one is turning out. It should work for now, but it should be more object
# oriented and inhert base and then just implement genSample or something like
# that.
class source:
  """
  Simulation source for generating samples
  """
  def __init__(self, init=8, dt='str', srctype=None): # general M
    self.dt = dt
    self.srctype = srctype
    self.M = init
    self.curval = init-1 # general M-1
    # decimated time index? will have to change something to get it to start at
    # zero
    self.i = 1
    self.modtimer = 0

    if self.dt is not 'str' and self.srctype is None:
      print("Error: A numeric datatype is expected to have a srctype")
      print("Error: Not exiting, but things will break...")

  def genSample(self):

    dout = None
    # working on other source value generation
    if self.dt == 'str':
      # samples are generated newest to oldest as they would be out of the
      # polyphase FIR branches (port M-1 up to port 0)
      val = self.i*M - self.modtimer - 1
      dout = "x{}".format(val)
    else:
      if self.srctype == 'counter':
        dout = (self.i-1)*M + self.modtimer
        # apply the following for a counter that would count like the string
        # version above (newest to oldest samples)
        #dout = self.i*M - self.modtimer - 1
      elif self.srctype == 'sine':
        # TODO: need to implement -- include noise
        dout = 1

    # update meta data on number of cycles ran
    self.modtimer = (self.modtimer+1) % self.M
    self.i = self.i+1 if self.modtimer == 0 else self.i 

    return dout
  

if __name__ == "__main__":
  print("OSPFB phase compensation implementation")
  # OS PFB simulation parameters
  M = 8
  D = 6

  # examples creating containers of different types
  ppstr = ppbuf(length=M, dt='str')
  ppint16 = ppbuf(length=M, dt='int16')
  srcint = source(init=M, dt='int', srctype='counter')
  pcint = phaseComp(M=M, D=D, dt='int')

  # create string symbolic objects and run simulation
  src = source(init=M)
  pc = phaseComp(M=M, D=D)
  fftin = []

  while pc.modCounter < 12:
    nextsamp = src.genSample()

    if pc.pp.full():
      print("**********************************************************************")
      print("FFT Input: ", fftin)
      print("**********************************************************************\n")
      fftin = []

    out = pc.step(nextsamp)
    fftin.append(out)

