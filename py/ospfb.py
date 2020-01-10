import sys
import numpy as np

def minTuple(t):
    m = (0,0)
    if (t[0] < m[0]):
      m = t
    return m


class OSPFB:
  def __init__(self, M, D, P, initval, followHistory=False):
    self.M = M
    self.D = D
    self.P = P
    self.L = P*M
    self.osratio = float(M)/float(D)
    self.iterval = initval
    self.followHistory = followHistory

    self.modtimer = 0
    self.cycle = 0
    self.run = False

    # initialize prototype LPF
    self.taps = ['h{}'.format(i) for i in range(0, self.L)]

    # initialize PEs elements
    self.PEs = [pe(idx=1, M=M, D=D, taps=self.taps[M-1::-1], keepHistory=self.followHistory)]
    self.PEs += [pe(idx=i, M=M, D=D, taps=self.taps[i*M-1:(i-1)*M-1:-1], keepHistory = self.followHistory) for i in range(2, (P+1))]

  def enable(self):
    self.run = (not self.run)
    print("PFB is {}".format("running" if self.run else "stopped"))

  def step(self):
    if not self.run:
      print("PFB not enabled...returning")
      return

    self.cycle += 1
    vnext = self.valid()
    if vnext=="False":
      dnext = "*"
    else:
      dnext = "x{}".format(self.iterval)
      self.iterval += 1

    self.modtimer = (self.modtimer+1) % self.M
    peout = self.runPEs(dnext, vnext)
    print("T={:<3d} in:({:<4s}, {:<5s}), out:({:<4s}, {}, {})".format(self.cycle, dnext, vnext,
                                                  peout[0], peout[1], peout[2]))

    return peout

  def runPEs(self, din, vin):
    peout = () # empty tuple just as a reference it is tuple out
    for (i, pe) in enumerate(self.PEs):
      if i==0:
        peout = pe.step(din, '0', vin)
      else:
        peout = pe.step(peout[0], peout[1], peout[2])

    return peout

  def valid(self):
    return "True" if self.modtimer < self.D else "False"

  def getHistory(self, dumpf=False):
    strhist = ""
    # only need to increase the databuf and delaybuf large cycle counts
    dbfmt = "{{{:s}}}".format(":<5s") # field width of 5 for when need negative inputs 3 when positive
    validfmt = "{{{:s}}}".format(":<2s")
    delayfmt = "{{{:s}}}".format(":<5s") # field width of 5 for when need negative inputs 3 when positive
    sumfmt = "{{:<{:d}s}}".format((self.P-1)*9+6) # 9 for the 6 pe char and 3 for the ' + ' connecting sum values beetween pe
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
      s += "-"*40
      s += "\n"
      s += "{}\n".format(pe)

    return s

  def __repr__(self):
    return self.print()


class pe:
  def __init__(self, idx, M, D, taps, keepHistory=False):
    self.idx = idx 
    self.M = M
    self.D = D
    self.taps = None
    self.keepHistory = keepHistory
    self.sumbuf   = ringbuffer(length=M)
    self.delaybuf = ringbuffer(length=(M-D))
    self.databuf  = ringbuffer(length=2*M)
    self.validbuf = ringbuffer(length=2*M, load=["False" for i in range(0,2*M)])

    self.cycle = 0

    self.sumhist   = None
    self.dbhist    = None
    self.delayhist = None
    self.validhist = None

    if len(taps) != M: 
      print("PE: Init error number of taps not correct")
    else:
      self.taps = ringbuffer(length=M, load=taps)
      self.taps.head = (M-D)
      self.taps.tail = (M-D)

  def step(self, din, sin, vin):
    # default values
    self.cycle += 1
    d = "-"
    vout = "False"
    sout = "-"
    dout = "-"

######## TESTING NEW CONTROL/DATAFLOW #########
# Re-writing the control this way yields the same
# result as previous control flow
#
#    dbuf = self.delaybuf.buf[self.delaybuf.head] # has to be here since we need the value before it is overwritten
#    if vin=="True":
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
    if self.delaybuf.full and (vin=="True"):
      d = self.delaybuf.war(din)
    elif vin=="True":
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
    if sin == "0":
      s = ('{}{}').format(coeff, din)
    else:
      s = ('{} + ' + '{}{}').format(sin, coeff, din)

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
      print("No history has been accumulated")
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
  # max representable is a 128 long string per buffer element
  dt = np.dtype((np.unicode_, 128)) 

  def __init__(self, length=16, load=None):
    self.head = 0
    self.tail = 0
    self.full = False
    self.empty = True
    self.length = length

    self.buf = np.zeros(length, self.dt)
    self.buf = ["-" for i in range(0, self.length)]

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
  def __init__(self, M, D, P, init):
    self.M = M
    self.P = P
    self.D = D
    self.init = init

    self.cycle = 0

    # determine the decimated time sample (n*D) and branch index that the initial
    # value (init) will first appear in the last term of the polyphase sum
    self.l = []
    self.num = lambda m: (self.init+(self.P-1)*self.M+m)
    for m in range(0,self.M):
      if (self.num(m)%self.D == 0):
        self.l.append((int(self.num(m)/self.D), m))

    self.startbranch = min(self.l, key=minTuple)
    self.m = self.startbranch[1]
    self.n = self.startbranch[0]

  def step(self):
    self.cycle += 1

    ym = "y{}({}) = ".format(self.m,self.n*self.D)
    for p in range(0, self.P):
      if p==0:
        ym += "h{}x{}".format(self.hmap(p,self.m), self.xmap(p,self.m))
      else:
        ym += " + h{}x{}".format(self.hmap(p,self.m), self.xmap(p,self.m))

    if self.m==0:
      self.n += 1
    self.m = (self.m-1) % self.M
    return ym

  def hmap(self, p, m):
    return p*self.M+m

  def xmap(self, p, m):
    return self.n*self.D-p*self.M-m


