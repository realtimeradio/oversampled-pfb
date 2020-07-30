import sys

from ospfb import (OSPFB, sink, computeLatency)
from source import SymSource
from taps import SymTaps
from utils import TYPES_INIT

if __name__ == "__main__":
  print("**** Software OS PFB Symbolic Hardware Simulation ****")

  SIM_DT = 'str'

  # OS PFB parameters
  M = 8; D = 6; P = 3;

  taps = SymTaps.genTaps(M, P, D)

  # TODO: it looks initval is really just depricated since the ospfb doesn't produce the
  # symbolic inputs anymore. As discussed below there was a capability for symbolic processing
  # to have control over the starting input symbolic sample and when to start looking at which
  # output sample and branch that first input sample appears on. The capabiliyt to do this may
  # be irrelevant but if it is required it is needed to be implemented elsewhere such as the
  # symbolic sink or source.
  #
  # It does not make sense to talk about samples other than '0' with an FIR
  # but this is left over as a reminder of the capability for verification with arbitrary values.
  initval = 0
  ospfb = OSPFB(M=M, D=D, P=P, taps=taps, initval=initval, followHistory=False)
  ospfb.enable()

  k = sink(M=M, D=D, P=P, init=None, order='natural')
  src = SymSource(M, order='natural')

  # What we call "valid" here is relative and depends what we care about as valid.
  #
  # In this version of the symbolic simulator the 'Tvalid' represents when the sink instance 'k'
  # should start to be stepped to compare outputs. Without the init value the sink instance first
  # value starts at discrete time step n=0, branch index m=0 of the general expression for the
  # FIR output of the OSPFB.
  #
  # This means that the output form contains non-causal symbolic time samples prior to zero
  # (i.e., x[-1], x[-2], ...). In other words Tvalid is the pure latency of the OSPFB.
  #
  # 'cycleValid' would be the cycle time when the sink should be stepped to start comparing when
  # the init value sample (usually x0) appears in the last tap of the FIR sum (i.e, h0x4+ h4x0).
  # In otherwords, this is the first valid sample after the 'wind up' of the FIR.
  #
  # For this symbolic simulation 'Tvalid' is used and 'cycleValid' is here to show how it would
  # be computed but not how you would set up the OSPFB to use it. The capability to use
  # 'computeLatency' (and arbitrary init values) is available but what is needed to make that
  # happen is sprinkled through the source code for the ospfb class.
  #
  # This approach was settled on because it didn't make sesne to 1) talk about init values other
  # than x0 since this is when casual samples occur and 2) the wind up doesn't really matter that
  # much.
  #
  # However, the question of 'valid' for hardware processing particularly passing a valid signal
  # to the FFT in HDL is still something we care about and need to be worked on.

  Tvalid = M*P+2
  cycleValid = computeLatency(P, M ,D)
  # simulation end cycle
  Tend = Tvalid + 2000

  # Advance the ospfb to match when stepping the sink compares to valid outputs
  din = TYPES_INIT[SIM_DT] # init din in case ospfb.valid() not ready
  for i in range(0, Tvalid-1):
    # simulate hardware-like AXIS handshake
    # The ospfb indicates a new sample will be accepted otherwise din is held at the previous value
    if ospfb.valid():
      din = src.genSample()

    peout, pe_firout = ospfb.step(din)

  while ospfb.cycle < Tend:
    # simulate hardware AXIS handshake
    if ospfb.valid():
      din = src.genSample()

    peout, fir_out = ospfb.step(din)

    # check individual output steps when processing symbolic data
    _, sink_rotout, _ = k.step()

    # get just the sum from both the ospfb and sink outputs
    rot = peout[1]
    sink_rotout = sink_rotout.split(" = ")[2]

    # In symbolic processing the filter state is not initialized. Instead, the
    # filter continues to operate filling results with "null" values ('-')
    # until a valid symbolic value is available.  We therefore cannot compare
    # sink and ospfb outputs until the filter state is populated.
    # Instead what we do is trim the filter output and compare what is ready.
    nid = rot.find('-')
    if (nid) >= 0:
      nplus = rot.find('+')
      # nothing to check if a null appears in the first tap (before the first '+')
      if nid < nplus :
        continue

      # trim for a shortened filter output we can compare against
      sub = rot[0:nid]
      rot = sub.rpartition(' + ')[0]

    if (sink_rotout.find(rot) != 0):
      print("Symbolic simulation FAILED!")
      print("expected:", sink_rotout)
      print("computed:", rot)
      sys.exit()

  print("SIMULATION COMPLETED SUCCESSFULLY!")
