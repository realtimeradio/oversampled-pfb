import sys
import numpy as np

from utils import (TYPES, TYPES_MAP, TYPES_INIT, TYPES_STR_FMT)
from phasecomp import (PhaseComp, stack)
from source import (ToneSource, SymSource)
from goldenmodel import golden

def minTuple(t):
  m = (0,0)
  if (t[0] < m[0]):
    m = t
  return m

def maxTuple(t):
  m = (0,0)
  if (t[0] > m[0]):
    m = t
  return m


class OSPFB:
  """
    Implementation of SFG OS PFB architecture to demonstrate functionality of
    the design methodolgy.
  """

  def __init__(self, M, D, P, initval, dt='str', followHistory=False):
    """
      M - Polyphase branches (Transform size)

      P - Taps per polyphase branch For this architecture this is also the number
          of PEs used

      D - Decimation rate

      initval - starting symbolic sample index (e.g., -11 for 'x-11', or 0 for 'x0'

      When using values other than '0' three changes must be made to correctly
      operate the OSPFB.

      ospfb.modtimer - needs to be changed such that correct true and false
      values are created at the right time.

      pe.taps.head and .tail - needs to be changed to the correct starting
      position to make sure the correct coefficient is being applied.

      res (short for "result", nothing special) - the second tuple element needs
      to be changed setting up the start of the pattern for correclty determining
      the added latency.

      when the init value was 1 and the startbranch algorithm soliving for (n,m)
      was finding the earliest n using minTuple
      ospfb.modtimer = 0
      pe.taps.head = M-D
      pe.taps.tail = M-D

      res = (0, M-1)

      when the init value is 1 and the startbranch algorithm is solving for
      (n,m) finding the latest n the parameters above are the same except

      res = (0, M-D)

      with init value of 0 and the startbranch algorithm solving for (n,m)
      finding the latest n using maxTuple
      ospfb.modtimer = D-1
      pe.taps.head = M-1
      pe.taps.tail = M-1

      res = (0, 0)

      For more information continue to read:

      In the design methodology to produce the DG and SFG time indices are part
      of the process to show data dependencies. During the derivation I had used
      actual index values (-11, -10, -9...) instead of relative indices (n-2, n-1,
      n, n+1...). This was partly because deriving the accurate SFG would have
      required multiple projections and I had not completely understood how that
      would work with this DG because of the irregular structure. Instead I used
      re-timing techniques to slow the circuit and then interleave the different
      branch calculations. For the critically sampled PFB I knew that the way to
      think about the block diagram is to start delivering the samples at port M-1
      and subsequently until port 0. Formulating the systolic architecture was
      a matter of slowing the circuit down by a factor of M and placing the
      branches in the holes starting at M-1 and subsequently down to port 0.

      However in the oversampled case the approach to interleave the branches by
      placing them in the holes created by the slow down of a factor of M didn't work
      exactly in the same fashion. See my hand drawn notes and figures for the
      differences. I believe that interleaving didn't work because the PEs after the
      first projection are not homogeneous (different PEs required different behaviour
      -- this is seen with the PE that crosses between DG layers). Keeping numeric values
      instead of relative values was helpful to tweeze the correct functionality out
      of interleaving the branches. So I was using the equation and absolute numbers
      to make sure the timing lined up correctly. Relying on the OS pattern and that I
      knew the modification to the CS PFB to make the OS PFB was to begin delivering
      samples at port D-1. So in my hand written derivation I had chosen -11 but
      figured it would work for any arbitrary value as long as the correct value was
      being delivered to the correct port, multiplied by the right tap and that the
      correct control was implemented to mark the input as when no samples are to be
      delivered.

      While this is a Polyphase FIR and it doesn't really make sense to talk about
      initial samples other than '0' it has been helpful to make the initial
      value arbitrary as it has helped investigate and understand further the
      behaviour of this architecture that cannot be easily understood from the
      hand drawn case. This is because it has shown how the mod pattern between
      the transform size (M) and the decimation rate (D) contribute to the
      latency of the design as PEs are added. This is because as the initial value
      changes (as mentioned earlier) the modtimer determining 'True' and 'False'
      values and the correct filter tap must be selected on the input. But, also
      that to get the exact latency depends on which port we start delivering
      samples to and how the mod patter begins. This is the second modulo
      reminder of the 'res' variable in the atencyComp method. Which in the
      Polyphase FIR interpolator explanation by f.j. Harris indicates which port
      the output sample is pulled from. This isn't the exact same here but I am
      working on figuring that out.

    """
    # containers data type
    self.dt = dt

    # os pfb parameters
    self.M = M
    self.D = D
    self.P = P
    self.L = P*M
    self.osratio = float(M)/float(D)
    self.iterval = initval
    self.followHistory = followHistory

    self.modtimer = D-1
    self.cycle = 0
    self.run = False

    # TODO: allow for tap initialization
    # initialize prototype LPF
    if self.dt == "str":
      h = ['h{}'.format(i) for i in range(0, self.L)]
    else:
      tmpid = np.arange(-self.P/2*self.osratio, self.osratio*self.P/2, 1/self.D)
      tmpx = np.sinc(tmpid)
      hann = np.hanning(self.L)
      h = tmpx*hann

    self.taps = h

    # initialize PEs elements
    self.PEs = [pe(idx=1, M=M, D=D,
                    taps=self.taps[M-1::-1],
                    dt=dt,
                    keepHistory=self.followHistory)]

    self.PEs += [pe(idx=i, M=M, D=D,
                     taps=self.taps[i*M-1:(i-1)*M-1:-1],
                     dt=dt,
                     keepHistory = self.followHistory) \
                 for i in range(2, (P+1))]

    # initialize phase compensation block
    self.pc = PhaseComp(M=self.M, D=self.D,
                        dt=dt,
                        keepHistory=self.followHistory)

    self.strfmt = "T={{{:s}}} in:({{{:s}}}, {{}}), out:({{{:s}}}, {{{:s}}}, {{}})"
    self.strfmt = self.strfmt.format(":<3d", TYPES_STR_FMT[self.dt], TYPES_STR_FMT[self.dt], TYPES_STR_FMT[self.dt])

  def enable(self):
    self.run = (not self.run)
    print("PFB is {}".format("running" if self.run else "stopped"))


  def step(self, din):
    if not self.run:
      print("PFB not enabled...returning")
      return

    vnext = self.valid()
    if vnext==False:
      if self.dt=='str':
        dnext = "*"
      else:
        dnext = -1
    else:
      dnext = din

    self.cycle += 1
    self.modtimer = (self.modtimer+1) % self.M
    peout, firout = self.runPEs(dnext, vnext)

    print(self.strfmt.format(self.cycle, dnext, vnext, peout[0], peout[1], peout[2]))

    return (peout, firout)

  def runPEs(self, din, vin):
    # empty tuple as a reference it is tuple out format is (dout, sout, vout)
    peout = ()
    for (i, pe) in enumerate(self.PEs):
      if i==0:
        # The first PE has a default zero value on the sum in line
        peout = pe.step(din, TYPES_INIT[self.dt], vin)
      else:
        peout = pe.step(peout[0], peout[1], peout[2])

    firout = peout[1]
    # the last output of the PE is then input to the phase compensation prior to
    # the FFT
    # TODO: enable calculation should be replaced with a valid signal. Currently
    # the valid buffers are length 2*M but I am getting a little more convinced
    # that it should be M. See notes.
    en = self.M*(self.P-1)+2
    if (self.cycle) >= en:
      peout = self.pc.step(peout[0], peout[1], peout[2])
    return (peout, firout)

  def valid(self):
    return True if self.modtimer < self.D else False

  def getHistory(self, dumpf=False):
    strhist = ""
    # only need to increase the databuf and delaybuf large cycle counts

    # field width of 5 for when need negative inputs 3 when positive
    dbfmt = "{{{:s}}}".format(":<5s")
    validfmt = "{{{:s}}}".format(":<2s")
    # field width of 5 for when need negative inputs 3 when positive
    delayfmt = "{{{:s}}}".format(":<5s")
    # 9 for the 6 pe char and 3 for the ' + ' connecting sum values beetween pe
    sumfmt = "{{:<{:d}s}}".format((self.P-1)*9+6)
    for i in range(self.P-1, -1, -1):
      pe = self.PEs[i]
      #sumfmt = "{{:>{:d}s}}".format(i*9+6) #iter over pe if different lengths needed
      strhist += pe.formatHistory(dbfmt, sumfmt, delayfmt, validfmt)
      strhist += "\n\n"

    if dumpf:
      fp = open("history.txt", 'w')
      fp.write(strhist)
      fp.close()

    return strhist

  def print(self):
    s = ""
    for (i, pe) in enumerate(self.PEs):
      s += "PE {}\n".format(i)
      s += "-"*40 # add a line of '-'
      s += "\n"
      s += "{}\n".format(pe)

    return s

  def __repr__(self):
    return self.print()


