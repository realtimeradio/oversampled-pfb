
import numpy as np

def latencyCalc(P, M, D):
  # Need to document what the starting value in the res value means. I am still
  # tryig to accurately describe it. But for now it is important in order to
  # know how to line up and calculate the expected latency of the pipeline and
  # so it depends on the input sample
  res = (0,0) # (M-D) (M-1)
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

M = 8
D = 6
Pmax = 10

print("M=", M, " D=", D, "\n")

for i in range(1, Pmax+1):
  d = latencyCalc(i, M, D)
  print("P = {:<4d}: {:<4d}".format(i, d))

