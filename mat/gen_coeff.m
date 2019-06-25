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

% fname = "/home/mcb/git/alpaca/oversampled-pfb/csim/coeff.dat";
% fp = fopen(fname, 'w+');
% % learned that c++ has no built conversion from hex to float and so a hex
% % representation file to be included for an array becomes unsinged longs or
% % something like that. The only form in the standard is to have them
% % represented as text
% fprintf(fp, '%g,\n', h);

fine = 8192;
H = fft(h, fine);
faxis_normalized = (0:1/(fine/2):2-1/(fine/2));
plot(faxis_normalized, 10*log10(abs(H))); grid on;
xlabel('normalized frequency');

% We don't want 32 filters spaced here, we want 24 spaced here inside a 32
% window area and then we are throwing channels out to.
% I assert (without proof, yet) that the  best you can do in designing your
% filter is to have adajacent channels overlap at the corner frequency for
% the oversampled case (e.g., 1/D).
% So in my mind how I am thinking of it now is that the channel passband
% extends out to 1/D in normalized frequency but we are going to end up
% only keeping up to 1/M. The region between [1/M and 1/D] is sort of (I
% think) "slack" that we have to play with. The number of channels we throw
% away though ultimately depends on how aligned we are and the aliasign we
% want to achieve. But again this is where I assert that based on the
% design here, the worst case is you are retaining D/M of your band. 
f_c_cs = 1/M; % critically sampled corner in normalized frequency [-1, 1];
f_c_os = 1/D; % oversampled corner frequency in normalized frequency [-1, 1];

% Some interesting take aways for specific numbers to think about. Consider
% the oversample ratio 4/3, M=32, D=24. Then a second stage PFB at N=512.
% The total number of possible channels is 512*32=16384 but we actually
% reatain 24*512=12288. The ratio's of these equal our oversampled ratio
% (16384/12288 = 4/3 with the inverse being 12288/16384 = 3/4) and the
% inverse can be thought of the amount of the band that we get to keep. So
% a smaller overample ratio, the less we have to potentially throw away.


