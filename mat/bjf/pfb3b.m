function [Y_Dec, Xf, ls] = pfb3b(x,L_c,H,Xi,ls, Dec)
%
%  This version does not do a true polyphase filter bank but a conventional
%  bank of basebanding decimating FIR filters using down mixers.  It can
%  serve as a gold standard reference for what pfb3os should do, allbeit
%  this is not nearly as efficient as pfb3os.
%
% Brian D. Jeffs  7/18/17
%   Modified 11/20/18 to support arbitrary decimation rates, Dec

N = length(x);
h = H(:);
n = [0:N-1]';

% create L_c different frequency mix downs of x
Xmix = zeros(N,L_c);
kk = 1;
for k = L_c/2:-1:-L_c/2+1
    Xmix(:,kk) = x.*exp(1j*2*pi*k*(n+ls)/L_c);
    kk = kk+1;
end

% lowpass filter and decimate
[Y, Xf] = filter(h,1,Xmix,Xi);
Y_Dec = Y(Dec-ls:Dec:end,:);      % Decimated output

% Since N may not be a multiple of Dec, keep track of where decimation left
% off and restart on next call at the same point
ls = mod(N-Dec+ls,Dec);    

end