def latencyComp(P, M, D):
  """
  Calculate the added latency due to the loopback and modulo operation of the
  resampling. This is the extra latency that the is added to the total latency
  of the PEs.

  It is also noted that is is added in the case when we want to know when the
  first complete sum is finished (i.e., the first input sample appears in the
  last term of the polyphase sum).

  The way this works is by counting times the modulo operator is not triggered
  and adding the difference (M-D). Each time the modulo operator is triggered
  iterator counts up until it reaches P-1 (the number of PEs). What this does is
  it follows the pattern that is seen in the derivation of the resampling
  polyphase fir for when input samples should be delivered to the filter and
  not. In this case the delay is incremented when we don't deliver a sample and
  the PE count is increased when we do.

  Notice that the inital value for res = (0, M-1) this is required to start
  counting the pattern correctly. I am still trying to figure this out but my
  best explanation for now is that it is in line with the fact that we would
  normally (under critically sampled conditions) deliver samples starting at
  port M-1 which is what the output of the mod() operator tells us to do (it
  tells us what port we should be accessing).
  """

  res = (0,M-1)
  delay = 0
  i = 0
  while i < P:
    res = np.divmod(res[1]+D, M)
    if not res[0]:
      delay = delay + (M-D)
    else:
      i+=1

  return delay

if __name__ == "__main__":
  print("**** Software OS PFB Symbolic Hardware Calculation ****")

  # example ring buffer initialization
  rb = ringbuffer(8)

  M = 8; D = 5; P = 4;

  # manual manual tap and pe instantiation
  taps = ['h{}'.format(i) for i in range(0,M*P)]
  pe1 = pe(idx=1, M=M, D=D, taps=taps[(M-1)::-1])
  pe2 = pe(idx=2, M=M, D=D, taps=taps[(2*M-1):(M-1):-1])

  # This is where I should start tomorrow. But I am not sure I remember what I
  # meant by pointers. If I am remembering correctly I am refering to the
  # starting coefficient pointer. In the original DG/SFG the derivation of the
  # systolic architecture pointed to interleaving that resulted in starting at
  # the port M (in the critically sampled case) and so in the oversampled case I
  # then started at port M-D which is where we would start the coefficients
  # from. Which is why in the original hand drawn diagrams for M=4, D=3, P=3 the
  # filter coefficients for the first PE start h2, h1, h0, h3

  # but now I am trying to determine how to know when the output is valid
  # because I am trying to see patterns but then some cases seems to violate any
  # hurestics or patters (like M=8, D=5, P=4) there are some '-' that show up
  # after the cycleValid comparison.

  # I am also reconsidering the whole initvalue and determine the branch and
  # time the sample is valid and the whole rotated pointers because maybe we
  # want to just always start with sample x0 h0. This stems from the fact I
  # still need to know when the outputs are the ones that I care about and can
  # rotate in the phase correction buffer....

  # w/o changing pointers in ospfb only valid initvals are -11, -8, -5, -2, etc.
  # but changes with M and **it is important to change** ( I think 1 is always
  # safe though because it is the one after n=0
  initval = 1

  ospfb = OSPFB(M=M, D=D, P=P, initval=initval, followHistory=False)

  # A poorly described explanation of how this is determined (and kind of why)
  # is in the comments of the latencyComp function.
  addedLatency = latencyComp(P, M, D)

  # Each PE contributes 2M+(M-D) = 3M-D delay but on the last PE we only way M
  # before the output is delivered. The offset of one moves us off cycle 0
  # and see latencyComp for the calculation of the added latency.
  # in my hand written simulation notes for the OS PFB with M=4, D=3, and P=2 I
  # have the first valid output being produced at cycle 10 the difference is I
  # wasn't taking into account the additional M latency that would be present in
  # a generic PE (coding a PE that didn't have that delay).

  # This is the cycle valid for when the initial value (initval) will appear in
  # the last term of the polyphase sum. 
  cycleValid = (P-1)*(3*M-D) + M + 1 + addedLatency

  s = sink(M=M, D=D, P=P, init=initval)

  ospfb.enable()
  print("Data will be valid on cycle T={}".format(cycleValid))
  for i in range(0,cycleValid):
    peout = ospfb.step()
    if ospfb.cycle >= cycleValid:
      sinkout =s.step()
      print(sinkout)
      sinksplit = sinkout.split(" = ")
      if not (sinksplit[1] == peout[1]):
        print("Outputs did not match")