class pe:
  def __init__(self, idx, M, D, taps, dt='str', keepHistory=False):
    self.idx = idx 
    self.M = M
    self.D = D
    self.taps = None
    self.keepHistory = keepHistory
    self.sumbuf   = ringbuffer(length=M, dt=dt)
    self.delaybuf = ringbuffer(length=(M-D), dt=dt)
    self.databuf  = ringbuffer(length=2*M, dt=dt)
    self.validbuf = ringbuffer(length=2*M, load=["False" for i in range(0,2*M)], dt=dt)

    self.cycle = 0

    self.sumhist   = None
    self.dbhist    = None
    self.delayhist = None
    self.validhist = None

    # containers data type
    self.dt = dt

    if len(taps) != M: 
      print("PE: Init error number of taps not correct")
    else:
      self.taps = ringbuffer(length=M, load=taps, dt=dt)
      self.taps.head = M-1
      self.taps.tail = M-1

  def step(self, din, sin, vin):
    # default values
    self.cycle += 1

    d = TYPES_INIT[self.dt]
    vout = TYPES_INIT['bool']
    sout = TYPES_INIT[self.dt]
    dout = TYPES_INIT[self.dt]

######## TESTING NEW CONTROL/DATAFLOW #########
# Re-writing the control this way yields the same
# result as previous control flow
#
#    dbuf = self.delaybuf.buf[self.delaybuf.head] # has to be here since we need the value before it is overwritten
#    if vin==True:
#      d = din
#      if self.delaybuf.full:
#        self.delaybuf.war(din)
#      else:
#        self.delaybuf.write(din)
#    else:
#      d = self.delaybuf.war(self.delaybuf.buf[self.delaybuf.head])
#
#    if self.databuf.full:
#      dout = self.databuf.war(dbuf)
#    else:
#      self.databuf.write(dbuf)
#
#    # write to valid buffer
#    if self.validbuf.full:
#      vout = self.validbuf.war(vin)
#    else:
#      self.validbuf.write(vin)
#
#    # compute sum
#    h = self.taps.war(self.taps.buf[self.taps.head])
#    s = self.MAC(sin, d, h)
#    if self.sumbuf.full:
#      sout = self.sumbuf.war(s)
#    else:
#      self.sumbuf.write(s)
#
############ PREV CONTROL/DATAFLOW #############

    # deterimine if data to use is from in our loopback delay buffer
    if self.delaybuf.full and (vin==True):
      d = self.delaybuf.war(din)
    elif vin==True:
      self.delaybuf.write(din)
    else:
      din = self.delaybuf.buf[self.delaybuf.head]
      d = din
      self.delaybuf.war(self.delaybuf.buf[self.delaybuf.head])

    # write to data buffer
    if self.databuf.full:
      dout = self.databuf.war(d)
    else:
      self.databuf.write(d)

    # write to valid buffer
    if self.validbuf.full:
      vout = self.validbuf.war(vin)
    else:
      self.validbuf.write(vin)

    # compute sum
    h = self.taps.war(self.taps.buf[self.taps.head])
    s = self.MAC(sin, din, h)
    if self.sumbuf.full:
      sout = self.sumbuf.war(s)
    else:
      self.sumbuf.write(s)
