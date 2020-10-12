import sys, argparse

from fixedpoint import toUnsigned
import numpy as np

if __name__=="__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('-M', '--FFTLEN',  type=int, default=64, help="Transform Size")
  parser.add_argument('-b', '--bits',    type=int, default=23, help="Bit resolution")
  parser.add_argument('-s', '--save',    action='store_true', help="Save coeff to file")
  parser.add_argument('-F', '--forward', action='store_true', help="Generate forward transfrom twiddle factors")
  args = parser.parse_args()

  Nfft = args.FFTLEN
  Nfft_2 = Nfft//2

  bits = args.bits
  verify_fmt = "{{:0{:d}x}}".format(int(np.ceil(bits/4)))
  packed_fmt = "{{:0{:d}x}}".format(int(np.ceil(2*bits/4))) # {im, re} packed

  forward = args.forward

  k = np.arange(0, Nfft_2)
  if forward:
    print("creating twiddle factors for forward transform")
    Wk = np.exp(-1j*2*np.pi*k/Nfft)
    transform_type = "forward"
  else:
    print("creating twiddle factors for inverse transform")
    Wk = np.exp(1j*2*np.pi*k/Nfft)
    transform_type = "inverse"

  lsb_scale = 2**(-(bits-1))

  Wk_re = np.round(np.real(Wk)/lsb_scale)
  Wk_re_sat = np.where(Wk_re >= 2**(bits-1), 2**(bits-1)-1, Wk_re)
  Wk_re_quant = np.int64(Wk_re_sat)

  # check bounds and saturate at both the high an low end of the quantized range because the imaginary
  # component of the complex exponential will have a positive or negative one based on the transform
  # direction (twiddle factors for inverse are conj(Wk))
  Wk_im = np.round(np.imag(Wk)/lsb_scale)
  Wk_im_sat = np.where(Wk_im < -2**(bits-1), -2**(bits-1), Wk_im)
  Wk_im_sat = np.where(Wk_im >= 2**(bits-1), 2**(bits-1)-1, Wk_im)
  Wk_im_quant = np.int64(Wk_im_sat)

  fname = "twiddle_{:s}_n{:d}_b{:d}.bin".format(transform_type, Nfft, bits)
  fp = open(fname, 'w')
  for i in range(0,Nfft_2):
    xq = toUnsigned(Wk_im_quant[i], bits) # toUnsigned prepares the number for the hex formated string without
    xi = toUnsigned(Wk_re_quant[i], bits) # python inserting the stupid hex string with '-x0001' to represent negative one
    packed = (xq << bits) | xi
    s_packed = packed_fmt.format(packed)
    fp.write(s_packed+"\n")
    print(verify_fmt.format(xq), verify_fmt.format(xi))
  fp.close()


  
