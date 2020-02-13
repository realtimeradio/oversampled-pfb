import numpy as np
from ospfb import ringbuffer

class ppbuf:
  def __init__(self, length=8): # general M

    self.length = length
    self.setA = False

    self.stkA = stack(length=length)
    self.stkB = stack(length=length)


  def step(self, din, dout):
    pass

class stack:
  # max representable is a 128 long string per buffer element
  dt = np.dtype((np.unicode_, 128))

  def __init__(self, length=8):
    self.top = 0
    self.bottom = 0
    self.full = False
    self.empty = True
    # don't need the negative 1 because the wrap around helps
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

  pp = ppbuf(length=M)
  clearIn = False
  fftin = []
  while src.i < 12:
    nextsamp = src.genSample()
    out = "-"

    if clearIn:
      print("**********************************************************************")
      print("FFT Input: ", fftin)
      print("**********************************************************************\n")
      fftin = []
      clearIn = False

    # Note that the control does not count cycles and mod on the transform
    # length M. Instead this is built into full/empty flag and instead control
    # monitors this. When the setting buffer is full it is marked for getting to
    # begin on the next cycle and vice versa.
    if pp.setA:
      pp.stkA.write(nextsamp)
      out = pp.stkB.read()

      if pp.stkA.full:
        clearIn = True
        # next M cycles will load B and read out from A
        # set A to read from the next phase roation state on the next iteration
        pp.setA = False
        pp.stkA.top= rotState[stateIdx]
        pp.stkA.bottom = rotState[stateIdx]
        stateIdx = (stateIdx+1) % Nstates

        # prepare the B stack to be loaded
        pp.stkB.top = 0
        pp.stkB.bottom = 0
    else:
      pp.stkB.write(nextsamp)
      out = pp.stkA.read()

      if pp.stkB.full:
        clearIn = True
        pp.setA = True
        pp.stkA.top = 0
        pp.stkA.bottom = 0

        pp.stkB.top = rotState[stateIdx]
        pp.stkB.bottom = rotState[stateIdx]
        stateIdx = (stateIdx+1) % Nstates

    fftin.append(out)

 # it looks like I have the stack programmed correctly. Then shifting the top
 # and bottom to the same values in the shift state pattern works. I tried
 # making use of the ending spot of the read out of the stack but it doesn't
 # look like the rotation pattern deceases how I would like. So while the
 # original way works the hope is that it will be acceptable for hdl design and
 # not inquire additional latency. 