############ PREV CONTROL/DATAFLOW #############

    # update symbolic timing history
    if self.keepHistory:
      self.updateHistory()    

    return (dout, sout, vout)

  def MAC(self, sin, din, coeff):

    if self.dt == 'str':
      if sin == "-": # was previously "0" as this is really what is input
        s = ('{}{}').format(coeff, din)
      else:
        s = ('{} + ' + '{}{}').format(sin, coeff, din)
    else:
      s = sin + coeff*din

    return s

  def updateHistory(self):
    """
    create history looking like my hand drawn systolic timing diagrams.

    roll    - buffer by -head so newest is first element oldest is last.
    reshape - to be a column vector
    concat  - column vector to growing history
    """
    
    if self.sumhist is None:
      self.sumhist = np.reshape(np.roll(self.sumbuf.buf,
                                       -self.sumbuf.head),
                                       (self.M,1))
    else:
      self.sumhist = np.concatenate((self.sumhist,
                      np.reshape(np.roll(self.sumbuf.buf,
                                        -self.sumbuf.head),
                                        (self.M,1))),
                                 axis=1)

    if self.dbhist is None:
      self.dbhist = np.reshape(np.roll(self.databuf.buf,
                                      -self.databuf.head),
                              (2*self.M,1))
    else:
      self.dbhist = np.concatenate((self.dbhist,
                      np.reshape(np.roll(self.databuf.buf,
                                        -self.databuf.head),
                                        (2*self.M,1))),
                                 axis=1)

    if self.delayhist is None:
      self.delayhist = np.reshape(np.roll(self.delaybuf.buf,
                                         -self.delaybuf.head),
                                  (self.M-self.D,1))
    else:
      self.delayhist = np.concatenate((self.delayhist,
                      np.reshape(np.roll(self.delaybuf.buf,
                                        -self.delaybuf.head),
                                        (self.M-self.D,1))),
                                 axis=1)

    if self.validhist is None:
      self.validhist = np.reshape(np.roll(self.validbuf.buf,
                                      -self.validbuf.head),
                              (2*self.M,1))
    else:
      self.validhist = np.concatenate((self.validhist,
                      np.reshape(np.roll(self.validbuf.buf,
                                        -self.validbuf.head),
                                        (2*self.M,1))),
                                 axis=1)

  def formatHistory(self, dbfmt, sumfmt, delayfmt, validfmt):

    if self.dbhist is None:
      print("No history has been accumulated... returning...")
      return ""

    strhist = ""

    # outer loop over all databuffer delays (2*M)
    for i in range(0, 2*self.M):
      for j in range(0, self.cycle):
        strhist += dbfmt.format(self.dbhist[i,j])

      # white space between databuf and valid buffer
      strhist += "{:<4s}".format(" ")

      # valid buffer history
      for j in range(0, self.cycle):
        strhist += validfmt.format(self.validhist[i,j][0])
      if i < self.M:
        strhist += "{:<4s}".format(" ")
        for j in range(0, self.cycle):
          strhist += sumfmt.format(self.sumhist[i,j])
      strhist += "\n"
    strhist += "\n"

    # loopback delay buffer
    for i in range(0, self.M-self.D):
      for j in range(0, self.cycle):
        strhist += delayfmt.format(self.delayhist[i,j])

      # white space between delay buffer and valid buffer
      strhist += "{:<4s}".format(" ")

    return strhist

  def __repr__(self):
    return self.print()

  def print(self):
    s = "delay buffer\n{}\n\n"\
        "sum buffer\n{}\n\n"\
        "data buffer\n{}\n\n"\
        "valid buffer\n{}\n\n"\
        "taps\n{}\n".format(self.delaybuf, self.sumbuf, self.databuf,
                          self.validbuf, self.taps)
    return s


