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
    sumfmt = "{{:<{:d}s}}".format((self.P-1)*9+6)
    for i in range(self.P-1, -1, -1):
      pe = self.PEs[i]
      #sumfmt = "{{:>{:d}s}}".format(i*9+6) #i for the pe, 9 for the 6 pe char and 3 for the ' + ' connecting sum values beetween pe
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
    self.sumbuf = ringbuffer(length=M)
    self.delaybuf = ringbuffer(length=(M-D))
    self.databuf = ringbuffer(length=2*M)
    self.validbuf = ringbuffer(length=2*M, load=["False" for i in range(0,2*M)])

    self.cycle = 0

    self.sumhist = None
    self.dbhist = None
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
      #print("PE {}: Pulling from delay line".format(self.idx))
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
    #print("Current tap: {}".format(h))
    s = self.MAC(sin, din, h)
    if self.sumbuf.full:
      sout = self.sumbuf.war(s)
    else:
      self.sumbuf.write(s)
############ PREV CONTROL/DATAFLOW #############
    if self.keepHistory:
      self.updateHistory()    

    return (dout, sout, vout)


  def MAC(self, sin, din, coeff):
    if sin == "0":
      s = ('{}{}').format(coeff, din)
    else:
      s = ('{} + ' + '{}{}').format(sin, coeff, din)

    return s
    #return sin + din*sout


  def updateHistory(self):
    # create history looking like my hand drawings
    # really python-ic code here but I was too lazy to break each line out into
    # multiple variables that may have been more descriptive. However, what is
    # going on here is the *hist variables are matrices of the snapshot outputs
    # of each buffer. The roll operation by head moves each buffer as if the the
    # very next thing was first in the array. Then reshape and concatenate
    # formats each buffer into a column vector to concatenate and grow the
    # matrix.
    if self.sumhist is None:
      self.sumhist = np.reshape(np.roll(self.sumbuf.buf,-self.sumbuf.head), (self.M,1))
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
                              #(2*self.M+(self.M-self.D),1))
    else:
      self.validhist = np.concatenate((self.validhist,
                      np.reshape(np.roll(self.validbuf.buf,
                                        -self.validbuf.head),
                                        (2*self.M,1))),
                                        #(2*self.M+(self.M-self.D),1))),
                                 axis=1)


  def formatHistory(self, dbfmt, sumfmt, delayfmt, validfmt):

    if self.dbhist is None:
      print("No history has been accumulated")
      return ""

    strhist = ""
    # outer loop over all databuffer branches (2*M)
    for i in range(0, 2*self.M):
      for j in range(0, self.cycle):
        strhist += dbfmt.format(self.dbhist[i,j]) #" {:<3s}"

      # white space between databuf and valid buffer
      strhist += "{:<4s}".format(" ")

      # valid buffer history
      for j in range(0, self.cycle):
        strhist += validfmt.format(self.validhist[i,j][0])
      if i < self.M:
        strhist += "{:<4s}".format(" ")
        for j in range(0, self.cycle):
          strhist += sumfmt.format(self.sumhist[i,j]) #"{:>12s}"
      strhist += "\n"
    strhist += "\n"

    for i in range(0, self.M-self.D):
      # delay buffer
      for j in range(0, self.cycle):
        strhist += delayfmt.format(self.delayhist[i,j]) #" {:<s}"

      # white space between delay buffer and valid buffer
      strhist += "{:<4s}".format(" ")

      ## valid buffer when there is a valid buffer matching the delay line
      #for j in range(0, self.cycle):
      #  strhist += validfmt.format(self.validhist[8-i,j][0]) # no offset to get aligned with the delay buffer

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
  dt = np.dtype((np.unicode_, 128)) # max is a 128 long string per element

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

  # Insert a value into the ring buffer
  #   Error and do nothing when tail = head
  #   Return a tuple of the addr and value written
  def write(self, din):
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

  # write after read
  def war(self, din):
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

def latencyCalc(P, M, D):
  res = (0,M-1)
  #res = (0,3)
  delay = 0
  i = 0
  while i < P:
  #for i in range(0, P):
    res = np.divmod(res[1]+D, M)
    if not res[0]:
      delay = delay + (M-D)
    else:
      i+=1

  return delay

if __name__ == "__main__":
  print("**** Software OS PFB Symbolic Hardware Calculation ****")
  rb = ringbuffer(8)

  M = 2048; D = 1536; P = 8;
  # manual tap and pe instantiation
  taps = ['h{}'.format(i) for i in range(0,M*P)]
  pe1 = pe(idx=1, M=M, D=D, taps=taps[(M-1)::-1])
  pe2 = pe(idx=2, M=M, D=D, taps=taps[(2*M-1):(M-1):-1])

  # OSPFB instantiation
  # w/o changing pointers in ospfb only valid initvals are -11, -8, -5, -2, etc.
  # but changes with M and **it is important to change** ( I think 1 is always
  # safe though because it is the one after n=0
  initval = 1
  ospfb = OSPFB(M=M, D=D, P=P, initval=initval, followHistory=False)
  #sys.exit()
  # this latency comp works for some but not all cases so I still don't have it
  # right. But it works for the cases we care about... like ALPACA specs.
  #latencyComp = (M-D)*int((P-1)/(D/np.gcd(M,D)))

  latencyComp = latencyCalc(P, M, D)

  cycleValid = (P-1)*(3*M-D) + M + 1 + latencyComp

  s = sink(M=M, D=D, P=P, init=initval)
  #s = sink(t=startbranch, M=M, D=D, P=P, init=initval)
  # In my hand written simulation notes for the OS PFB with M=4, D=3, P=2 I have
  # the first outputs being produced at cycle 10 where as here they come at
  # cycle 14. This is because the PEs now have the FIFOs built-in and we must
  # wait for the FIFOs. The cycle the 1st data will be ready is (P-1)*(3*M-D)+M
  # which equates in waiting the P-1 data delay and loop back delay fifos plus
  # the last PE's sum buffer in the chain
  #
  # but something is still wrong... becuase the output is still off

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

