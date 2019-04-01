clearvars;
% streaming PFB simulation code

% Polyphase filterbank parameters
M = 32;  % Polyphase branches (NFFT)
L = 256; % Taps in prototype FIR filter

P = L/M; % Taps in branch of a polyphase FIR filter

% Design prototype LPF (Hanning window)
idx = -P/2:1/M:P/2-1/M;
x = sinc(idx);
hann = hanning(L).';

h = x.*hann;

% Data generation
fs = 10e3; % sample rate (Hz)
f  = 2e3;  % SOI frequency (Hz)
t = 2; % simulation time (seconds)
T = 1/fs; % sample period (seconds)

Nsamps = fs*t;
n = 0:Nsamps-1; % sample index

signal = 10/sqrt(2)*(cos(2*pi*f/fs*n) + 1j*sin(2*pi*f/fs*n));
noise = 1/sqrt(2)*(randn(1,Nsamps) + 1j*randn(1,Nsamps)); 

x = signal + noise;

% PFB processing
input_buffer = zeros(1,M);             % input ports on PFB
filter_state = zeros(1,L);             % memory of samples going through PFB
ifft_buffer = zeros(1,M);              % input ports to the FFT
pfb_output = zeros(M ,ceil(Nsamps/M)); % Decimates by M, producing M channels

data_ptr = 1; % pointer to data location
output_ctr = 1;
while data_ptr < length(x) - M

  % rotate filter state and shift new samples in
  filter_state = circshift(filter_state, -M);
  filter_state(end-M+1:end) = x(data_ptr:data_ptr+M-1);
  data_ptr = data_ptr + M;
    
  for m = 0:M-1
    for p = 0:P-1
      ifft_buffer(m+1) = ifft_buffer(m+1) + h(p*M+m+1)*filter_state(L-p*M-m);
    end
  end

  pfb_output(:, output_ctr) = ifft(ifft_buffer, M);
  ifft_buffer = zeros(1,M); % need to clear out the ifft buffer you dum dum
  output_ctr = output_ctr + 1;
end

% Analysis

% plot the output of the PFB compared to the FFT
offset = 8; % wait offset samples for output

figure(98);
X = fft(x(offset:offset+M), M)/M;
fbins = 0:M-1;
f = fbins*fs/M;
plot(f, 20*log10(abs(X)), f, 20*log10(abs((pfb_output(:,offset))))); grid on;
legend('FFT', 'PFB');

% Form a single spectrum output after the PFB (manifestation of the scalloping problem)
fs_decimated = fs/M; % decimated sample rate on the output of the pfb (Hz)
Nfft = 512;
fbins = 0:Nfft-1;

pfb_spectrum = fftshift(fft(pfb_output(:, offset:Nfft+offset), Nfft, 2), 2)/Nfft; % apply the fft across the matrix
% for m = 1:M %  Plot individual frames
%   figure(1);
%   subplot(4,8,m);
%   fbins = ((m-1)-1/2)*Nfft:((m-1)+1/2)*Nfft-1; % m-1 explicit because matlab is one based 
%   f = fbins*fs_decimated/Nfft;
%   plot(f, 20*log10(abs(pfb_spectrum(m,:)))); grid on;
%   xlim([min(f), max(f)]);
%   ylim([-60, 20]);
% end

% stitch the spectrum together
figure(10);
stitch_bins = -Nfft/2:Nfft*M-Nfft/2-1;
fstitch = stitch_bins*fs_decimated/Nfft;
pfb_stitch = reshape(pfb_spectrum.', [1, Nfft*M]);
plot(fstitch, 20*log10(abs(pfb_stitch))); grid on;
xlim([min(fstitch), max(fstitch)]);