class ringbuffer:

  def __init__(self, length=16, load=None, dt='str'):
    self.head = 0
    self.tail = 0
    self.full = False
    self.empty = True
    self.length = length

    self.buf = np.full(length, TYPES_INIT[dt], dtype=TYPES_MAP[dt])

    if load is not None:
      if len(load) == length:
        self.buf = load
        self.full = True
        self.empty = False
      else:
        print("RB: incorrect length of values to load")

  def read(self):
    if (self.full):
      self.full = False

    res = self.buf[self.tail]
    if (not self.empty):
      self.tail = (self.tail+1) % self.length
      if(self.tail == self.head):
        self.empty = True
    return res

  def write(self, din):
    """
      Insert a value into the ring buffer
      Error and do nothing when tail = head
      Return a tuple of the addr and value written
    """
    if (self.full):
      print("Error: overwriting data... not writing")
      return
    else:
      if (self.empty):
        self.empty = False

      self.buf[self.head] = din
      res = (self.head, din)
      self.head = (self.head+1) % self.length
      if (self.head == self.tail):
        #print("Warning buffer is full")
        self.full = True

    return res

  def war(self, din):
    """
      Write after read
    """
    res = self.read()
    wr = self.write(din)
    return res


  def __repr__(self):
    return self.print()

  def print(self):
    s = "head: {} tail: {} full: {}, empty:{}".format(self.head, self.tail,
                                                      self.full, self.empty)
    s += "\n{}".format(self.buf)
    return s

