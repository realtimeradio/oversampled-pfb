import numpy as np
from ospfb import sink

def latencyCalc(P, M, D):
  res = (0,M-D)
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

M = 4
D = 3
Pmax = 10

print("M=", M, " D=", D, "\n")

for i in range(1, Pmax+1):
  s = sink(M=M, D=D, P=i, init=0)
  d = latencyCalc(i, M, D)
  print("P = {:<4d}: {}".format(i,s.l))
  #print("added latency = {:<4d}".format(d))
