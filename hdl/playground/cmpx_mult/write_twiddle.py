from fixedpoint import toUnsigned
import numpy as np

if __name__=="__main__":

  fname = "twiddle_n32_b23.bin"

  bits = 23
  verify_fmt = "{{:0{:d}x}}".format(int(np.ceil(bits/4)))
  packed_fmt = "{{:0{:d}x}}".format(int(2*np.ceil(bits/4))) # {im, re} packed

  Nfft = 16
  Nfft_2 = Nfft//2

  k = np.arange(0, Nfft_2)

  Wk = np.exp(1j*2*np.pi*k/Nfft_2)

  lsb_scale = 2**(-(bits-1))

  Wk_re = np.round(np.real(Wk)/lsb_scale)
  Wk_re_sat = np.where(Wk_re >= 2**(bits-1), 2**(bits-1)-1, Wk_re)
  Wk_re_quant = np.int64(Wk_re_sat)

  Wk_im = np.round(np.imag(Wk)/lsb_scale)
  Wk_im_sat = np.where(Wk_im < -2**(bits-1), -2**(bits-1), Wk_im)
  Wk_im_quant = np.int64(Wk_im_sat)

  fp = open(fname, 'w')
  for i in range(0,Nfft_2):
    xq = toUnsigned(Wk_im_quant[i], bits)
    xi = toUnsigned(Wk_re_quant[i], bits)
    packed = (xq << bits) | xi
    s_packed = packed_fmt.format(packed)
    fp.write(s_packed+"\n")
    print(verify_fmt.format(xq), verify_fmt.format(xi))
  fp.close()


  
