clearvars;
% read csim output

fname = "../csim/data/out.dat";
fp = fopen(fname);

data = fread(fp, 'float32');

% TODO: Have data file contain this info to parse out
windows = 833;
M = 32;
D = 24;
X = reshape(data, [2, M*windows]);
X_cx = X(1,:) + 1j*X(2,:);

pfb_output = reshape(X_cx, [M, windows]);

offset = 8;

fs = 10e3;
fbins = 0:M-1;
f = fbins*fs/M;

% coarse output plot
figure(99);
plot(f, 20*log10(abs(pfb_output(:,offset)))); grid on;


% second stage PFB (fft for now...) (copied from sim_oversampled_pfb)
fs_decimated = fs/D; % decimated sample rate on the output of the pfb (Hz)
Nfft = 512;
fbins = 0:Nfft-1;

df = fs_decimated/Nfft; % bin width (Hz)
f = fbins*df;

hsov = fs/2*(1/D-1/M)/df; % half-sided overlap - bins to throw away on the right and left channels boundries
channel_bins = Nfft-hsov*2; % channels reamining after discarding overlapped regions.

full_pfb_spectrum = fftshift(fft(pfb_output(:, offset:Nfft+offset), Nfft, 2), 2)/Nfft; % apply the fft across the matrix
pfb_spectrum = full_pfb_spectrum(:, hsov:end-hsov-1);

% subplots for each pfb channel
% for m = 1:M
%   figure(2);
%   subplot(4,8,m);
%   fbins_corrected = ((m-1)-1/2)*(Nfft-2*hsov):((m-1)+1/2)*(Nfft-2*hsov)-1;
%   f_corrected = fbins_corrected*fs_decimated/Nfft;
%   plot(f_corrected, 20*log10(abs(pfb_spectrum(m,:)))); grid on;
%   xlim([min(f_corrected), max(f_corrected)]);
%   ylim([-60, 20]);
% end

figure(11);
os_pfb_stitch = reshape(pfb_spectrum.', [1, (Nfft-2*hsov)*M]);
fbins_os = (-Nfft/2+hsov-1):((M*Nfft-Nfft/2-1)-2*M*(hsov-1)-1);
f_os = fbins_os*fs_decimated/Nfft;
plot(f_os, 20*log10(abs(os_pfb_stitch))); grid on;
xlim([min(f_os), max(f_os)]);