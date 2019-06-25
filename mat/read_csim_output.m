clearvars;
% read in simulation data
fname = "../hls/data/out.dat";
fp = fopen(fname);
data = fread(fp, 'float32');
fclose(fp);

% TODO: Have data file contain some of these parameters parse out
% OS PFB parameters and simulation parameters
windows = 833;
M = 32;                  % Transform size (i.e., polyphase branches, Nfft_coarse)
D = 24;                  % Decimation rate (D < M)

Nfft_coarse = M;         % Transform size for 1st stage PFB (number of channels from 1st stage)
Nfft_fine = 512;         % Each corase PFB is channelized by Nfft

fs = 10e3;               % signal sampling rate (Hz)
fs_cs = fs/M;            % critically sampled PFB output time-series sample rate (Hz)
fs_os = fs/D;            % Oversampled PFB output time-series sample rate (Hz)

fbins_coarse = 0:M-1;
faxis_coarse = fbins_coarse*fs/M;

% reformat data read in from file
X = reshape(data, [2, M*windows]);
X_cx = X(1,:) + 1j*X(2,:);
os_pfb_output = reshape(X_cx, [M, windows]);

offset = 8;              % Ouputs from the OS PFB are considered valid after the number of taps (filter wind up effect)

% coarse output plot
figure(99);
plot(faxis_coarse, 20*log10(abs(os_pfb_output(:,offset)))); grid on;
title('Corase Channel'); xlabel('Frequency (Hz)'); ylabel('Power (arb. units dB)');

% Second stage channelizer computation (fft for now...extend to PFB later)
total_channels = Nfft_coarse*Nfft_fine;     % total number of channels in fine 'zoom' spectrum prior to discarding channels
hsov = (M-D)*Nfft_fine/(2*M);               % half-sided overlap; Number of overlapped channels for two adjacent channels;
                                            % Also thought of as the number
                                            % of discarded channels.
hs_count = D*Nfft_fine/(2*M);               % half-sided channel count; Number of channels preserved from bin center extending
                                            % to the edge of one channel

fine_channel_count = hs_count*2;       % number of fine channels remaning after discarding channels
                                       % note:
                                       % channel_count = Nfft_fine - 2*hsov

channels_fbins_fine = D*Nfft_fine;     % total number of channels in the fine 'zoom' spectrum after discarding channels
                                       % note:
                                       % fbins_fine = hscount * (2*M)
                                       % and
                                       % fbins_fine = (Nfft_fine-2*hsov)*M
                                       % all of these identities
 

fbins_fine_full = 0:total_channels-1;              % unpruned spectrum bins
faxis_fine_full = fbins_fine_full*fs_os/Nfft_fine; % unpruned frequency axis

% I want to figure out why waht was wrong here with the commented out
% fbins_os. Becuase I understand that I am starting at the left channel
% edge minus how many channels are discared for being oversampled but I
% don't know yet why my algorithm for stepping was wrong. Instead I here
% just start at 0 and go to number of remaning channels minus 1 and then
% apply the hsov shift to the left and then multiply by the fine channel
% oversampled bin width (fs_decimated/Nfft)
% I also learned that Brian shifts his up so that frequencies are greater
% than zero where I start with negative frequencies. This would seem to be
% that the difference is that I start with zero being a bin center and he
% starts with zero being a far left channel edge.

fshift = -(Nfft_fine/2-hsov+1);
fbins_fine = 0:channels_fbins_fine-1 + fshift;  % pruned spectrum bins
faxis_fine = fbins_fine*fs_os/Nfft_fine;        % pruned frequency axis

pfb_output_spectrum = fftshift(fft(os_pfb_output(:, offset:Nfft_fine+offset), Nfft_fine, 2), 2)/Nfft_fine; % apply the fft across the matrix
pfb_output_spectrum_full = reshape(pfb_output_spectrum.', [1, total_channels]);

zoom_pfb_spectrum = pfb_output_spectrum(:, hsov:end-hsov-1);

% % subplots for each pfb channel
% for m = 1:M
%   figure(2);
%   subplot(4,8,m);
%   fbins_corrected = ((m-1)-1/2)*(Nfft-2*hsov):((m-1)+1/2)*(Nfft-2*hsov)-1;
%   f_corrected = fbins_corrected*fs_decimated/Nfft;
%   plot(f_corrected, 20*log10(abs(pfb_spectrum(m,:)))); grid on;
%   xlim([min(f_corrected), max(f_corrected)]);
%   ylim([-60, 20]);
% end

% plot unpruned spectrum
figure(10);
plot(faxis_fine_full, 20*log10(abs(pfb_output_spectrum_full))); grid on;
title('Unpruned Zoom Spectrum'); xlabel('Frequency (Hz)'); ylabels('Power (arb. units dB)');
xlim([min(faxis_fine_full), max(faxis_fine_full)]);

% plot pruned spectrum
figure(11);
zoom_pfb_stitch = reshape(zoom_pfb_spectrum.', [1, (Nfft_fine-2*hsov)*M]);
plot(faxis_fine, 20*log10(abs(zoom_pfb_stitch))); grid on;
title('Pruned Zoom Spectrum'); xlabel('Frequency (Hz)'); ylabels('Power (arb. units dB)');
xlim([min(faxis_fine), max(faxis_fine)]);
