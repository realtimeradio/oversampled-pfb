import numpy as np
from ospfb import ringbuffer


class ppbuf:
  def __init__(self, M=8, D=6):
    """
    A ping pong buffer implementing the phase rotation behavior between the
    polyphase FIR and M-PT FFT in the oversampled PFB.

    While this class if called ppbuf (ping pong buffer) it really is the fully
    phase rotation implementation. In otherwords it combines both functionality the
    implementation of the ping pong data structure and applying the phase rotation
    on that buffer
    """

    # OS PFB parameters

    # The number of of shift states is the numerator of the oversampling ratio
    # which is the reduced form of M/D
    self.M = M
    self.D = D
    self.S = M//np.gcd(self.M, self.D)
    self.shifts = [s*D % M for s in range(0, self.S)]
    self.stateIdx = 0

    # ping pong buffer control
    self.setA = False
    self.stkA = stack(length=self.M)
    self.stkB = stack(length=self.M)

    # meta data
    self.cycle = 0
    self.modCounter = 0

  def step(self, din):
    """
    A single cycle transaction of the phase compensation operation
    """

    dout = "-"

    if self.setA:
      self.stkA.write(din)
      dout = self.stkB.read()

      if self.stkA.full:
        self.modCounter +=1
        # next M cycles will load B and read out from A
        # set A to read from the next phase roation state on the next iteration
        self.setA = False
        self.stkA.top= self.shifts[self.stateIdx]
        self.stkA.bottom = self.shifts[self.stateIdx]
        self.stateIdx = (self.stateIdx+1) % self.S

        # prepare the B stack to be loaded
        self.stkB.top = 0
        self.stkB.bottom = 0
    else:
      self.stkB.write(din)
      dout = self.stkA.read()

      if self.stkB.full:
        self.modCounter +=1
        # next M cycles will load A and read out from B
        # set B to read from the next phase roation state on the next iteration
        self.setA = True
        self.stkA.top = 0
        self.stkA.bottom = 0

        self.stkB.top = self.shifts[self.stateIdx]
        self.stkB.bottom = self.shifts[self.stateIdx]
        self.stateIdx = (self.stateIdx+1) % self.S

    self.cycle += 1
    return dout

class stack:
  # max representable is a 128 long string per buffer element
  dt = np.dtype((np.unicode_, 128))

  def __init__(self, length=8):
    self.top = 0
    self.bottom = 0
    self.full = False
    self.empty = True
    # don't need the +1 because the wrap around helps
    self.length = length # +1 potentially need to  add a dummy space to help at top

    self.buf = np.zeros(length, self.dt)
    # will need a generic empty data generator depending on the data type so
    # that switching between symbolic and numeric modes works
    self.buf = ["-" for i in range(0, self.length)]

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
    # full and empty. Works because the bottom is never used to access elements
    # and we have a power of 2 buffer size. 
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


class source:
  def __init__(self, init=8): # general M
    self.M = init
    self.curval = init-1 # general M-1
    # decimated time index? will have to change something to get it to start at
    # zero
    self.i = 1
    self.modtimer = 0

  def genSample(self):

    val = self.i*M - self.modtimer - 1
    self.modtimer = (self.modtimer+1) % self.M
    self.i = self.i+1 if self.modtimer == 0 else self.i

    return "x{}".format(val)
  

if __name__ == "__main__":
  print("ping pong buffer impl")

  M = 8
  D = 6
  Nstates = M//np.gcd(M,D)

  rotState = [n*D % M for n in range(0,Nstates)]
  stateIdx = 0
  print(rotState)

  stk = stack(length=M)
  src = source(init=M)
  pp = ppbuf(M=M, D=D)

  fftin = []
  while pp.modCounter < 12:
    nextsamp = src.genSample()

    if (pp.stkA.full and pp.stkB.empty) or (pp.stkB.full and pp.stkA.empty):
      print("**********************************************************************")
      print("FFT Input: ", fftin)
      print("**********************************************************************\n")
      fftin = []

    out = pp.step(nextsamp)
    fftin.append(out)

