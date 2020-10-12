
"""
  Simple examples of what I did in information theory to manipulate bits to convince myself I can do this...
"""
def bin2dec(cw):
  """
  bin2dec: Given a binary string return the fractional representation in base 10
  """

  cw = list(cw)
  d = 0
  for i, b in enumerate(cw):
    d += int(b)*2**-(i+1)
  return d


def bin2dec(cw):
  """
  bin2dec: Given a binary string return the fractional representation in base 10
  """

  cw = list(cw)
  d = 0
  for i, b in enumerate(cw):
    d += int(b)*2**-(i+1)
  return d

def dec2bin(d, width):
  """
  dec2bin: Given a fractional number in base 10 return as a string the binary
  representation

  Q: should we be be checking against any sort of quantization error (e.g., 2**-BITS)
  """
  w = []
  while (len(w) < width):
    d *= 2
    if (d >= 1):
      w.append('1')
      d -= 1
    else:
      w.append('0')

  return "".join(w)

"""
"""

# Examples for how to take native (or hex values) and produce the signed equivalent)
def s4(v):
  return -(v & 0b1000) | (v & 0b0111)

def s5(v):
  return -(v & 0b100000) | (v & 0b01111)

def s8(v):
  return -(v & 0x80) | (v & 0x7f)

def s16(v):
  return -(v & 0x8000) | (v & 0x7fff)

def toUnsigned(v, bits):
  mask = 1 << (bits-1)
  return (v & mask) | (v & (mask-1))

def toSigned(v, bits):
  mask = 1 << (bits-1)
  return -(v & mask) | (v & (mask-1))

def sgn(v, w):
  mask = 0b1 << (w-1)
  return (v & mask) >> (w-1)

def same_sgn(a, b, w):
  return (sgn(a,w) ^ sgn(b,w)) ^ 0b1 # ending exclusive or to implement not since python's '~' is really the complement operator

def ovflow(a, b, w):
  ov = 0b0
  # picked 'a' arbitrarily to compare the sign to, could have done b, point is that if the opearnds where the
  # same sign and the sign changes we have overflowed in 2's complement
  if (same_sgn(a, b, w)):
    ov = sgn(a, w) ^ sgn(a+b, w)

  return ov

def tofracfixed(a, w, f):
  """
    a: integer, w: length of binary word, f: number of fractional bits
    convert binary  (or the int that results from bin(v) to the fractional fixed point representation
  """
  v = 0
  for s in range(0, w):
    tmp = ( (a>>s) & 0b1 )*2**(s-f)
    if (s==w-1):
      v += -tmp
    else:
      v += tmp
  return v

def add(a, b, w):
  res = a + b
  ov = 0b0
  if (same_sgn(a,b,w)):
    ov = sgn(a, w) ^ sgn(res, w)

  return (ov, res)  

if __name__=="__main__":
  print("fixed-point sandbox")


  res = s5(s4(7) + s4(4))

  # grab the round first
  # since we are treating them as integer (no binary point on our 4-bit numebr) an implicit binary
  # point is added between bit 4 and 5 (5 being the lsb, on the right)

  # Question: it seems this is easiest to detect for rounding cases because it is either even or not
  # there are no other bits lower. Is this true? Or am I missing something
  round_mask = 0b00001 # 0b1 is sufficient, zeros padded to length to be explicit
  
  inter_res = res & round_mask

  # then we have to detect this and round: implementing convergent round to even
  # if inter_res is 1 then 
  if (inter_res):
    res = res + 1

  # define slice mask
  slice_mask = 0b11110 # slice upper 4 bits from 5

  # slice and capture result
  ans = (res & slice_mask) >> 1 # right-shift by 1 because we want 4 from 5 (5-4=1) we need off

  # ok... so what do you do if you are doing
  res = s5(s4(3) + s4(2))

  # you don't want to do any rounding because as demonstrated this gives you a wack result.
  # And so in thinking about this and I find the paper 'Effect of Finite Word Length on the
  # Accuaracy of Ditial Filters -- A Review' and read "When two t-bit fixed point numers are
  # added their sum would sill have t bits, provided there is no overflow. Therefore, under
  # this assumption of no overflow, fixed-point addition causes no error.
  # And so as I am reading this it seems to dawn on me the answer to the question I asked
  # buckd about overflow and do I monitor it. Because it seemed to me at the time of going over
  # with him the arithmetic just having the extra bits for growth for addition seemed (at the
  # time) to remove the need detecting and reporting overflow. However, given my example above
  # where you round two numbers within in the range, you have no error and rounding would wack
  # your answer. So the answer is: yes you do always monitor overflow. Because this is when you
  # round otherwise, you don't need to and just can continue on.

  # You also always round with multiplcation by the way since multiplication always results in
  # needing the growth.

  # But I find this strange then that people always say "multiplication doesn't result in overflow"
  # .... I mean it seems that the fact you need (in the case of equal width multiplicands) twice
  # as many bits you essentially overflowed before you started.

  """
    Using the fact of 2's complement that to negate a number is to complement and add one we can
    generate a value that when interpreted as a fixed point fractional
  """
  # Say we want a value whoes 2's complement binary from interpretted as fractional fixed point (4,3)
  # is -0.25. Using the property of being of 2's complement that -x = comp(x)+1. So we can evaluate
  # the RHS to get -0.25 from starting with 0.25

  v = -0.25
  # note: I am pretty sure my dec2bin func will only work for when there is one digit to the left of the binary point
  # and that you pass the width of the fractional portion. This won't work for -1 so it needs to be improved
  # i think the idea is you get whole number part seperate from the fractional and so to do whole numbers we need to process
  # to the left and right of the binary point separately (e.g., 14.325 
  binstr = dec2bin(abs(v), 3)
  # make a python binary literal to convert to an int, is there a better way to do this? (i.e., make the literal in
  # dec2bin function instead of it return a str?
  binstr = "{}{}".format('0b', binstr)
  a = int(binstr, 2)

  # fortunately pythons gives us what we want as it is the complement operator, however it in general is not the bitwise
  # not like you would think
  # to do bitwise not:
  #  comp_a = a ^ 0b1111
  # where 0b1111 is a mask at our width to do the bitewise not
  comp_a = ~a

  twos_v = comp_a + 1

  v_frac = tofracfixed(twos_v, 4, 3)
  print(v_frac == v)

  # so while this isn't perfect this at least encapsulates the approach 

  # python math has the modf function that will return fractional and whole parts
  from math import modf
  v = 3.175
  f, i = modf(v)

  # so far with what I have here we can then produce some binary
  i = bin(int(i))
  f = dec2bin(f, 8)
  # then we can put these two strings together
  v = i+"."+f
  # the next step would be to produce an integer notation
