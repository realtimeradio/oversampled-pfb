clearvars;
% streaming oversampled PFB simulation code

% Polyphase filterbank parameters
M = 32;  % Polyphase branches (NFFT)
L = 256; % Taps in prototype FIR filter
P = L/M; % Taps in branch of a polyphase FIR filter
D = 24;  % decimation rate (D <= M)

% Compute ifft shifting states
Nstates = 4; % numerator of simplest rational fraction M/D
shift_state = zeros(1,Nstates);

for n=0:Nstates-1
  shift_state(n+1) = mod(n*D, M);
end

% Design prototype LPF (Hanning window)
idx = -P/2*(M/D):1/D:(M/D)*P/2-1/D; % (M/D) 1/D to extend to the correct L length. Note: need to design the filter for the decimation rate D not the maximally sampled rate M in fact I really need to investiagate proper filter design here to get a super tight corner to achieve an image rejection as low as askap does of -60dB.
x = sinc(idx);
hann = hanning(L).';

h = x.*hann;

% Data generation
fs = 10e3;   % sample rate (Hz)
f  = 5.5e3;  % SOI frequency (Hz)
t = 2;       % simulation time (seconds)
T = 1/fs;    % sample period (seconds)

Nsamps = fs*t;
n = 0:Nsamps-1; % sample index

signal = 20/sqrt(2)*(cos(2*pi*f/fs*n) + 1j*sin(2*pi*f/fs*n));
noise = 10/sqrt(2)*(randn(1,Nsamps) + 1j*randn(1,Nsamps)); 

x = signal + noise;

% oversampled PFB processing
input_buffer = zeros(1,M);               % input ports on PFB
filter_state = zeros(1,L);               % memory of samples going through PFB
shift_buffer = zeros(1,L);               % circular shift buffer for oversampling correction.
ifft_buffer  = zeros(1,M);               % input ports to the FFT
pfb_output   = zeros(M ,ceil(Nsamps/D)); % Decimates by D, producing M channels (when D=M, maximally sampled PFB)

data_ptr = 1; % pointer to data location
output_ctr = 1;
while data_ptr < length(x)-D

  % rotate filter state and shift new samples in by decimation rate
  filter_state = circshift(filter_state, -D);
  filter_state(end-D+1:end) = x(data_ptr:data_ptr+D-1);
  data_ptr = data_ptr + D;
  
  % polyphase filter computation
  for m = 0:M-1
    for p = 0:P-1
      ifft_buffer(m+1) = ifft_buffer(m+1) + h(p*M+m+1)*filter_state(L-p*M-m);
    end
  end

  % apply phase correction
  ifft_buffer = circshift(ifft_buffer, shift_state(1)); % always grab first element because we are rotating the shift_bufer
  shift_state = circshift(shift_state, 1);
  
  % ifft computation
  pfb_output(:, output_ctr) = ifft(ifft_buffer, M);
  ifft_buffer = zeros(1,M); % need to clear out the ifft buffer you dum dum
  output_ctr = output_ctr + 1;
end

% Second stage PFB (FFT for now)

% plot the output of the PFB compared to the FFT
offset = 8; % wait offset samples for output

figure(99);
X = fft(x(offset:offset+M), M)/M;
fbins = 0:M-1;
f = fbins*fs/M;
plot(f, 20*log10(abs(X)), f, 20*log10(abs((pfb_output(:,offset))))); grid on;
legend('FFT', 'Oversampled PFB');

% Second stage (fine channel mode) - forming a single spectrum for now, not
% averaging across multiple windows. This is the manefistation of the
% scalloping in the critically sampled case.
fs_decimated = fs/D; % decimated sample rate on the output of the pfb (Hz)
Nfft = 512;
fbins = 0:Nfft-1;

df = fs_decimated/Nfft; % bin width (Hz)
f = fbins*df;

hsov = fs/2*(1/D-1/M)/df; % half-sided overlap - bins to throw away on the right and left channels boundries
channel_bins = Nfft-hsov*2; % channels reamining after discarding overlapped regions.

full_pfb_spectrum = fftshift(fft(pfb_output(:, offset:Nfft+offset), Nfft, 2), 2)/Nfft; % apply the fft across the matrix
pfb_spectrum = full_pfb_spectrum(:, hsov:end-hsov-1);

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