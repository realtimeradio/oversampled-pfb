% Polyphase filterbank parameters
M = 32;  % Polyphase branches (NFFT)
L = 256; % Taps in prototype FIR filter
P = L/M; % Taps in branch of a polyphase FIR filter
D = 24;  % decimation rate (D <= M)

% Design prototype LPF (Hanning window)
idx = -P/2*(M/D):1/D:(M/D)*P/2-1/D; % (M/D) 1/D to extend to the correct L length. Note: need to design the filter for the decimation rate D not the maximally sampled rate M in fact I really need to investiagate proper filter design here to get a super tight corner to achieve an image rejection as low as askap does of -60dB.
x = sinc(idx);
hann = hanning(L).';

h = x.*hann;

fname = "/home/mcb/git/alpaca/oversampled-pfb/csim/coeff.h";
fp = fopen(fname, 'w+');
fprintf(fp, '0x%tx,\n', h); 