class sink:
  """
  Implements the OS PFB equations producing symbolic outputs for comparison for
  verification
  """

  def __init__(self, M, D, P, init=None, order='reversed'):
    # OS PFB parameters
    self.M = M
    self.P = P
    self.D = D

    # phase rotation compensation states
    self.S = M//np.gcd(self.M, self.D)
    self.shifts = [-(s*D) % M for s in range(0, self.S)]

    # output processing order
    # reversed - processing order (port M-1 down to zero, newest to oldest)
    # natrual  - parallel or natrual order (port 0 to M, oldest to newest)
    self.order = order

    # determine the decimated time sample (n*D) and branch index that the initial
    # value (init) will first appear in the last term (max -- the earliest time
    # would instead use min) of the polyphase sum
    self.init = init
    if self.init is not None:
      ## polyphase fir solution
      #self.l = []
      #self.num = lambda m: (self.init+(self.P-1)*self.M+m)
      #for m in range(0,self.M):
      #  if (self.num(m)%self.D == 0): # (no remainder -- is integer)
      #    self.l.append((int(self.num(m)/self.D), m))

      # phase rotation solution
      self.l = []
      self.num = lambda m: (self.init+(self.P-1)*self.M+m)
      for mprime in range(0,self.M):
        if (self.num(mprime)%self.D == 0): # (no remainder -- is integer)
          n = int(self.num(mprime)/self.D)
          s = int(n % self.S)
          rs = self.shifts[s]
          m = (mprime + rs) % self.M # TODO: verify this solution is true in general...
          print("sol: n={}, mprime={}, s={}, rs={}, m={}".format(n, mprime, s, rs,m))
          self.l.append((n, m))

      #self.startbranch = min(self.l, key=minTuple)
      self.startbranch = max(self.l, key=maxTuple)
      self.n = self.startbranch[0]  # sample time
      self.m = self.startbranch[1]  # branch index
    else:
      self.n = 0
      if order == "reversed":
        self.m = self.M-1
      else:
        self.m = 0

    # tmp state shift index to store
    self.stateidx = self.n % self.S # state index

    # meta-data
    self.cycle = 0

  def step(self):
    """
    A single cycle step returning the mth branch output at time nD for both the
    polyphase FIR and phase rotation
    """
    self.cycle += 1

    t = self.n*self.D   # decimated sample time
    s = self.n % self.S # state index
    self.stateidx = s

    # polyphase FIR output
    ym = "y{}[{}] = ".format(self.m,self.n*self.D)
    for p in range(0, self.P):
      if p==0:
        ym += "h{}x{}".format(self.hmap(p,self.m), self.xmap(p,self.m))
      else:
        ym += " + h{}x{}".format(self.hmap(p,self.m), self.xmap(p,self.m))

    # phase rotation output
    rs = (self.m-self.shifts[s]) % self.M
    ymprime = "y'({},{})[{}] = y{}[{}] = ".format(self.m, s, t, rs, t)
    for p in range(0, self.P):
      if p==0:
        ymprime += "h{}x{}".format(self.hmap(p, rs), self.xmap(p, rs))
      else:
        ymprime += " + h{}x{}".format(self.hmap(p,rs), self.xmap(p, rs))

    yex = "y{}".format(rs+self.n*self.M)

    if self.order == "reversed":
      # output ordered from port M-1 down to zero
      if self.m==0:
        self.n += 1
      self.m = (self.m-1) % self.M
    else:
      # output ordered from port 0 to M-1
      if self.m==self.M-1:
        self.n += 1
      self.m = (self.m+1) % self.M

    # output tuple format
    # (polyphase fir output, phase rotation, debug val matching handdrawn)
    return (ym, ymprime, yex)

  def hmap(self, p, m):
    return p*self.M+m

  def xmap(self, p, m):
    return self.n*self.D-p*self.M-m


