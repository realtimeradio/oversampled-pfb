% oversampPFB_2stage.m
%
% Test code to evaluate oversampled 2-stage fine PFB spectrometer performance,
% This is used to test 1st stage PFB architecture for ALPACA.
%
% Brian Jeffs   11/19/18
%     updated:  03/28/19

% Set up parallel processing

% Set constant parameters and initialize
fs = 100;               % Sample frequency. Only effect is to scale plot freq. axis
L_c = 64;               % number of coarse PFB bins
Dec = 48;               % Decimation rate at 1st stage coarse PFB. D <= L_c
L_f = 128;              % Length of FFT in stage 2 PFB 
l1 = Dec*L_f/(L_c*2);   % Offeset from fine PFB band center to last retained chan. 
                        %   when overlap bins are pruned ... must be integer.
L = L_c*L_f;            % total number of fine bins (channels) in conven. PFB
L_os = L_c*2*l1;        % total number of fine bins (channels) in over sampled PFB
N_s = 100;              % no. of time samples per fine bin per block
N = L*N_s;              % total no. of time samples per block
P = 8;                  % no. of taps per polyphase filter branch
N_b = 10;               % no. of blocks to process
N_filt = 1024;          % length of input data spectral shaping filter
ls = 0;                 % "last sample" index for how far we got (in last call 
                        % to pfb3os.m) towards computing Dec undecimated ouput samples
                        % in order to get the next decimated value for Y.
                        % This keeps track of decimation index between data
                        % blocks which may not be multiples of Dec in length
m_samp = 0;             % m_samp: decimated sample index (can be reduced modulo L_c)
                        %  used to keep track of circular shift state in
                        %  pfb3os. A running count is needed across windows.

% Initialize PSD accumulators and filter state memory arrays
Sxx = zeros(L,1);
Sxx2 = zeros(L_os,1);
Sxx3 = zeros(L_os,1);
b_i = zeros(N_filt-1,1);
Yi = [];
Yi3 = [];
Xi = zeros(L_c, P-1);
Xi2 = zeros(L_c, P-1);   % Uses this for pfb3os: PFB filter state memory
xi2 = [];                % Uses this for pfb3os: window overlaped vector
L_h = P*L_c;
Xi3 = zeros(L_h-1,L_c); % filter state memory for simple FFT filter bank

% Check for consistency of FFT lengths and decimation rate
if (rem(l1,1) ~= 0)|(rem(L_f,2) ~= 0)
    error('L_c not even, or Dec not allowed given specified L_c and L_f');
end

% Design the spetral shaping filter for the P=pfb input data.
% This is just used to provide a recognizable final spectrum slope shape.
h_shape = ifft(fftshift(sqrt(linspace(1,1.5,N_filt))));

% figure(1);
% freqz(h_shape,1,'whole');
% title('Spectrum shaping filter response');
    
% *** Design the critically sampled polyphase filter tap weights  
h = fir1(L_h-1,1/L_c,'low',hamming(L_h));
H = reshape(h,L_c,[]);

% *** Design oversampled polyphase filter tap weights  
h2 = fir1(L_h-1, 0.95/Dec,'low',hamming(L_h));  
H2 = reshape(h2,L_c,[]);
figure(1)
freqz(h2)
title('O.S. PFB filter frequency response')

for i = 1:N_b       % loop for each data block

    % Generate complex blue noise random data with a positive frequency slope
    % by filtering white noise
    x_w = crandn(N,1);
    [x, b_i] = filter(h_shape,1,x_w, b_i);
    
    % Add pilot tone(s) to check for aliasing
    for m = [-2];
        % puts tones at e.g. fine channel crossover point in m -th coarse chanel
        x = x + 0.1*exp(j*2*pi/L*(m*L_f+L_f/2)*[(i-1)*N:i*N-1]'); 
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % *** critically sampled PFB *** 
    % First stage, coarse critically sampled PFB
    [Y,Xi] = pfb1(x,L_c,H,Xi);

    % Second stage, fine critically sampled PFB
    Z = pfb2(Y,L_f,L_c);

    % Compute full band fine spectrometer as concatination of fine PFB powers
    Sxx = Sxx + reshape(sum(real(Z.*conj(Z)),2),[],1);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % *** oversampled PFB *** 
    %
    % Full oversampled PFB version:
    [Y_Dec,xi2,m_samp] = pfb3os(x,L_c,H2,xi2,m_samp,Dec);
    %
    % Now do the second stage critically sampled PFB, which discards
    %   overlapped fine channels
    [Z2,Yi] = pfb4os(Y_Dec,L_f,L_c,l1,Yi);
    %
    % Compute full band fine spectrometer as concatination of fine PFB powers
    Sxx2 = Sxx2 + reshape(sum(real(Z2.*conj(Z2)),2),[],1);
    %
    % Now, for testing and performance comparison, do a (slow) bank of
    % conventional basebanding bandpass filters followed by decimation.
    % This is the "gold standard" to which we compare the os PFB. The
    % number of channels (L_c) and desimation rate (Dec) can be totally
    % differerent, same as for os PFB
    [Y_Dec,Xi3,ls] = pfb3b(x,L_c,H2,Xi3,ls,Dec);    
    [Z2,Yi3] = pfb4os(Y_Dec,L_f,L_c,l1,Yi3);
    Sxx3 = Sxx3 + reshape(sum(real(Z2.*conj(Z2)),2),[],1);
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

% Rotate PFB spectra by L_f/2 to correct for FFT offset.  Normalize.
% In Sxx2 & Sxx3, the L_c/Dec term corrects for oversampling gain
Sxx = circshift(Sxx,-L_f/2)/(L_f^2*N_b*N_s);
Sxx2 = circshift(Sxx2,-L_f/2)/((L_c/Dec)^2*L_f^2*N_b*N_s); 
Sxx3 = circshift(Sxx3,-L_f/2)/((L_c/Dec)^2*L_f^2*N_b*N_s); 

figure(2)
f = [0:L-1]'*fs/L;
fshift = L_f/2 - l1 + 1;              % This will correct for discarded fine bins
f2 = (fshift+[0:L_os-1])'*fs/L_os;    
plot(f2,10*log10(Sxx3),f,10*log10(Sxx),f2,10*log10(Sxx2),'k');
set(gca,'fontsize',16)
title('Two-stage "zoom" PSD estimate, comparing 3 algorithms')
xlabel('Frequency in Mhz')
ylabel('dB scale, arbitrary reference')
legend('Gold-standard os basebanding filter bank','Critically sampled PFB','Oversampled PFB','Location','NorthWest')


