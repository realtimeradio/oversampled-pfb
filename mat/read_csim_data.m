clearvars;
% read in c simulated data

fname = "../csim/data/data.dat";
fp = fopen(fname);

% read in simulation parameters
nbytes = fread(fp, 1, 'char');
nbits = nbytes*8;
% after modifying the cpp code to use the std::complex data type my
% pervious code wouldn't work because the nbytes written by cpp was for a
% single complex element now instead of a single real or imaginary part.
% But for now if I divide by 2 the code I wrote now works. TODO: come back
% and modify
nbits = nbits/2;

% Modified the data type on the OS PFB to test with floats. Therefore, for
% now don't need to read in chars and cast to floats. But having this in
% the future will help and could look into making it automatic.
% precLabel = ['bit', int2str(nbits), '=>float32'];
precLabel = ['float32'];

Nparams = 2; % time (s), Fs (Hz)
params = fread(fp, Nparams, 'float32');
%params = fscanf(fp, '%g,%g', Nparams);

% remainder of file is data
% data = fscanf(fp, '%i,%i');
data = fread(fp, precLabel);
fclose(fp);

% extract parameters
t = params(1);
fs = params(2);

Nsamps = t*fs;

% format data
x = reshape(data, [2, Nsamps])'; % had to be [2, ] first to get it to parse right.

% begin processing
Nfft = 2048;

x = x(:,1) + 1j*x(:,2);

X = fft(x, Nfft)/Nfft;

fbins = 0:Nfft-1;
f = fbins*fs/Nfft;

plot(f, 20*log10(abs(X))); grid on;