def latencyComp(P, M, D):
  """
  Calculate the added latency due to the loopback and modulo operation of the
  resampling. This is the extra latency that the is added to the total latency
  of the PEs.

  Note that this is computed under the assumption that the desire is to know
  when the first input sample appears in the last term of the polyphase sum.
  Therefore, as mentioned previously this idea of "when are data valid" may
  result in a different latency calculation. This is yet undecided as this is
  the current area of investigation.

  The algorithm works by counting the number of times the modulo operator is
  not triggered and adding the difference (M-D). This is essentially a brute
  force depection of the mod pattern as noted in some handwritten notes. Each
  time the modulo operator is triggered the iterator counts up until it reaches P-1
  (the number of PEs). What this does is it follows the pattern that is seen in
  the derivation of the resampling polyphase FIR for when input samples should be
  delivered to the filter and not. In this case the delay is incremented when we
  don't deliver a sample and the PE count is increased when we do.

  Notice that the inital value for res = (0, 0) the second value of the tuple is
  required to change as to start the counting pattern correctly when different
  starting assumptions are made. This is what is mentioned in the notes in the
  OSPFB class. That when the intial value is being delivered to port D-1 and when
  we are solving using the earliest (or latest) (n,m) pair the second element of
  the tuple must be changed as to start the counting pattern correctly. This is
  what is meant when writing about "slipping" the pattern.  I am still trying to
  figure this out but my best explanation for now is that it is in line with the
  fact that we would normally (under critically sampled conditions) deliver
  samples starting at port M-1 which is what the output of the mod() operator
  tells us to do (it tells us what port we should be accessing).
  """

  res = (0,0)
  delay = 0
  i = 0
  while i < P:
    res = np.divmod(res[1]+D, M)
    if not res[0]:
      delay = delay + (M-D)
    else:
      i+=1

  return delay

def computeLatency(P, M, D):
  """
  Produces the cycle that the first input value will be in the last term of
  the polyphase output. While this function is created to indicate when data
  are valid it currently being investigated to what extend we need to know or
  even care.

  Each PE contributes 2M+(M-D) = 3M-D delay except the last PE which we only
  need to wait M cycles before the output is delivered. The offset of one moves
  us off the zero cycle.

  The latency compensation is manifest through the M-D loopback delay and the
  mod pattern that is a result of the oversampled nature. See the latency comp
  calculation for more notes and as documented elsewhere.
  """

  return (P-1)*(3*M-D) + M + 1 + latencyComp(P, M, D) + M


