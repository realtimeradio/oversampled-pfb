function Z = pfb2(Y,L_f,L_c)
%%% Second stage, i.e. fine filter bank
%  Note that here we use a simple FFT rather than full PFB since it is
%  unnecessary to have a true PFB in the second stage to observe
%  scolloping.  Do not implement this in the GPU as coded here.
%
%  Brian D. Jeffs  7/19/17

YY = reshape(Y,L_f,[],L_c);
Z = fftshift(fft(YY),1);

end