if __name__ == "__main__":
  import matplotlib.pyplot as plt
  from numpy.fft import (fft, ifft, fftshift)
  from numpy import (log10, abs, min, max)
  print("**** Software OS PFB Symbolic Hardware Calculation ****")

  # simulation data type
  SIM_DT = 'cx'

  # OS PFB parameters
  M = 32; D = 24; P = 8;
  NFFT = M

  # second stage parameters
  NFFT_FINE = 512

  # example ring buffer initialization
  rb = ringbuffer(8)

  # example manual tap and pe instantiation
  taps = ['h{}'.format(i) for i in range(0,M*P)]
  pe1 = pe(idx=1, M=M, D=D, taps=taps[(M-1)::-1])
  pe2 = pe(idx=2, M=M, D=D, taps=taps[(2*M-1):(M-1):-1])

  # It does not make sense to talk about samples other than '0' with an FIR
  # but this is left for verification with arbitrary values.
  initval = 0
  ospfb = OSPFB(M=M, D=D, P=P, initval=initval, dt=SIM_DT, followHistory=False)
  ospfb.enable()
  s = sink(M=M, D=D, P=P, init=None, order='natural')

  # output stack
  dout = stack(length=M, dt=SIM_DT)
  # collection of output frames
  ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=TYPES_MAP[SIM_DT])
  fi = 0 # ospfb_data output idx counter

  # TODO: What is the best way to catch and process generated samples by the
  # golden model.
  # Right now the approach is that the best thing to do is to just start
  # catching samples while the OPSB is sequentially pulling samples out of the
  # FIR model and computing FFT frames. Then when the time comes to compute a
  # fine frame the correct number of raw generated samples will have been
  # produced to just compute the golden model across the entire block of data.
  # NOTE that this approach takes advantage of what I believe to have shown that
  # the first for loop ends when the first real valid frame of output data from
  # the FIR is arriving. Meaning that we will be lined up from the begninng on
  # comparing the correct sequence of input samples with the correct OSPFB
  # output frames
  golden_in = []

  FINE_FRAMES = 10
  frameidx = 0
  GfMat = np.zeros((D*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)
  fineSpectrumMat = np.zeros((D*NFFT_FINE, FINE_FRAMES), dtype=np.complex128)

  # initialize data generator
  if SIM_DT is not 'str':
    fs = 10e3
    flist = [2200, 3050, 4125,5000, 6561, 8333]
    ntones = len(flist)

    src = ToneSource(M, sigpowdb=-3, fs=fs, ntones=ntones, freqlist=flist)
  else:
    src = SymSource(M, order='natural')

  Tvalid = M*P+2
  cycleValid = computeLatency(P, M ,D)
  Tend = 16500

  din = TYPES_INIT[SIM_DT] # init din incase ospfb.valid() not ready
  # need to advance the ospfb before stepping the sink
  # why the -1? I remember it has to do with Tvalid having +2 but would it make
  # more sense to instead have Tvalid at +1?
  # I did verify that this is the correct sequence that we want for collecting
  # the output it lines the frames up into the FFT buffer correctly.
  for i in range(0, Tvalid-1):
    # handshake on ospfb indicates a new sample will be accepted
    # otherwise din will keep the previous value generated
    if ospfb.valid():
      din = src.genSample()
      golden_in.append(din)

    peout, pe_firout = ospfb.step(din)

  #sys.exit()
  while frameidx < FINE_FRAMES:
  #for i in range(0, Tend):
    if ospfb.valid():
      din = src.genSample()
      golden_in.append(din)

    peout, _ = ospfb.step(din)

    # need to append each run but need to make sure an ifft shouldn't fire first
    if dout.full:
      x = dout.buf
      if SIM_DT is not 'str':
        ospfb_data[:, fi] = ifft(x, NFFT)*NFFT
      else:
        ospfb_data[:, fi] = x
      fi += 1
      dout.reset()

    dout.write(peout[1])

    # with symbolic outputs we can check individual output steps
    if SIM_DT is 'str':
      _, sink_rotout, _ = s.step()

      # retrieve just the sum form both the filter and sink
      rot = peout[1]
      sink_rotout = sink_rotout.split(" = ")[2]

      # with symbolic filter outputs the filter state is not initialized. The
      # filter is instead full of null values ('-'). We therefore cannot compare
      # the full sink value with the PFB output. Instead we can trim the filter
      # output and just compare what we do have.
      nid = rot.find('-')
      if (nid) >= 0:
        nplus = rot.find('+')
        if nid < nplus : # a null '-' appears before the first '+' (i.e., in the first tap)
          #print("skipping check, empty first tap")
          continue

        # form a shortened version of the filter output that can be compared with
        # the sink value
        sub = rot[0:nid]
        rot = sub.rpartition(' + ')[0]

      if (sink_rotout.find(rot) != 0):
        print("symbolic sim failed!")
        print(sink_rotout)
        print(rot)
        sys.exit()

    # Evaluation and second stage fft for numeric simulations
    if SIM_DT is not 'str':
      # if we want to check for NFFT_FINE -1 might want to move fi++ to end of
      # loop instead of right after ifft computation
      if (fi==NFFT_FINE): # we have enough outputs to comute a fine spectrum
        # plot the most recent output of the OSPFB
        #df = fs/NFFT
        #fbins = np.arange(0, NFFT)
        #tmp = ospfb_data[:,-1]
        #plt.plot(fbins*df, 20*log10(abs(tmp)))
        #plt.show()

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
        # all this time we have been collecting the input samples to process
        # against the golden model
        st = 0
        ed = 0
        GX = np.zeros((NFFT, NFFT_FINE), dtype=np.complex128)
        mm = 0
        decmod = 0
        gi = np.zeros((M, M*P-1), dtype=np.complex128)

        while ed < NFFT_FINE:
          gx = np.array(golden_in[0:M])
          del golden_in[0:M]
          #gx = np.asarray(golden_in[mm*M:(mm+1)*M])
          mm += 1
          (Gdec, gi, ndec, decmod) = golden(gx, ospfb.taps, gi, M, D, decmod)

          ed = st + ndec
          GX[:, st:ed] = Gdec
          st = ed

        Gfine = fftshift(fft(GX, NFFT_FINE, axis=1), axes=(1,))/NFFT_FINE
        Gfinepruned = Gfine[:, (hsov-1):-(hsov+1)]
        Gf = Gfinepruned.reshape(N_FINE_CHANNELS)
        GfMat[:, frameidx] = Gf
        frameidx += 1

        PLT_INV_SPEC=False
        if PLT_INV_SPEC:
          fig, ax = plt.subplots(4,8, sharey='row')
          for i in range(0,4):
            for j in range(0,8):
              k = (i*8)+j
              # this shift corrects for overlap between adjacent bins
              bin_shift = - ((NFFT_FINE//2) + k*2*hsov)

              subbins = np.arange(k*NFFT_FINE, (k+1)*NFFT_FINE) + bin_shift
              cur_ax = ax[i,j]
              cur_ax.plot(subbins*fs_os/NFFT_FINE, 20*log10(abs(fineoutputmat[k, :])))
              cur_ax.set_xlim(min(subbins*fs_os/NFFT_FINE), max(subbins*fs_os/NFFT_FINE))
              cur_ax.grid(True)
          plt.show()

          fig, ax = plt.subplots(4,8, sharey='row')
          for i in range(0,4):
            for j in range(0,8):
              k = (i*8)+j
              # this shift corrects for overlap between adjacent bins
              fbins_corrected = np.arange((k-1/2)*(NFFT_FINE-2*hsov),(k+1/2)*(NFFT_FINE-2*hsov))
              cur_ax = ax[i,j]
              cur_ax.plot(fbins_corrected*fs_os/NFFT_FINE, 20*log10(abs(fineOutputPruned[k, :])))
              cur_ax.set_xlim(min(fbins_corrected*fs_os/NFFT_FINE), max(fbins_corrected*fs_os/NFFT_FINE))
              cur_ax.grid(True)
          plt.show()

        # plot fine spectrum
        fshift = -(NFFT_FINE/2-hsov+1)
        fbins_fine = np.arange(0, N_FINE_CHANNELS) + fshift
        faxis_fine = fbins_fine*fs_os/NFFT_FINE

        #plt.plot(faxis_fine, 20*np.log10(np.abs(fineSpectrum)))
        #plt.plot(faxis_fine, 20*np.log10(np.abs(Gf)))
        #plt.grid()
        #plt.show()

        # clear ospfb_data and reset fi
        ospfb_data = np.zeros((NFFT, NFFT_FINE), dtype=TYPES_MAP[SIM_DT])
        fi = 0

  if frameidx==FINE_FRAMES:
    Sxx_model = np.mean(np.real(fineSpectrumMat*np.conj(fineSpectrumMat)), 1)
    Sxx_golden = np.mean(np.real(GfMat*np.conj(GfMat)), 1)


    plt.plot(faxis_fine, 10*np.log10(Sxx_model))
    plt.plot(faxis_fine, 10*np.log10(Sxx_golden))
    plt.ylim([-20, 70])
    plt.grid()
    plt.show()




# NOTE
# I have two time approaches that I am needing to rationalize. For almost the
# entire time I was developing this ospfb architecture wanting to make sure I
# knew when the first sample (relly the x0 sample) was in the last tap on the
# output.
#
# I thought through the process to get build the sink that could compute it and
# then I derived the latency computation AND compensation due to the delay line
# that would allow me to line up the polyphase FIR components and know exactly
# when that initial sample showed up in the last tap.
#
# Now working on the phase compensation to think about it I realized that
# starting the phase compensation core was independent of D and that any M, P
# pair you waited M*P + 1 - M + 1 = M*(P-1) + 2 which is the length L=M*P of the
# filter +1 minus M for anticipating the wind up of the phase rotation buffer
# plus the additional 1 to move off the zero-th cycle.
#
# And so now since it is just M*P+1 + 1 to get the h0x0 term on the output
# (which is just the dealy of the sum path in the PE drawings -- including the
# phasse roation) I am back to not really "needing" to know exactly when samples
# come out other.
#
# Because all I am doing is just moving past ospfb outputs that have time
# samples less than zero until all greater than zero and comparing that with the
# sink.
#
# So I am back at wanting to know when I want to compare samples again but only
# because I am wanting to check all  my answers....
#
# And therefore this is the question, do I leave as is, or figure it out.
#
# By the way, this implies I do want a valid signal that starts the phase
# rotation buffer.
#
# But I am really thinking I don't want to care to find a general approach at
# this moment and just either compare as I can or just keep steping the outputs
# until I don't find a string with the null '-' char.
